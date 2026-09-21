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
    "//coco/private:cc_runtime_deps.bzl",
    "collect_cc_runtime_extra_deps",
)
load(
    "//coco/private:toolchain_hub.bzl",
    "declare_coco_toolchains",
    "resolve_versions",
)
load(
    "//coco/private:version_aliases.bzl",
    "VERSION_ALIASES",
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
    c = False
    license_source = ""
    license_token = ""
    auth_token_path = ""

    for mod in ctx.modules:
        for toolchain in mod.tags.toolchain:
            all_versions.extend(toolchain.versions)
            cc = cc or toolchain.cc
            c = c or toolchain.c

            # Take the first non-empty license configuration
            if not license_source and toolchain.license_source:
                license_source = toolchain.license_source
            if not license_token and toolchain.license_token:
                license_token = toolchain.license_token
            if not auth_token_path and toolchain.auth_token_path:
                auth_token_path = toolchain.auth_token_path

    # Root-module only: a dependency must not force a machine-specific path on consumers.
    local_tag = None
    for mod in ctx.modules:
        for tag in mod.tags.local_toolchain:
            if not mod.is_root:
                fail("coco.local_toolchain is only allowed in the root module (requested by module '%s')." % mod.name)
            if local_tag != None:
                fail("coco.local_toolchain may be specified at most once.")
            local_tag = tag

    # Resolve version aliases (like "stable" -> "1.5.1"), validate and deduplicate.
    versions, error = resolve_versions(all_versions, _resolve_version)
    if error:
        fail(error)

    # str(label) gives canonical @@repo+//pkg:target form; the generated runtime
    # BUILD file lives in a different repo and has no mapping for the user's @boost.
    cc_runtime_deps_entries = [
        struct(
            module_name = mod.name,
            is_root = mod.is_root,
            version = tag.version,
            deps = [str(d) for d in tag.deps],
        )
        for mod in ctx.modules
        for tag in mod.tags.cc_runtime_deps
    ]

    cc_runtime_extra_deps_by_version, err = collect_cc_runtime_extra_deps(
        cc_runtime_deps_entries,
        {version: True for version in versions},
        _resolve_version,
    )
    if err:
        fail(err)

    local = None
    if local_tag:
        local = struct(
            popili = local_tag.popili,
            cc_runtime = local_tag.cc_runtime,
            c_runtime = local_tag.c_runtime,
        )

    declare_coco_toolchains(
        versions = versions,
        c = c,
        cc = cc,
        cc_runtime_extra_deps_by_version = cc_runtime_extra_deps_by_version,
        license_source = license_source,
        license_token = license_token,
        auth_token_path = auth_token_path,
        local = local,
    )

    # A local path isn't reproducible.
    return ctx.extension_metadata(
        reproducible = local_tag == None,
    )

_toolchain_tag = tag_class(
    attrs = {
        "auth_token_path": attr.string(
            doc = "Optional path to auth token file for all toolchains when license_source is 'action_file'. The file must be available in the execution environment.",
            default = "",
        ),
        "c": attr.bool(
            default = False,
            doc = "Whether to include C runtime support",
        ),
        "cc": attr.bool(
            default = False,
            doc = "Whether to include C++ runtime support",
        ),
        "license_source": attr.string(
            doc = "Optional default license source mode for all toolchains (e.g., 'local_user', 'local_acquire', 'token', 'action_environment', 'action_file'). Can be overridden via --@rules_coco//:license_source flag.",
            default = "",
        ),
        "license_token": attr.string(
            doc = "Optional default license token for all toolchains when license_source is 'token'.",
            default = "",
        ),
        "versions": attr.string_list(
            default = ["stable"],
            doc = "List of Coco/Popili versions to register (e.g., ['1.5.0', '1.4.0']). Use version aliases like 'stable' or explicit versions like '1.5.1'. The first version is the one used when --@rules_coco//:version is unset.",
        ),
    },
)

_cc_runtime_deps_tag = tag_class(
    doc = (
        "Inject extra cc_library deps into the Coco C++ runtime for a specific " +
        "Coco/Popili version. Root-module only. See the rules_coco README for " +
        "when this is needed (typically Boost libraries when building against old libstdc++)."
    ),
    attrs = {
        "deps": attr.label_list(
            doc = "List of cc_library targets to append to the runtime's deps.",
            mandatory = True,
        ),
        "version": attr.string(
            doc = "Coco/Popili version these deps apply to. May be an explicit version (e.g. '1.5.1') or an alias (e.g. 'stable').",
            mandatory = True,
        ),
    },
)

_local_toolchain_tag = tag_class(
    doc = (
        "Register a Coco toolchain from a popili distribution on the local filesystem, " +
        "instead of fetching a published release. Root-module only, at most once. Used " +
        "only under --@rules_coco//:version=local. Paths mirror the extracted release " +
        "archive layout; see the rules_coco README."
    ),
    attrs = {
        "c_runtime": attr.string(
            doc = "Optional path to a dir holding the C runtime 'coco_c/' subtree. Absolute or workspace-relative.",
            default = "",
        ),
        "cc_runtime": attr.string(
            doc = "Optional path to a dir holding the C++ runtime 'coco/' subtree. Absolute or workspace-relative.",
            default = "",
        ),
        "popili": attr.string(
            doc = "Path to a dir holding the 'popili' and 'cocotec-licensing-server' binaries. Absolute or workspace-relative.",
            mandatory = True,
        ),
    },
)

coco = module_extension(
    implementation = _toolchain_tag_impl,
    tag_classes = {
        "cc_runtime_deps": _cc_runtime_deps_tag,
        "local_toolchain": _local_toolchain_tag,
        "toolchain": _toolchain_tag,
    },
)
