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

"""C++ integration macros for Coco-generated code."""

load("//coco/private:cc_library.bzl", "coco_library", "coco_test_library")

_CC_RUNTIME = Label("//coco:cc_runtime")

def coco_cc_library(
        name,
        generated_package = None,
        generated_packages = [],
        srcs = [],
        hdrs = [],
        deps = [],
        public_hdrs = None,
        **kwargs):
    """Creates a C++ library from Coco-generated C++ code.

    This automatically adds the Coco C++ runtime as a dependency.

    Generated headers are made available to downstream targets via CcInfo.
    The `public_hdrs` parameter controls which generated headers are public:

    - None (default): all generated headers are public
    - ["ISensor.h", "Types.h"]: only listed headers are public, rest are private
    - []: no generated headers are public (all private)

    Use bare filenames to match by name, or path suffixes (e.g., "src/ISensor.h")
    to disambiguate when multiple generated files share a name.

    Args:
        name: The name of the library
        generated_package: A coco_generate target (mutually exclusive with generated_packages)
        generated_packages: Multiple coco_generate targets to merge into one library
        srcs: Additional C++ source files
        hdrs: Additional C++ header files
        deps: Additional dependencies
        public_hdrs: List of generated header names to make public, or None for all
        **kwargs: Additional arguments passed to cc_library
    """
    coco_library(
        name = name,
        runtime = _CC_RUNTIME,
        generated_package = generated_package,
        generated_packages = generated_packages,
        srcs = srcs,
        hdrs = hdrs,
        deps = deps,
        public_hdrs = public_hdrs,
        **kwargs
    )

def coco_cc_test_library(
        name,
        generated_package = None,
        generated_packages = [],
        srcs = [],
        hdrs = [],
        deps = [],
        public_hdrs = None,
        gmock = "@googletest//:gtest",
        **kwargs):
    """Creates a C++ test library from Coco-generated C++ test code.

    This automatically adds the Coco C++ runtime and GoogleTest as dependencies.

    Generated test headers are made available to downstream targets via CcInfo.
    The `public_hdrs` parameter controls which generated test headers are public:

    - None (default): all generated test headers are public
    - ["RunnableMock.h"]: only listed headers are public, rest are private
    - []: no generated test headers are public (all private)

    Args:
        name: The name of the test library
        generated_package: A coco_generate target with mocks enabled (mutually exclusive with generated_packages)
        generated_packages: Multiple coco_generate targets to merge into one library
        srcs: Additional C++ source files
        hdrs: Additional C++ header files
        deps: Additional dependencies
        public_hdrs: List of generated test header names to make public, or None for all
        gmock: The GoogleTest/GoogleMock library (default: @googletest//:gtest).
               Set to None to omit.
        **kwargs: Additional arguments passed to cc_library
    """
    coco_test_library(
        name = name,
        runtime = _CC_RUNTIME,
        generated_package = generated_package,
        generated_packages = generated_packages,
        srcs = srcs,
        hdrs = hdrs,
        deps = deps,
        public_hdrs = public_hdrs,
        gmock = gmock,
        **kwargs
    )
