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
load(":coco.bzl", "POPILI_TOOLCHAINS", "exec_popili")

def _coco_c_runtime_impl(ctx):
    """Helper rule that provides the C runtime of the configured popili version."""

    # A bring-your-own toolchain may name its runtime itself. rules_coco's own toolchains do
    # not (see toolchain_repositories.bzl): the hub aliases the configured version's runtime.
    toolchain = exec_popili(ctx)
    runtime = toolchain.c_runtime if toolchain != None and toolchain.c_runtime else ctx.attr._hub_runtime
    if CcInfo not in runtime:
        fail("C runtime not available. Did you enable c=True in coco.toolchain()?")

    # Forward the runtime target's providers
    return [runtime[CcInfo], runtime[DefaultInfo]]

coco_c_runtime = rule(
    implementation = _coco_c_runtime_impl,
    attrs = {
        "_hub_runtime": attr.label(default = "@coco_toolchains//:c_runtime"),
    },
    toolchains = POPILI_TOOLCHAINS,
    doc = """Internal helper rule that provides the C runtime from the Coco toolchain.

    Resolves to the runtime of the version `--@rules_coco//:version` selects. This rule is not
    part of the public API and should not be used directly.
    Use `coco_c_library` or `coco_c_test_library` instead.
    """,
)
