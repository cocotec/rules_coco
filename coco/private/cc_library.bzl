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

"""Shared implementation for coco_cc_library and coco_c_library macros."""

load("@rules_cc//cc:defs.bzl", "cc_library")
load(":coco.bzl", _coco_cc_gen = "coco_cc_gen")

def coco_library(
        name,
        runtime,
        generated_package = None,
        generated_packages = [],
        srcs = [],
        hdrs = [],
        deps = [],
        public_hdrs = None,
        **kwargs):
    """Creates a C/C++ library from Coco-generated code.

    Args:
        name: The name of the library
        runtime: The Coco runtime label (cc_runtime or c_runtime)
        generated_package: A single coco_generate target (use this or generated_packages, not both)
        generated_packages: Multiple coco_generate targets to merge into one library
        srcs: Additional source files
        hdrs: Additional header files
        deps: Additional dependencies
        public_hdrs: List of generated header names to make public, or None for all.
                        Use bare filenames (e.g., 'ISensor.h') to match by name, or
                        path suffixes (e.g., 'src/ISensor.h') to disambiguate.
        **kwargs: Additional arguments passed to cc_library
    """
    if generated_package and generated_packages:
        fail("Cannot specify both generated_package and generated_packages")
    packages = generated_packages if generated_packages else [generated_package]

    gen_targets = []
    for i, pkg in enumerate(packages):
        gen_name = name + "._gen" if len(packages) == 1 else name + "._gen_%d" % i
        _coco_cc_gen(
            name = gen_name,
            package = pkg,
            all_hdrs_public = (public_hdrs == None),
            public_hdrs = public_hdrs if public_hdrs != None else [],
            tags = ["manual"],
        )
        gen_targets.append(gen_name)

    cc_library(
        name = name,
        srcs = srcs + gen_targets,
        hdrs = hdrs,
        deps = deps + gen_targets + [runtime],
        **kwargs
    )

def coco_test_library(
        name,
        runtime,
        generated_package = None,
        generated_packages = [],
        srcs = [],
        hdrs = [],
        deps = [],
        public_hdrs = None,
        gmock = "@googletest//:gtest",
        **kwargs):
    """Creates a C/C++ test library from Coco-generated test code.

    Args:
        name: The name of the test library
        runtime: The Coco runtime label (cc_runtime or c_runtime)
        generated_package: A single coco_generate target (use this or generated_packages, not both)
        generated_packages: Multiple coco_generate targets to merge into one library
        srcs: Additional source files
        hdrs: Additional header files
        deps: Additional dependencies
        public_hdrs: List of generated test header names to make public, or None for all.
                        Use bare filenames (e.g., 'RunnableMock.h') to match by name, or
                        path suffixes (e.g., 'src/RunnableMock.h') to disambiguate.
        gmock: The GoogleTest/GoogleMock library to use (default: @googletest//:gtest).
               Set to None to omit gmock dependency.
        **kwargs: Additional arguments passed to cc_library
    """
    if generated_package and generated_packages:
        fail("Cannot specify both generated_package and generated_packages")
    packages = generated_packages if generated_packages else [generated_package]

    gen_targets = []
    for i, pkg in enumerate(packages):
        gen_name = name + "._gen" if len(packages) == 1 else name + "._gen_%d" % i
        _coco_cc_gen(
            name = gen_name,
            package = pkg,
            use_test_outputs = True,
            all_hdrs_public = (public_hdrs == None),
            public_hdrs = public_hdrs if public_hdrs != None else [],
            tags = ["manual"],
        )
        gen_targets.append(gen_name)

    gmock_deps = [gmock] if gmock else []

    cc_library(
        name = name,
        srcs = srcs + gen_targets,
        hdrs = hdrs,
        deps = deps + gen_targets + gmock_deps + [runtime],
        **kwargs
    )
