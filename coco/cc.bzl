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
        popili_version = "",
        library_rule = None,
        **kwargs):
    """Creates a C++ library from Coco-generated C++ code.

    The library depends on the Coco C++ runtime of its Popili version.

    Args:
        name: The name of the library target.
        generated_package: A coco_generate target (mutually exclusive with generated_packages)
        generated_packages: Multiple coco_generate targets to merge into one library
        srcs: Hand-written C++ sources to add to the library.
        hdrs: Hand-written C++ headers to add to the library.
        deps: Other `cc_library` targets the library depends on, such as the library of each package this
            package depends on.
        public_hdrs: The generated headers dependents may include, each named by file name or by a
            trailing part of its include path, such as `"sensors/ISensor.h"`. An entry that matches no
            header is an error. Default: `None`, all of them; `[]` makes them all private.
        popili_version: The registered Popili version whose runtime the library links, such as
            `"1.5.1"` or `"stable"`. The `coco_generate` targets in `generated_package` or
            `generated_packages` that have no `popili_version` of their own run with this version too,
            so pin the library like its `coco_generate` targets. `deps` is not affected: it is built
            as if the library had no pin. Default: `""`, the version the rest of the build uses. See
            [Pinning targets](../popili-versions.md#pinning-targets).
        library_rule: The rule or macro that compiles the library, such as a wrapper of
            cc_library adding your project's defaults. It is called with cc_library's
            attributes. None means rules_cc's cc_library.
        **kwargs: Additional arguments passed to library_rule
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
        popili_version = popili_version,
        library_rule = library_rule,
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
        popili_version = "",
        library_rule = None,
        **kwargs):
    """Creates a C++ test library from Coco-generated C++ test code.

    The library depends on the Coco C++ test runtime of its Popili version, and on `gmock`.

    Args:
        name: The name of the test library target.
        generated_package: A `coco_generate` target whose package sets `cpp_mocks` (mutually exclusive with
            `generated_packages`)
        generated_packages: Multiple coco_generate targets to merge into one library
        srcs: Hand-written C++ sources to add to the library.
        hdrs: Hand-written C++ headers to add to the library.
        deps: Other `cc_library` targets the library depends on, such as the library of each package this
            package depends on.
        public_hdrs: The generated test headers dependents may include, each named by file name or by
            a trailing part of its include path, such as `"runnable/RunnableMock.h"`. An entry that
            matches no header is an error. Default: `None`, all of them; `[]` makes them all private.
        gmock: The GoogleTest/GoogleMock library (default: @googletest//:gtest).
               Set to None to omit.
        popili_version: The registered Popili version whose runtime the library links, such as
            `"1.5.1"` or `"stable"`. The `coco_generate` targets in `generated_package` or
            `generated_packages` that have no `popili_version` of their own run with this version too,
            so pin the library like its `coco_generate` targets. `deps` and `gmock` are not affected:
            they are built as if the library had no pin. Default: `""`, the version the rest of the build uses. See
            [Pinning targets](../popili-versions.md#pinning-targets).
        library_rule: The rule or macro that compiles the library, such as a wrapper of
            cc_library adding your project's defaults. It is called with cc_library's
            attributes. None means rules_cc's cc_library.
        **kwargs: Additional arguments passed to library_rule
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
        popili_version = popili_version,
        gmock = gmock,
        library_rule = library_rule,
        **kwargs
    )
