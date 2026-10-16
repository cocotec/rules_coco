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

"""Internal C runtime rule implementation."""

load("@rules_cc//cc:defs.bzl", "CcInfo")
load("//coco/private:coco.bzl", "COCO_TOOLCHAIN_TYPE", "TOOLCHAIN_ATTRIBUTES", "coco_toolchain_or_fail", "popili_version_pin")

def _coco_c_runtime_impl(ctx):
    """Helper rule that provides the C runtime from the toolchain."""
    toolchain = coco_toolchain_or_fail(ctx)
    if not toolchain.c_runtime:
        fail("C runtime not available. Did you enable c=True in coco.toolchain()?")

    # Forward the c_runtime target's providers
    return [toolchain.c_runtime[CcInfo], toolchain.c_runtime[DefaultInfo]]

coco_c_runtime = rule(
    implementation = _coco_c_runtime_impl,
    attrs = TOOLCHAIN_ATTRIBUTES,
    cfg = popili_version_pin,
    toolchains = [COCO_TOOLCHAIN_TYPE],
    doc = """Internal helper rule that provides the C runtime from the Coco toolchain.

    This rule is not part of the public API and should not be used directly.
    Use `coco_c_library` or `coco_c_test_library` instead.
    """,
)
