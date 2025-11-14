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

"""C integration rules for Coco-generated code."""

load("@rules_cc//cc:defs.bzl", "CcInfo", "cc_library")
load("@rules_coco//coco:defs.bzl", "coco_test_outputs_name")

def _coco_c_runtime_impl(ctx):
    """Helper rule that provides the C runtime from the toolchain."""
    toolchain = ctx.toolchains["@rules_coco//coco:toolchain_type"]
    if not toolchain.c_runtime:
        fail("C runtime not available. Did you enable c=True in coco.toolchain()?")

    # Forward the c_runtime target's providers
    return [toolchain.c_runtime[CcInfo], toolchain.c_runtime[DefaultInfo]]

coco_c_runtime = rule(
    implementation = _coco_c_runtime_impl,
    attrs = {},
    toolchains = ["@rules_coco//coco:toolchain_type"],
    doc = """Helper rule that provides the C runtime from the Coco toolchain.

    This rule is typically not used directly by users. Instead, use `coco_c_library`
    or `coco_c_test_library` which automatically add the C runtime as a dependency.

    Example:
        coco_c_runtime(name = "runtime")

        cc_library(
            name = "my_lib",
            srcs = ["my_code.c"],
            deps = [":runtime"],
        )

    Note: The C runtime must be enabled in your workspace by setting `c=True` in
    `coco_repositories()` (WORKSPACE) or `coco.toolchain(c=True)` (bzlmod).
    """,
)

def coco_c_library(name, generated_package, srcs = [], deps = [], **kwargs):
    """Creates a C library from Coco-generated C code.

    This automatically adds the Coco C runtime as a dependency by accessing
    it from the Coco toolchain.

    Args:
        name: The name of the library
        generated_package: The coco_generate target that generates C code
        srcs: Additional C source files
        deps: Additional dependencies
        **kwargs: Additional arguments passed to cc_library
    """

    # Create a helper target to get the runtime from the toolchain
    runtime_target = "_{}_coco_runtime".format(name)
    coco_c_runtime(
        name = runtime_target,
        visibility = ["//visibility:private"],
    )

    cc_library(
        name = name,
        srcs = srcs + [generated_package],
        deps = deps + [":{}".format(runtime_target)],
        **kwargs
    )

def coco_c_test_library(
        name,
        generated_package,
        srcs = [],
        deps = [],
        gmock = "@googletest//:gtest",
        **kwargs):
    """Creates a C test library from Coco-generated C test code.

    This automatically adds the Coco C testing runtime as a dependency by accessing
    it from the Coco toolchain.

    Args:
        name: The name of the test library
        generated_package: The coco_package target that generates C test code
        srcs: Additional C source files
        deps: Additional dependencies
        gmock: The GoogleTest/GoogleMock library to use (default: @googletest//:gtest)
        **kwargs: Additional arguments passed to cc_library
    """

    # Create a helper target to get the testing runtime from the toolchain
    runtime_target = "_{}_coco_test_runtime".format(name)
    coco_c_runtime(
        name = runtime_target,
        visibility = ["//visibility:private"],
    )

    cc_library(
        name = name,
        srcs = srcs + [coco_test_outputs_name(generated_package)],
        deps = deps + [gmock, ":{}".format(runtime_target)],
        **kwargs
    )
