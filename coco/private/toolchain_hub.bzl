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
load(":platforms.bzl", "COCO_TOOLCHAIN_PLATFORMS", "platform_constraints")
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
    exec_compatible_with = {exec_compatible_with},
    target_settings = {target_settings},
    toolchain = "{toolchain_label}",
    toolchain_type = "@rules_coco//coco:toolchain_type",
    visibility = ["//visibility:public"],
)
"""

# The host's constraints, as `@platforms` detects them, for the local toolchain and the
# registry. Evaluated when the hub's BUILD file is loaded rather than baked into it, so the
# hub's content does not depend on the host. Loaded only when a local toolchain is registered,
# so a hub without one does not need an `@platforms` that has `//host`.
_HOST_CONSTRAINTS_LOAD = """load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
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

_REGISTRY_LOAD = """load("@rules_coco//coco/private:version_registry.bzl", "coco_registered_versions", "coco_version_registry")
"""

_REGISTRY_TEMPLATE = """
coco_registered_versions(
    name = "registered_versions",
    build_setting_default = {versions},
    visibility = ["//visibility:public"],
)

coco_version_registry(
    name = "registry",
    host_constraints = {host_constraints},
    registered_versions = ":registered_versions",
    visibility = ["//visibility:public"],
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
    """Computes the full payload of the toolchain hub repository.

    One toolchain is declared per (platform, version), gated on that version's
    config_setting. Toolchains constrain only the exec platform: popili runs there, and the
    runtime it hands out is source, so any target platform can use it (cross-compiling
    included). The first version additionally gets a `__default` toolchain per
    platform, gated on the version flag being unset. A local toolchain, when present, is
    constrained to the host (its binaries only exist on the machine that staged them) and
    gated on `--@rules_coco//:version=local`; it never becomes the default, matching
    bzlmod.

    Args:
      versions: Resolved, validated, deduplicated versions in priority order.
      has_local: Whether a local popili distribution is also registered.
      hub_name: The name of the hub repository, which its config_settings are read from.

    Returns:
      A struct with `toolchain_names`, `toolchain_labels`, `exec_compatible_with`,
      `target_settings`, `version_suffixes` and `has_local` fields, plus `registered_versions`
      (the versions followed by `local` when registered) for the registry targets. An
      `exec_compatible_with` value is a list of constraint labels, or for the local toolchain
      the `HOST_CONSTRAINTS` expression the hub's BUILD file loads.
    """
    toolchain_names = []
    toolchain_labels = {}
    exec_compatible_with = {}
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
            target_settings[name] = ["@%s//:version_%s" % (hub_name, version_suffix)]

            # The first version is what an unset version flag resolves to.
            if version == versions[0]:
                default_name = "%s_%s__default" % (os, arch)
                toolchain_names.append(default_name)
                toolchain_labels[default_name] = label
                exec_compatible_with[default_name] = constraints
                target_settings[default_name] = ["@%s//:version_default" % hub_name]

    if has_local:
        version_suffixes[LOCAL_VERSION] = LOCAL_VERSION

        toolchain_names.append(LOCAL_VERSION)
        toolchain_labels[LOCAL_VERSION] = "@%s//:toolchain_impl" % LOCAL_TOOLCHAIN_REPO_NAME
        exec_compatible_with[LOCAL_VERSION] = "HOST_CONSTRAINTS"
        target_settings[LOCAL_VERSION] = ["@%s//:version_%s" % (hub_name, LOCAL_VERSION)]

    return struct(
        toolchain_names = toolchain_names,
        toolchain_labels = toolchain_labels,
        exec_compatible_with = exec_compatible_with,
        target_settings = target_settings,
        version_suffixes = version_suffixes,
        has_local = has_local,
        registered_versions = versions + ([LOCAL_VERSION] if has_local else []),
    )

def render_toolchain_hub_build(entries):
    """Renders the hub repository's BUILD file.

    The result uses only native rules, `@platforms` and rules_coco's own
    `version_registry.bzl`, which loads nothing, so the hub stays loadable before
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
            version_flag = VERSION_FLAG,
            config_name = version_suffix,
        )
        for version, version_suffix in entries.version_suffixes.items()
    ])

    # Generate BUILD file with all toolchain declarations
    toolchains = "\n".join([
        _TOOLCHAIN_HUB_BUILD_TEMPLATE.format(
            name = name,
            exec_compatible_with = entries.exec_compatible_with[name],
            target_settings = entries.target_settings[name],
            toolchain_label = entries.toolchain_labels[name],
        )
        for name in entries.toolchain_names
    ])

    registry = _REGISTRY_TEMPLATE.format(
        host_constraints = "HOST_CONSTRAINTS" if entries.has_local else "[]",
        versions = repr(entries.registered_versions),
    )

    prelude = (_HOST_CONSTRAINTS_LOAD if entries.has_local else "") + _REGISTRY_LOAD
    return prelude + config_settings + "\n" + toolchains + registry

def _coco_toolchain_hub_impl(repository_ctx):
    """Implementation of the coco toolchain hub repository rule."""
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    entries = toolchain_hub_entries(
        repository_ctx.attr.versions,
        has_local = repository_ctx.attr.has_local,
        hub_name = repository_ctx.attr.hub_name,
    )
    repository_ctx.file("BUILD.bazel", render_toolchain_hub_build(entries))

coco_toolchain_hub = repository_rule(
    doc = (
        "Generates a hub repository that aggregates all Coco toolchains. " +
        "This allows registering all toolchains with a single `:all` target."
    ),
    attrs = {
        "has_local": attr.bool(
            doc = "Whether a local popili distribution is registered, as a host-only toolchain.",
            default = False,
        ),
        "hub_name": attr.string(
            doc = "The apparent name of this repository, which its config_settings are read from.",
            mandatory = True,
        ),
        "versions": attr.string_list(
            doc = "Resolved, deduplicated versions in priority order; the first is the default.",
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
        describing a popili distribution on the local filesystem, and the
        `license_protocol_version` its popili reads (0 if unknown).
      hub_name: The name of the hub repository to create.
    """
    coco_preferences_repository(name = "io_cocotec_coco_preferences")
    coco_fetch_license_repository(
        name = "io_cocotec_licensing_fetch",
        versions = versions,
    )
    coco_symlink_license_repository(name = "io_cocotec_licensing_local")

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

        # Set up C runtime if requested (version-specific)
        c_runtime_label = None
        if c:
            coco_c_runtime_repository(
                name = c_runtime_repo_name(version_suffix),
                version = version,
            )
            c_runtime_label = "@%s//:runtime" % c_runtime_repo_name(version_suffix)

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
                extra_deps = cc_runtime_extra_deps_by_version.get(LOCAL_VERSION, []),
            )
            cc_runtime_label = "@%s//:runtime" % LOCAL_CC_RUNTIME_REPO_NAME

        c_runtime_label = None
        if local.c_runtime:
            coco_c_local_runtime_repository(
                name = LOCAL_C_RUNTIME_REPO_NAME,
                path = local.c_runtime,
            )
            c_runtime_label = "@%s//:runtime" % LOCAL_C_RUNTIME_REPO_NAME

        coco_local_toolchain_repository(
            name = LOCAL_TOOLCHAIN_REPO_NAME,
            path = local.popili,
            cc_runtime_label = cc_runtime_label,
            c_runtime_label = c_runtime_label,
            license_protocol_version = local.license_protocol_version,
            license_source = license_source,
            license_token = license_token,
            auth_token_path = auth_token_path,
        )

    coco_toolchain_hub(
        name = hub_name,
        versions = versions,
        has_local = local != None,
        hub_name = hub_name,
    )
