# Copyright 2019 Cocotec Limited
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

"""Coco toolchain implementation."""

load("//coco/private:license_paths.bzl", "LicensePathsInfo")
load("//coco/private:license_sources.bzl", "LICENSE_SOURCES")
load("//coco/private:version_resolution.bzl", "LOCAL_VERSION", "version_tuple")

def _coco_toolchain_impl(ctx):
    version = ctx.attr.popili_version
    if version != LOCAL_VERSION and version_tuple(version) == None:
        fail(
            "%s: popili_version must be the version of the popili binary, such as \"1.5.8\", not %r: " % (ctx.label, version) +
            "rules_coco checks it against the version every target asks for, and an alias such as " +
            "\"stable\" moves when rules_coco is upgraded.",
        )
    toolchain = platform_common.ToolchainInfo(
        # Names the toolchain in messages about the popili version it provides.
        label = ctx.label,
        coco = ctx.file.coco,
        cocotec_licensing_server = ctx.file.cocotec_licensing_server,
        preferences_file = ctx.file.preferences_file,
        cc_runtime = ctx.attr.cc_runtime,
        c_runtime = ctx.attr.c_runtime,
        license_source = ctx.attr.license_source,
        license_token = ctx.attr.license_token,
        auth_token_path = ctx.attr.auth_token_path,
        popili_version = ctx.attr.popili_version,
        license_protocol_version = ctx.attr.license_protocol_version,
        local_acquire_licenses = ctx.attr.local_acquire_licenses[LicensePathsInfo] if ctx.attr.local_acquire_licenses else None,
    )
    return toolchain

coco_toolchain = rule(
    _coco_toolchain_impl,
    attrs = {
        "auth_token_path": attr.string(
            doc = "The path to auth token file to use when license_source is 'action_file'. The file must be available in the execution environment. Optional.",
            default = "",
        ),
        "c_runtime": attr.label(
            doc = "The C runtime library for Coco. Optional - only needed when using coco_c_library.",
            default = None,
        ),
        "cc_runtime": attr.label(
            doc = (
                "The C++ runtime library for Coco. Optional - only needed when using coco_cc_library. " +
                "To inject extra deps into this target (e.g. Boost libraries for old libstdc++), " +
                "use the coco.cc_runtime_deps tag in MODULE.bazel."
            ),
            default = None,
        ),
        "coco": attr.label(
            doc = "The location of the `coco` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            mandatory = True,
        ),
        "cocotec_licensing_server": attr.label(
            doc = "The location of the `cocotec-licensing-server` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            mandatory = True,
        ),
        "license_protocol_version": attr.int(
            doc = (
                "The licence protocol version the `popili` binary reads, `n` in `licenses_<n>.lic`, " +
                "which picks its licence file under the local licence modes. Optional: 0 derives it from " +
                "`popili_version`, or takes the newest protocol version rules_coco knows of when that is " +
                "unknown. Set it when the popili reads a different protocol version than that."
            ),
            default = 0,
        ),
        "license_source": attr.string(
            doc = "The license source mode for this toolchain. Can be 'local_user', 'local_acquire', 'token', 'action_environment', or 'action_file'. If not specified, defaults to 'local_user'. Can be overridden via --@rules_coco//:license_source flag.",
            default = "",
            values = LICENSE_SOURCES + [""],
        ),
        "license_token": attr.string(
            doc = "The license token to use when license_source is 'token'. Optional.",
            default = "",
        ),
        "local_acquire_licenses": attr.label(
            doc = (
                "The licences acquired for `local_acquire` licensing; popili gets the one of its licence " +
                "protocol version by path. Optional: without it, popili gets no licence path under " +
                "`local_acquire` and reads the licence in its own data directory, if any. The toolchains rules_coco generates set it; a bring-your-own toolchain can " +
                "use `@rules_coco//coco:local_acquire_licenses_<n>`, `n` being its popili's licence protocol " +
                "version, which acquires a licence only under `local_acquire`."
            ),
            providers = [LicensePathsInfo],
            default = None,
        ),
        "popili_version": attr.string(
            doc = (
                "The version of the `popili` binary, such as \"1.5.8\"; not an alias such as " +
                "\"stable\". It picks the licence file under the local licence modes, and every target " +
                "this toolchain serves must ask for this version, or for none in particular. The " +
                "toolchains rules_coco generates set it; a local distribution is 'local'."
            ),
            mandatory = True,
        ),
        "preferences_file": attr.label(
            doc = "The location of the Popili `preferences.toml` file. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            default = "@io_cocotec_coco_preferences//:preferences",
        ),
    },
)
