# Copyright 2026 Cocotec Limited
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

"""A C++ toolchain config that can only be analysed, for building tests for a riscv64 platform.

A coco_verify_test depends on the runtimes, which need a C++ toolchain for the target platform.
The diagnostics tests only analyse, so this one never compiles.
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
