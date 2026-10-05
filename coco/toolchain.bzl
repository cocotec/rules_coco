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

"""Coco toolchain implementation.

`coco_toolchain` describes one popili binary, for one execution platform, with the runtime and
licence settings that go with it. rules_coco's toolchain repositories declare one per published
platform of every registered version, and bring-your-own toolchains are declared with it too.

This file loads only `version_resolution.bzl`, so generated repositories can load it before
bazel_skylib has been fetched in WORKSPACE mode.
"""

load("//coco/private:version_resolution.bzl", "FORCE_VERSION_FLAG", "VERSION_FLAG")

def _reset_version_impl(_settings, _attr):
    return {
        FORCE_VERSION_FLAG: False,
        VERSION_FLAG: "",
    }

# Toolchains of the same licence version point at the same licence target, but are analysed
# in whatever configuration selected them. Resetting the version flags on the way to the
# licence makes all of them reach one configured target, so the licence is acquired once per
# platform the toolchains were resolved for.
_reset_version = transition(
    implementation = _reset_version_impl,
    inputs = [],
    outputs = [FORCE_VERSION_FLAG, VERSION_FLAG],
)

def _is_set(attr_value):
    # An attribute with a transition is a list, which is empty when unset.
    return bool(attr_value) if type(attr_value) == type([]) else attr_value != None

def _single_file(attr_value):
    """Returns the only file of a label attribute, or None if it is unset or empty."""
    if type(attr_value) == type([]):
        attr_value = attr_value[0] if attr_value else None
    if attr_value == None:
        return None
    files = attr_value[DefaultInfo].files.to_list()
    return files[0] if files else None

def _coco_toolchain_impl(ctx):
    toolchain = platform_common.ToolchainInfo(
        coco = ctx.file.coco,
        cocotec_licensing_server = ctx.file.cocotec_licensing_server,
        preferences_file = ctx.file.preferences_file,
        cc_runtime = ctx.attr.cc_runtime,
        c_runtime = ctx.attr.c_runtime,
        license_source = ctx.attr.license_source,
        license_token = ctx.attr.license_token,
        auth_token_path = ctx.attr.auth_token_path,
        platform = ctx.attr.platform,
        version = ctx.attr.version,
        # Whether the licences below come from this toolchain. Toolchains registered outside
        # rules_coco leave them unset, and use the consuming rule's licences instead.
        declares_licenses = _is_set(ctx.attr.license_fetch) or _is_set(ctx.attr.license_local),
        license_fetch = _single_file(ctx.attr.license_fetch),
        license_local = _single_file(ctx.attr.license_local),
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
        "license_fetch": attr.label(
            doc = "The licence to use for license_source 'local_acquire'. Set by rules_coco's " +
                  "toolchain repositories; leave unset for a toolchain of your own.",
            cfg = _reset_version,
        ),
        "license_local": attr.label(
            doc = "The licence to use for license_source 'local_user'. Set by rules_coco's " +
                  "toolchain repositories; leave unset for a toolchain of your own.",
        ),
        "license_source": attr.string(
            doc = "The license source mode for this toolchain. Can be 'local_user', 'local_acquire', 'token', 'action_environment', or 'action_file'. If not specified, defaults to 'local_user'. Can be overridden via --@rules_coco//:license_source flag.",
            default = "",
        ),
        "license_token": attr.string(
            doc = "The license token to use when license_source is 'token'. Optional.",
            default = "",
        ),
        "platform": attr.string(
            doc = "The platform this popili runs on, as `<os>_<cpu>` in the vocabulary of `@platforms`, e.g. " +
                  "'linux_x86_64' or 'windows_x86_64'. Set by rules_coco's toolchain repositories; it decides " +
                  "whether the rules drive popili with .bat or .sh scripts. Optional: when unset, a `popili.exe` " +
                  "binary is taken to run on Windows and any other on a POSIX platform.",
            default = "",
        ),
        "preferences_file": attr.label(
            doc = "The location of the Popili `preferences.toml` file. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            default = "@io_cocotec_coco_preferences//:preferences",
        ),
        "version": attr.string(
            doc = "The popili version this toolchain provides, e.g. '1.5.1', or 'local'. Used to match " +
                  "the toolchain against popili_version pins and to pick the matching runtime. Optional; " +
                  "set automatically for toolchains registered by rules_coco.",
            default = "",
        ),
    },
)
