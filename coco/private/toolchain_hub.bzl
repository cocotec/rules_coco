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
bootstrap (`native.existing_rule`) and toolchain registration
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
)
load(":platforms.bzl", "COCO_TOOLCHAIN_PLATFORMS", "host_platform", "platform_constraints", "platform_key")
load(
    ":toolchain_repositories.bzl",
    "coco_local_toolchain_repository",
    "coco_toolchain_repository",
)
load(
    ":version_resolution.bzl",
    "LOCAL_VERSION",
    "RESERVED_VERSIONS",
    "VERSION_FLAG",
    "resolve_version_alias",
    "validate_minimum_version",
    "version_to_repo_suffix",
)

DEFAULT_HUB_NAME = "coco_toolchains"

LOCAL_TOOLCHAIN_REPO_NAME = "io_cocotec_coco_local"
LOCAL_CC_RUNTIME_REPO_NAME = "io_cocotec_coco_cc_runtime__local"
LOCAL_C_RUNTIME_REPO_NAME = "io_cocotec_coco_c_runtime__local"

# Template for generating toolchain declarations in the hub repository
_TOOLCHAIN_HUB_BUILD_TEMPLATE = """
toolchain(
    name = "{name}",
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
        "{version_flag}": "{version}",
    }},
    visibility = ["//visibility:public"],
)
"""

# Config setting for when no version is explicitly specified (empty string default)
_VERSION_DEFAULT_CONFIG_SETTING = """
config_setting(
    name = "version_default",
    flag_values = {{
        "{version_flag}": "",
    }},
    visibility = ["//visibility:public"],
)
""".format(version_flag = VERSION_FLAG)

# Template for the alias handing out the configured version's runtime of one kind. The fallback
# is a target without CcInfo, which the runtime helper turns into a message naming the kind.
_RUNTIME_ALIAS_TEMPLATE = """
alias(
    name = "{kind}_runtime",
    actual = select({{{branches}
        "//conditions:default": ":no_{kind}_runtime",
    }}),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "no_{kind}_runtime",
    srcs = [],
)
"""

# What the extension registers when no module in the dependency graph declares
# coco.toolchain. rules_coco's own MODULE.bazel declares the same as a dev dependency, so it
# never reaches consumers, and developing rules_coco uses the configuration a consumer
# declaring nothing gets.
DEFAULT_TOOLCHAIN_VERSIONS = ["stable"]

def merge_toolchain_tags(modules):
    """Merges every module's coco.toolchain tags into one toolchain configuration.

    Every module declaring the tag contributes its versions and runtimes, in module order
    (root first), so a dependency can register the versions its own packages pin while the
    root's first version stays the default. The first non-empty licence setting wins. When no
    module declares the tag, the default applies: `stable` with the C and C++ runtimes.

    Args:
      modules: The extension's `ctx.modules`, or structs with `tags.toolchain`.

    Returns:
      A struct with `versions`, `c`, `cc`, `license_source`, `license_token` and
      `auth_token_path`, plus `declared`, False when no module declared the tag.
    """
    tags = [tag for mod in modules for tag in mod.tags.toolchain]
    if not tags:
        return struct(
            versions = DEFAULT_TOOLCHAIN_VERSIONS,
            c = True,
            cc = True,
            license_source = "",
            license_token = "",
            auth_token_path = "",
            declared = False,
        )

    versions = []
    c = False
    cc = False
    license_source = ""
    license_token = ""
    auth_token_path = ""
    for tag in tags:
        versions.extend(tag.versions)
        c = c or tag.c
        cc = cc or tag.cc
        license_source = license_source or tag.license_source
        license_token = license_token or tag.license_token
        auth_token_path = auth_token_path or tag.auth_token_path

    return struct(
        versions = versions,
        c = c,
        cc = cc,
        license_source = license_source,
        license_token = license_token,
        auth_token_path = auth_token_path,
        declared = True,
    )

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

def resolve_versions(raw_versions, resolve_version = resolve_version_alias):
    """Resolves, validates and deduplicates a list of requested Coco versions.

    Aliases are resolved first, so "stable" and the version it points at collapse to a
    single entry. Order is significant: the first version becomes the toolchain selected
    when `--@rules_coco//:version` is unset, so first-seen order is preserved.

    Args:
      raw_versions: The version strings as written by the user, possibly aliases.
      resolve_version: Callable mapping an alias to a concrete version, and any other
        string to itself. Defaults to `resolve_version_alias`; tests inject their own.

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
    """Computes the toolchain() declarations of the hub repository.

    Every (version, platform) pair gets a toolchain `<os>_<arch>__<suffix>` pointing into the
    platform's repository and gated on the version's config_setting, so that only the
    repositories of the pairs a build actually resolves are fetched. It constrains the *target*
    platform only: the rules running popili reach the target resolving it through an exec
    transition (see coco.bzl), so that target's platform is their execution platform, and the
    binary runs where their actions run. Cross-compiling keeps resolving a toolchain.

    The first version additionally gets a `__default` entry, gated on the version flag being
    unset. A local toolchain, when present, gets a `local` entry gated on
    `--@rules_coco//:version=local` and constrained to the host by `render_toolchain_hub_build`;
    it never becomes the default, matching bzlmod.

    Args:
      versions: Resolved, validated, deduplicated versions in priority order.
      has_local: Whether a local popili distribution is also registered.
      hub_name: The name of the hub repository, which its config_settings are read from.

    Returns:
      A struct with `toolchain_names`, `toolchain_labels`, `target_compatible_with`,
      `target_settings`, `version_suffixes` and `default_version` fields.
    """
    entries = struct(
        toolchain_names = [],
        toolchain_labels = {},
        target_compatible_with = {},
        target_settings = {},
        version_suffixes = {},
        default_version = versions[0] if versions else "",
    )

    for version in versions:
        version_suffix = version_to_repo_suffix(version)
        entries.version_suffixes[version] = version_suffix

        for (os, arch) in COCO_TOOLCHAIN_PLATFORMS:
            constraints = platform_constraints(os, arch)

            # Point directly at the toolchain implementation: the hub owns every toolchain()
            # declaration, so no per-platform proxy repository is needed.
            label = "@%s//:toolchain_impl" % toolchain_repo_name(os, arch, version_suffix)

            _add_hub_entries(
                entries,
                "%s_%s__%s" % (os, arch, version_suffix),
                label,
                ["@%s//:version_%s" % (hub_name, version_suffix)],
                constraints,
            )

            # The first version is what an unset version flag resolves to.
            if version == versions[0]:
                _add_hub_entries(
                    entries,
                    "%s_%s__default" % (os, arch),
                    label,
                    ["@%s//:version_default" % hub_name],
                    constraints,
                )

    # Gated on the "local" version so it needs --version=local. Its constraints are the host's,
    # which only the hub repository rule knows: see render_toolchain_hub_build.
    if has_local:
        entries.version_suffixes[LOCAL_VERSION] = LOCAL_VERSION
        _add_hub_entries(
            entries,
            LOCAL_VERSION,
            "@%s//:toolchain_impl" % LOCAL_TOOLCHAIN_REPO_NAME,
            ["@%s//:version_%s" % (hub_name, LOCAL_VERSION)],
            [],
        )

    return entries

def _add_hub_entries(entries, name, label, settings, constraints):
    """Adds the toolchain() of one (version, platform) pair."""
    entries.toolchain_names.append(name)
    entries.toolchain_labels[name] = label
    entries.target_compatible_with[name] = constraints
    entries.target_settings[name] = settings

def render_toolchain_hub_build(entries, host = None, cc_runtimes = {}, c_runtimes = {}):
    """Renders the hub repository's BUILD file.

    Besides the toolchains, the hub hands out the runtimes: `:cc_runtime` and `:c_runtime`
    alias the runtime of the version the configuration selects, so a rule needing one gets it
    without resolving a toolchain, and the runtime archive is fetched only when one does. The
    toolchains themselves name no runtime (see toolchain_repositories.bzl).

    The result deliberately uses only native rules, so the hub stays loadable before
    bazel_skylib has been fetched in WORKSPACE mode.

    Args:
      entries: A struct as returned by `toolchain_hub_entries`.
      host: The host as an (os, arch) pair, as returned by `host_platform`, or None. The
        local toolchain's binaries only run there, so its toolchain() is constrained to it.
      cc_runtimes: Map of version to its C++ runtime label, for the versions that have one.
      c_runtimes: Map of version to its C runtime label, for the versions that have one.

    Returns:
      The BUILD file content.
    """

    # Generate config_settings for all resolved versions plus default
    config_settings = _VERSION_DEFAULT_CONFIG_SETTING + "\n".join([
        _VERSION_CONFIG_SETTING_TEMPLATE.format(
            version = version,
            version_flag = VERSION_FLAG,
            config_name = version_suffix,
        )
        for version, version_suffix in entries.version_suffixes.items()
    ])

    local_constraints = platform_constraints(host[0], host[1]) if host else []

    # Generate BUILD file with all toolchain declarations
    toolchains = "\n".join([
        _TOOLCHAIN_HUB_BUILD_TEMPLATE.format(
            name = name,
            target_compatible_with = local_constraints if name == LOCAL_VERSION else entries.target_compatible_with[name],
            target_settings = entries.target_settings[name],
            toolchain_label = entries.toolchain_labels[name],
        )
        for name in entries.toolchain_names
    ])

    runtimes = "".join([
        _RUNTIME_ALIAS_TEMPLATE.format(
            kind = kind,
            branches = _runtime_branches(entries, runtimes_by_version),
        )
        for kind, runtimes_by_version in [("cc", cc_runtimes), ("c", c_runtimes)]
    ])

    return config_settings + "\n" + toolchains + runtimes

def _runtime_branches(entries, runtimes_by_version):
    """Renders the select() branches of a runtime alias, one per version that has one."""
    branches = ""
    for version, label in runtimes_by_version.items():
        branches += '\n        ":version_%s": "%s",' % (entries.version_suffixes[version], label)

        # The first version is what an unset version flag resolves to.
        if version == entries.default_version:
            branches += '\n        ":version_default": "%s",' % label
    return branches

def render_version_registry_build(versions, default, host = "", cc_runtimes = {}, c_runtimes = {}):
    """Renders the BUILD file of the hub's `//versions` package.

    Kept out of the hub's root package, which `register_toolchains` loads early in
    WORKSPACE mode and which therefore uses only native rules.

    `:versions` lists the registered versions and is depended on by every coco_package, so it
    must not depend on anything. `:cc_runtimes` and `:c_runtimes` map each version to its
    C++ or C runtime, and are depended on only by coco_cc_library and coco_c_library
    respectively, so that only those make Bazel fetch every registered version's runtime of
    that kind.

    Args:
      versions: Every registered version, including "local" when registered.
      default: The version an unset `--@rules_coco//:version` resolves to, or "".
      host: The host as a platform key, e.g. "linux_x86_64", or "" when popili is not
        published for it.
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
    host = {host},
    visibility = ["//visibility:public"],
)

coco_version_registry(
    name = "cc_runtimes",
    cc_runtimes = {cc_runtimes},
    visibility = ["//visibility:public"],
)

coco_version_registry(
    name = "c_runtimes",
    c_runtimes = {c_runtimes},
    visibility = ["//visibility:public"],
)
""".format(
        versions = repr(versions),
        default = repr(default),
        host = repr(host),
        cc_runtimes = repr(cc_runtimes),
        c_runtimes = repr(c_runtimes),
    )

def _coco_toolchain_hub_impl(repository_ctx):
    """Implementation of the coco toolchain hub repository rule."""
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    # Evaluated on the machine running Bazel: where the local toolchain's binaries run, and
    # where a licence acquired or installed on the host is.
    host = host_platform(repository_ctx)

    repository_ctx.file("BUILD.bazel", render_toolchain_hub_build(
        struct(
            toolchain_names = repository_ctx.attr.toolchain_names,
            toolchain_labels = repository_ctx.attr.toolchain_labels,
            target_compatible_with = repository_ctx.attr.target_compatible_with,
            target_settings = repository_ctx.attr.target_settings,
            version_suffixes = repository_ctx.attr.version_suffixes,
            default_version = repository_ctx.attr.default_version,
        ),
        host = host,
        cc_runtimes = repository_ctx.attr.cc_runtimes,
        c_runtimes = repository_ctx.attr.c_runtimes,
    ))

    repository_ctx.file("versions/BUILD.bazel", render_version_registry_build(
        versions = repository_ctx.attr.registered_versions,
        default = repository_ctx.attr.default_version,
        host = platform_key(host[0], host[1]) if host else "",
        cc_runtimes = {label: version for version, label in repository_ctx.attr.cc_runtimes.items()},
        c_runtimes = {label: version for version, label in repository_ctx.attr.c_runtimes.items()},
    ))

coco_toolchain_hub = repository_rule(
    doc = (
        "Generates a hub repository that aggregates all Coco toolchains. " +
        "This allows registering all toolchains with a single `:all` target."
    ),
    attrs = {
        "c_runtimes": attr.string_dict(
            doc = "Map of version to its C runtime label, for the versions that have one.",
        ),
        "cc_runtimes": attr.string_dict(
            doc = "Map of version to its C++ runtime label, for the versions that have one.",
        ),
        "default_version": attr.string(
            doc = "The version an unset --@rules_coco//:version resolves to, or '' if none.",
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
        append to that version's C++ runtime deps. The `LOCAL_VERSION` key applies to
        the `local` C++ runtime.
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

    # Version -> runtime label, handed out by the hub's runtime aliases and recorded in its
    # version registry.
    cc_runtimes = {}
    c_runtimes = {}

    for version in versions:
        version_suffix = version_to_repo_suffix(version)

        # Set up C++ runtime if requested (version-specific)
        if cc:
            coco_cc_runtime_repository(
                name = cc_runtime_repo_name(version_suffix),
                version = version,
                extra_deps = cc_runtime_extra_deps_by_version.get(version, []),
            )
            cc_runtimes[version] = "@%s//:runtime" % cc_runtime_repo_name(version_suffix)

        # Set up C runtime if requested (version-specific)
        if c:
            coco_c_runtime_repository(
                name = c_runtime_repo_name(version_suffix),
                version = version,
            )
            c_runtimes[version] = "@%s//:runtime" % c_runtime_repo_name(version_suffix)

        # One repository per platform, each declaring the version's toolchain for that platform.
        # Only the ones the hub's toolchain resolution selects are fetched.
        for (os, arch) in COCO_TOOLCHAIN_PLATFORMS:
            coco_toolchain_repository(
                name = toolchain_repo_name(os, arch, version_suffix),
                arch = arch,
                os = os,
                version = version,
                license_source = license_source,
                license_token = license_token,
                auth_token_path = auth_token_path,
            )

    if local:
        if local.cc_runtime:
            coco_cc_local_runtime_repository(
                name = LOCAL_CC_RUNTIME_REPO_NAME,
                path = local.cc_runtime,
                extra_deps = cc_runtime_extra_deps_by_version.get(LOCAL_VERSION, []),
            )
            cc_runtimes[LOCAL_VERSION] = "@%s//:runtime" % LOCAL_CC_RUNTIME_REPO_NAME

        if local.c_runtime:
            coco_c_local_runtime_repository(
                name = LOCAL_C_RUNTIME_REPO_NAME,
                path = local.c_runtime,
            )
            c_runtimes[LOCAL_VERSION] = "@%s//:runtime" % LOCAL_C_RUNTIME_REPO_NAME

        coco_local_toolchain_repository(
            name = LOCAL_TOOLCHAIN_REPO_NAME,
            path = local.popili,
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
        target_compatible_with = entries.target_compatible_with,
        target_settings = entries.target_settings,
        version_suffixes = entries.version_suffixes,
        default_version = entries.default_version,
        cc_runtimes = cc_runtimes,
        c_runtimes = c_runtimes,
        registered_versions = versions + ([LOCAL_VERSION] if local else []),
    )
