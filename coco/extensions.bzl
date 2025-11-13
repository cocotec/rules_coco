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

"""Bazel module extensions for rules_coco."""

load(
    "//coco/private:common_repositories.bzl",
    "coco_cc_runtime_repository",
    "coco_fetch_license_repository",
    "coco_preferences_repository",
    "coco_symlink_license_repository",
    "version_to_repo_suffix",
)
load(
    "//coco/private:repositories.bzl",
    "coco_toolchain_repository",
    "coco_toolchain_repository_proxy",
)
load(
    "//coco/private:version_aliases.bzl",
    "VERSION_ALIASES",
)

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

def _coco_toolchain_hub_impl(repository_ctx):
    """Implementation of the coco toolchain hub repository rule."""
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    # Generate config_settings for all resolved versions
    config_settings = "\n".join([
        _VERSION_CONFIG_SETTING_TEMPLATE.format(
            version = version,
            config_name = version_suffix,
        )
        for version, version_suffix in repository_ctx.attr.version_suffixes.items()
    ])

    # Generate BUILD file with all toolchain declarations
    toolchains = "\n".join([
        _TOOLCHAIN_HUB_BUILD_TEMPLATE.format(
            name = name,
            exec_compatible_with = repository_ctx.attr.exec_compatible_with[name],
            target_compatible_with = repository_ctx.attr.target_compatible_with[name],
            target_settings = repository_ctx.attr.target_settings[name],
            toolchain_label = repository_ctx.attr.toolchain_labels[name],
        )
        for name in repository_ctx.attr.toolchain_names
    ])

    repository_ctx.file("BUILD.bazel", config_settings + "\n" + toolchains)

_coco_toolchain_hub = repository_rule(
    doc = (
        "Generates a hub repository that aggregates all Coco toolchains. " +
        "This allows registering all toolchains with a single `:all` target."
    ),
    attrs = {
        "exec_compatible_with": attr.string_list_dict(
            doc = "Map of toolchain name to exec platform constraints.",
            mandatory = True,
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

def _resolve_version(version):
    if version in VERSION_ALIASES:
        return VERSION_ALIASES[version]
    return version

def _toolchain_tag_impl(ctx):
    """Implementation of the coco module extension."""

    # Collect all toolchain configurations from tags across all modules
    # Merge versions from all modules to support different modules requesting different versions
    all_versions = []
    cc = False

    for mod in ctx.modules:
        for toolchain in mod.tags.toolchain:
            all_versions.extend(toolchain.versions)
            cc = cc or toolchain.cc

    # Resolve version aliases (like "stable" -> "1.5.1") and deduplicate
    # Keep track of both original and resolved versions for config_settings
    versions = []  # Resolved versions for toolchain creation
    seen = {}
    for v in all_versions:
        resolved = _resolve_version(v)
        if resolved not in seen:
            versions.append(resolved)
            seen[resolved] = True

    # Set up licensing repositories (after collecting versions so we can determine product name)
    coco_preferences_repository(name = "io_cocotec_coco_preferences")
    coco_fetch_license_repository(
        name = "io_cocotec_licensing_fetch",
        versions = versions,
    )
    coco_symlink_license_repository(name = "io_cocotec_licensing_local")

    # Collect information for hub repository
    toolchain_names = []
    toolchain_labels = {}
    exec_compatible_with = {}
    target_compatible_with = {}
    target_settings = {}
    version_suffixes = {}

    # Set up toolchains for all versions
    for version in versions:
        version_suffix = version_to_repo_suffix(version)
        version_suffixes[version] = version_suffix

        # Set up C++ runtime if requested (version-specific)
        if cc:
            coco_cc_runtime_repository(
                name = "io_cocotec_coco_cc_runtime__%s" % version_suffix,
                version = version,
            )

        # Set up toolchains for all platforms
        for (os, arch) in [
            ("osx", "aarch64"),
            ("osx", "x86_64"),
            ("linux", "aarch64"),
            ("linux", "x86_64"),
            ("windows", "x86_64"),
        ]:
            repo_name = "io_cocotec_coco_%s_%s__%s" % (os, arch, version_suffix)
            toolchains_repo_name = repo_name + "_toolchains"

            # Determine cc_runtime_label if CC support is enabled
            cc_runtime_label = None
            if cc:
                cc_runtime_label = "@io_cocotec_coco_cc_runtime__%s//:runtime" % version_suffix

            coco_toolchain_repository(
                name = repo_name,
                arch = arch,
                os = os,
                version = version,
                cc_runtime_label = cc_runtime_label,
            )

            constraints = [
                "@platforms//os:%s" % os,
                "@platforms//cpu:%s" % arch,
            ]

            coco_toolchain_repository_proxy(
                name = toolchains_repo_name,
                constraints = constraints,
                parent_workspace_name = repo_name,
            )

            # Record toolchain info for hub
            # Point directly to the toolchain implementation, not the proxy's toolchain declaration
            toolchain_name = "%s_%s__%s" % (os, arch, version_suffix)
            toolchain_names.append(toolchain_name)
            toolchain_labels[toolchain_name] = "@%s//:toolchain_impl" % repo_name
            exec_compatible_with[toolchain_name] = constraints
            target_compatible_with[toolchain_name] = constraints
            target_settings[toolchain_name] = ["@coco_toolchains//:version_%s" % version_suffix]

    # Create hub repository that aggregates all toolchains
    _coco_toolchain_hub(
        name = "coco_toolchains",
        toolchain_names = toolchain_names,
        toolchain_labels = toolchain_labels,
        exec_compatible_with = exec_compatible_with,
        target_compatible_with = target_compatible_with,
        target_settings = target_settings,
        version_suffixes = version_suffixes,
    )

    return ctx.extension_metadata(
        reproducible = True,
    )

_toolchain_tag = tag_class(
    attrs = {
        "cc": attr.bool(
            default = False,
            doc = "Whether to include C++ runtime support",
        ),
        "versions": attr.string_list(
            default = ["stable"],
            doc = "List of Coco/Popili versions to register (e.g., ['1.5.0', '1.4.0']). Use version aliases like 'stable' or explicit versions like '1.5.1'.",
        ),
    },
)

coco = module_extension(
    implementation = _toolchain_tag_impl,
    tag_classes = {
        "toolchain": _toolchain_tag,
    },
)
