# Copyright 2025 Cocotec Limited
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

"""Internal C++ runtime rule implementation."""

load("@rules_cc//cc:defs.bzl", "CcInfo")

def _coco_cc_runtime_impl(ctx):
    """Helper rule that provides the C++ runtime from the toolchain."""
    toolchain = ctx.toolchains["@rules_coco//coco:toolchain_type"]
    if not toolchain.cc_runtime:
        fail("C++ runtime not available. Did you enable cc=True in coco.toolchain()?")

    # Forward the cc_runtime target's providers
    return [toolchain.cc_runtime[CcInfo], toolchain.cc_runtime[DefaultInfo]]

coco_cc_runtime = rule(
    implementation = _coco_cc_runtime_impl,
    attrs = {},
    toolchains = ["@rules_coco//coco:toolchain_type"],
    doc = """Internal helper rule that provides the C++ runtime from the Coco toolchain.

    This rule is not part of the public API and should not be used directly.
    Use `coco_cc_library` or `coco_cc_test_library` instead.
    """,
)
