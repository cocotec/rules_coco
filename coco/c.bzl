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

"""C integration macros for Coco-generated code."""

load("@rules_cc//cc:defs.bzl", "cc_library")
load(":defs.bzl", "coco_test_outputs_name")

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

    cc_library(
        name = name,
        srcs = srcs + [generated_package],
        deps = deps + [Label("//coco:c_runtime")],
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

    This automatically adds the Coco C runtime as a dependency by accessing
    it from the Coco toolchain.

    Args:
        name: The name of the test library
        generated_package: The coco_package target that generates C test code
        srcs: Additional C source files
        deps: Additional dependencies
        gmock: The GoogleTest/GoogleMock library to use (default: @googletest//:gtest)
        **kwargs: Additional arguments passed to cc_library
    """

    cc_library(
        name = name,
        srcs = srcs + [coco_test_outputs_name(generated_package)],
        deps = deps + [gmock, Label("//coco:c_runtime")],
        **kwargs
    )
