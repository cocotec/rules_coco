"""A C++ toolchain config that can only be analysed, for targeting a platform no host can build for.

The Coco toolchain carries the C++ runtime, so resolving it for a foreign target platform needs a
C++ toolchain for that platform. test_platform_test.bzl only analyses, so this one never compiles.
"""

load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/toolchains:cc_toolchain_config_info.bzl", "CcToolchainConfigInfo")

def _stub_cc_toolchain_config_impl(ctx):
    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        toolchain_identifier = "stub",
        compiler = "stub",
        target_cpu = "stub",
        target_libc = "stub",
        abi_version = "stub",
        abi_libc_version = "stub",
    )

stub_cc_toolchain_config = rule(
    implementation = _stub_cc_toolchain_config_impl,
    provides = [CcToolchainConfigInfo],
)
