# Copyright 2024 Cocotec Limited
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Declares every Coco toolchain repository, plus the hub that dispatches between them.

Shared by WORKSPACE mode (`//coco/private:repositories.bzl`) and bzlmod
(`//coco:extensions.bzl`) so that both produce identical repository names and an
identical hub.

Nothing in this file may call `native.*`: `declare_coco_toolchains` runs inside a
module extension, where the native module is inaccessible. The WORKSPACE-only
bootstrap (`native.existing_rules`) and toolchain registration
(`native.register_toolchains`) therefore stay with the caller.
"""

load(
    ":common_repositories.bzl",
    "coco_c_local_runtime_repository",
    "coco_c_runtime_repository",
    "coco_cc_local_runtime_repository",
    "coco_cc_runtime_repository",
    "coco_fetch_license_repository",
    "coco_preferences_repository",
    "coco_symlink_license_repository",
    "validate_minimum_version",
    "version_to_repo_suffix",
)
load(
    ":toolchain_repositories.bzl",
    "coco_local_toolchain_repository",
    "coco_toolchain_repository",
)

# Every platform a published popili release is available for.
COCO_TOOLCHAIN_PLATFORMS = [
    ("osx", "aarch64"),
    ("osx", "x86_64"),
    ("linux", "aarch64"),
    ("linux", "x86_64"),
    ("windows", "x86_64"),
]

# Version strings the hub uses for its own config_settings, so they cannot also name
# a popili release. validate_minimum_version() waves them through because they contain
# no ".", and "default" would otherwise emit a duplicate config_setting.
RESERVED_VERSIONS = ["local", "default"]

DEFAULT_HUB_NAME = "coco_toolchains"

LOCAL_TOOLCHAIN_REPO_NAME = "io_cocotec_coco_local"
LOCAL_CC_RUNTIME_REPO_NAME = "io_cocotec_coco_cc_runtime__local"
LOCAL_C_RUNTIME_REPO_NAME = "io_cocotec_coco_c_runtime__local"

# Template for generating toolchain declarations in the hub repository
_TOOLCHAIN_HUB_BUILD_TEMPLATE = """
toolchain(
    name = "{name}",
    exec_compatible_with = {exec_compatible_with},
    target_compatible_with = {target_compatible_with},
    target_settings = {target_settings},
    toolchain = "{toolchain_label}",
    toolchain_type = "@rules_coco//coco:toolchain_type",
    visibility = ["//visibility:public"],
)
"""

# Template for generating version config_setting in the hub repository
_VERSION_CONFIG_SETTING_TEMPLATE = """
config_setting(
    name = "version_{config_name}",
    flag_values = {{
        "@rules_coco//:version": "{version}",
    }},
    visibility = ["//visibility:public"],
)
"""

# Config setting for when no version is explicitly specified (empty string default)
_VERSION_DEFAULT_CONFIG_SETTING = """
config_setting(
    name = "version_default",
    flag_values = {
        "@rules_coco//:version": "",
    },
    visibility = ["//visibility:public"],
)
"""

def platform_constraints(os, arch):
    """Returns the platform constraints for a Coco toolchain platform.

    Args:
      os: The toolchain OS ("osx", "linux" or "windows").
      arch: The toolchain CPU ("aarch64" or "x86_64").

    Returns:
      A list of constraint value label strings.
    """
    return [
        "@platforms//os:%s" % os,
        "@platforms//cpu:%s" % arch,
    ]

def toolchain_repo_name(os, arch, version_suffix):
    """Returns the name of the repository holding one platform's popili distribution.

    Args:
      os: The toolchain OS ("osx", "linux" or "windows").
      arch: The toolchain CPU ("aarch64" or "x86_64").
      version_suffix: The mangled version, as returned by `version_to_repo_suffix`.

    Returns:
      The repository name.
    """
    return "io_cocotec_coco_%s_%s__%s" % (os, arch, version_suffix)

def cc_runtime_repo_name(version_suffix):
    """Returns the name of the C++ runtime repository for a mangled version.

    Args:
      version_suffix: The mangled version, as returned by `version_to_repo_suffix`.

    Returns:
      The repository name.
    """
    return "io_cocotec_coco_cc_runtime__%s" % version_suffix

def c_runtime_repo_name(version_suffix):
    """Returns the name of the C runtime repository for a mangled version.

    Args:
      version_suffix: The mangled version, as returned by `version_to_repo_suffix`.

    Returns:
      The repository name.
    """
    return "io_cocotec_coco_c_runtime__%s" % version_suffix

def resolve_versions(raw_versions, resolve_version):
    """Resolves, validates and deduplicates a list of requested Coco versions.

    Aliases are resolved first, so "stable" and the version it points at collapse to a
    single entry. Order is significant: the first version becomes the toolchain selected
    when `--@rules_coco//:version` is unset, so first-seen order is preserved.

    Args:
      raw_versions: The version strings as written by the user, possibly aliases.
      resolve_version: Callable mapping an alias to a concrete version, and any other
        string to itself.

    Returns:
      A (versions, error) tuple. `versions` is empty when `error` is non-None.
    """
    versions = []
    seen = {}
    suffixes = {}

    for raw in raw_versions:
        resolved = resolve_version(raw)

        if resolved in RESERVED_VERSIONS:
            return [], (
                "Coco version %r is reserved and cannot be registered. " % raw +
                "%s name the hub's own config_settings. " % ", ".join([repr(v) for v in RESERVED_VERSIONS]) +
                "To register a popili distribution from the local filesystem, use the " +
                "local_popili argument of coco_repositories (WORKSPACE) or the " +
                "coco.local_toolchain tag (bzlmod)."
            )

        error = validate_minimum_version(resolved)
        if error:
            return [], error

        if resolved in seen:
            continue

        suffix = version_to_repo_suffix(resolved)
        if suffix in suffixes:
            return [], (
                "Coco versions %r and %r both mangle to the repository suffix %r, " % (suffixes[suffix], resolved, suffix) +
                "so they cannot be registered together."
            )

        suffixes[suffix] = resolved
        seen[resolved] = True
        versions.append(resolved)

    return versions, None

def toolchain_hub_entries(versions, has_local = False, hub_name = DEFAULT_HUB_NAME):
    """Computes the full payload of the toolchain hub repository.

    One toolchain is declared per (platform, version), gated on that version's
    config_setting. The first version additionally gets a `__default` toolchain per
    platform, gated on the version flag being unset. A local toolchain, when present, is
    host-only (no platform constraints) and gated on `--@rules_coco//:version=local`; it
    never becomes the default, matching bzlmod.

    Args:
      versions: Resolved, validated, deduplicated versions in priority order.
      has_local: Whether a local popili distribution is also registered.
      hub_name: The name of the hub repository, which its config_settings are read from.

    Returns:
      A struct with `toolchain_names`, `toolchain_labels`, `exec_compatible_with`,
      `target_compatible_with`, `target_settings` and `version_suffixes` fields.
    """
    toolchain_names = []
    toolchain_labels = {}
    exec_compatible_with = {}
    target_compatible_with = {}
    target_settings = {}
    version_suffixes = {}

    for version in versions:
        version_suffix = version_to_repo_suffix(version)
        version_suffixes[version] = version_suffix

        for (os, arch) in COCO_TOOLCHAIN_PLATFORMS:
            constraints = platform_constraints(os, arch)

            # Point directly at the toolchain implementation: the hub owns every
            # toolchain() declaration, so no per-platform proxy repository is needed.
            label = "@%s//:toolchain_impl" % toolchain_repo_name(os, arch, version_suffix)

            name = "%s_%s__%s" % (os, arch, version_suffix)
            toolchain_names.append(name)
            toolchain_labels[name] = label
            exec_compatible_with[name] = constraints
            target_compatible_with[name] = constraints
            target_settings[name] = ["@%s//:version_%s" % (hub_name, version_suffix)]

            # The first version is what an unset version flag resolves to.
            if version == versions[0]:
                default_name = "%s_%s__default" % (os, arch)
                toolchain_names.append(default_name)
                toolchain_labels[default_name] = label
                exec_compatible_with[default_name] = constraints
                target_compatible_with[default_name] = constraints
                target_settings[default_name] = ["@%s//:version_default" % hub_name]

    # Host-only (no constraints), gated on the "local" version so it needs --version=local.
    if has_local:
        version_suffixes["local"] = "local"

        toolchain_names.append("local")
        toolchain_labels["local"] = "@%s//:toolchain_impl" % LOCAL_TOOLCHAIN_REPO_NAME
        exec_compatible_with["local"] = []
        target_compatible_with["local"] = []
        target_settings["local"] = ["@%s//:version_local" % hub_name]

    return struct(
        toolchain_names = toolchain_names,
        toolchain_labels = toolchain_labels,
        exec_compatible_with = exec_compatible_with,
        target_compatible_with = target_compatible_with,
        target_settings = target_settings,
        version_suffixes = version_suffixes,
    )

def render_toolchain_hub_build(entries):
    """Renders the hub repository's BUILD file.

    The result deliberately uses only native rules, so the hub stays loadable before
    bazel_skylib has been fetched in WORKSPACE mode.

    Args:
      entries: A struct as returned by `toolchain_hub_entries`.

    Returns:
      The BUILD file content.
    """

    # Generate config_settings for all resolved versions plus default
    config_settings = _VERSION_DEFAULT_CONFIG_SETTING + "\n".join([
        _VERSION_CONFIG_SETTING_TEMPLATE.format(
            version = version,
            config_name = version_suffix,
        )
        for version, version_suffix in entries.version_suffixes.items()
    ])

    # Generate BUILD file with all toolchain declarations
    toolchains = "\n".join([
        _TOOLCHAIN_HUB_BUILD_TEMPLATE.format(
            name = name,
            exec_compatible_with = entries.exec_compatible_with[name],
            target_compatible_with = entries.target_compatible_with[name],
            target_settings = entries.target_settings[name],
            toolchain_label = entries.toolchain_labels[name],
        )
        for name in entries.toolchain_names
    ])

    return config_settings + "\n" + toolchains

def render_version_registry_build(versions, default, cc_runtimes = {}, c_runtimes = {}):
    """Renders the BUILD file of the hub's `//versions` package.

    Kept out of the hub's root package, which `register_toolchains` loads early in
    WORKSPACE mode and which therefore uses only native rules.

    Two targets: `:versions` lists the registered versions and is depended on by every
    coco_package, so it must not depend on anything; `:runtimes` additionally maps each
    version to its runtimes, and is depended on only by coco_cc_library and coco_c_library,
    so that only they make Bazel fetch every registered version's runtime.

    Args:
      versions: Every registered version, including "local" when registered.
      default: The version an unset `--@rules_coco//:version` resolves to, or "".
      cc_runtimes: Map of C++ runtime label string to the version it belongs to.
      c_runtimes: Map of C runtime label string to the version it belongs to.

    Returns:
      The BUILD file content.
    """
    return """load("@rules_coco//coco/private:version_registry.bzl", "coco_version_registry")

coco_version_registry(
    name = "versions",
    versions = {versions},
    default = {default},
    visibility = ["//visibility:public"],
)

coco_version_registry(
    name = "runtimes",
    versions = {versions},
    default = {default},
    cc_runtimes = {cc_runtimes},
    c_runtimes = {c_runtimes},
    visibility = ["//visibility:public"],
)
""".format(
        versions = repr(versions),
        default = repr(default),
        cc_runtimes = repr(cc_runtimes),
        c_runtimes = repr(c_runtimes),
    )

def _coco_toolchain_hub_impl(repository_ctx):
    """Implementation of the coco toolchain hub repository rule."""
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    repository_ctx.file("BUILD.bazel", render_toolchain_hub_build(struct(
        toolchain_names = repository_ctx.attr.toolchain_names,
        toolchain_labels = repository_ctx.attr.toolchain_labels,
        exec_compatible_with = repository_ctx.attr.exec_compatible_with,
        target_compatible_with = repository_ctx.attr.target_compatible_with,
        target_settings = repository_ctx.attr.target_settings,
        version_suffixes = repository_ctx.attr.version_suffixes,
    )))

    repository_ctx.file("versions/BUILD.bazel", render_version_registry_build(
        versions = repository_ctx.attr.registered_versions,
        default = repository_ctx.attr.default_version,
        cc_runtimes = repository_ctx.attr.cc_runtimes,
        c_runtimes = repository_ctx.attr.c_runtimes,
    ))

coco_toolchain_hub = repository_rule(
    doc = (
        "Generates a hub repository that aggregates all Coco toolchains. " +
        "This allows registering all toolchains with a single `:all` target."
    ),
    attrs = {
        "c_runtimes": attr.string_dict(
            doc = "Map of C runtime label to the version it belongs to.",
        ),
        "cc_runtimes": attr.string_dict(
            doc = "Map of C++ runtime label to the version it belongs to.",
        ),
        "default_version": attr.string(
            doc = "The version an unset --@rules_coco//:version resolves to, or '' if none.",
        ),
        "exec_compatible_with": attr.string_list_dict(
            doc = "Map of toolchain name to exec platform constraints.",
            mandatory = True,
        ),
        "registered_versions": attr.string_list(
            doc = "Every registered version, including 'local' when registered.",
        ),
        "target_compatible_with": attr.string_list_dict(
            doc = "Map of toolchain name to target platform constraints.",
            mandatory = True,
        ),
        "target_settings": attr.string_list_dict(
            doc = "Map of toolchain name to target settings (e.g., version constraints).",
            mandatory = True,
        ),
        "toolchain_labels": attr.string_dict(
            doc = "Map of toolchain name to toolchain implementation label.",
            mandatory = True,
        ),
        "toolchain_names": attr.string_list(
            doc = "List of toolchain names to include in the hub.",
            mandatory = True,
        ),
        "version_suffixes": attr.string_dict(
            doc = "Map of version string to normalized suffix for config_setting names.",
            mandatory = True,
        ),
    },
    implementation = _coco_toolchain_hub_impl,
)

def declare_coco_toolchains(
        versions,
        c = False,
        cc = False,
        cc_runtime_extra_deps_by_version = {},
        license_source = "",
        license_token = "",
        auth_token_path = "",
        local = None,
        hub_name = DEFAULT_HUB_NAME):
    """Declares every repository backing a set of Coco versions, plus the hub.

    Callers are responsible for registering `@<hub_name>//:all`; this function cannot do
    it itself because `native.register_toolchains` is unavailable inside a module
    extension.

    Args:
      versions: Resolved, validated, deduplicated versions in priority order, as
        returned by `resolve_versions`. May be empty when only `local` is registered.
      c: Whether to fetch the C runtime for each version.
      cc: Whether to fetch the C++ runtime for each version.
      cc_runtime_extra_deps_by_version: Map of version to extra cc_library labels to
        append to that version's C++ runtime deps.
      license_source: Default license source mode for every toolchain.
      license_token: Default license token for every toolchain.
      auth_token_path: Default auth token file path for every toolchain.
      local: None, or a struct with `popili`, `cc_runtime` and `c_runtime` path fields
        describing a popili distribution on the local filesystem.
      hub_name: The name of the hub repository to create.
    """
    coco_preferences_repository(name = "io_cocotec_coco_preferences")
    coco_fetch_license_repository(
        name = "io_cocotec_licensing_fetch",
        versions = versions,
    )
    coco_symlink_license_repository(name = "io_cocotec_licensing_local")

    # Runtime label -> version, recorded in the hub's version registry.
    cc_runtimes = {}
    c_runtimes = {}

    for version in versions:
        version_suffix = version_to_repo_suffix(version)

        # Set up C++ runtime if requested (version-specific)
        cc_runtime_label = None
        if cc:
            coco_cc_runtime_repository(
                name = cc_runtime_repo_name(version_suffix),
                version = version,
                extra_deps = cc_runtime_extra_deps_by_version.get(version, []),
            )
            cc_runtime_label = "@%s//:runtime" % cc_runtime_repo_name(version_suffix)
            cc_runtimes[cc_runtime_label] = version

        # Set up C runtime if requested (version-specific)
        c_runtime_label = None
        if c:
            coco_c_runtime_repository(
                name = c_runtime_repo_name(version_suffix),
                version = version,
            )
            c_runtime_label = "@%s//:runtime" % c_runtime_repo_name(version_suffix)
            c_runtimes[c_runtime_label] = version

        for (os, arch) in COCO_TOOLCHAIN_PLATFORMS:
            coco_toolchain_repository(
                name = toolchain_repo_name(os, arch, version_suffix),
                arch = arch,
                os = os,
                version = version,
                cc_runtime_label = cc_runtime_label,
                c_runtime_label = c_runtime_label,
                license_source = license_source,
                license_token = license_token,
                auth_token_path = auth_token_path,
            )

    if local:
        cc_runtime_label = None
        if local.cc_runtime:
            coco_cc_local_runtime_repository(
                name = LOCAL_CC_RUNTIME_REPO_NAME,
                path = local.cc_runtime,
            )
            cc_runtime_label = "@%s//:runtime" % LOCAL_CC_RUNTIME_REPO_NAME
            cc_runtimes[cc_runtime_label] = "local"

        c_runtime_label = None
        if local.c_runtime:
            coco_c_local_runtime_repository(
                name = LOCAL_C_RUNTIME_REPO_NAME,
                path = local.c_runtime,
            )
            c_runtime_label = "@%s//:runtime" % LOCAL_C_RUNTIME_REPO_NAME
            c_runtimes[c_runtime_label] = "local"

        coco_local_toolchain_repository(
            name = LOCAL_TOOLCHAIN_REPO_NAME,
            path = local.popili,
            cc_runtime_label = cc_runtime_label,
            c_runtime_label = c_runtime_label,
            license_source = license_source,
            license_token = license_token,
            auth_token_path = auth_token_path,
        )

    entries = toolchain_hub_entries(
        versions,
        has_local = local != None,
        hub_name = hub_name,
    )

    coco_toolchain_hub(
        name = hub_name,
        toolchain_names = entries.toolchain_names,
        toolchain_labels = entries.toolchain_labels,
        exec_compatible_with = entries.exec_compatible_with,
        target_compatible_with = entries.target_compatible_with,
        target_settings = entries.target_settings,
        version_suffixes = entries.version_suffixes,
        registered_versions = versions + (["local"] if local else []),
        default_version = versions[0] if versions else "",
        cc_runtimes = cc_runtimes,
        c_runtimes = c_runtimes,
    )
