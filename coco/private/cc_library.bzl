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
load(":coco.bzl", _coco_cc_gen = "coco_cc_gen", _coco_cc_pin = "coco_cc_pin")
load(":common_attrs.bzl", "companion_attrs")

def _generated_targets(name, runtime, packages, popili_version, public_hdrs, kwargs, use_test_outputs = False):
    """Declares the targets that feed the generated packages, with the runtime, to the cc_library.

    One _coco_cc_pin at the library's `popili_version` (beneath which the generators and the
    runtime are analysed, and which checks they share one version), and one _coco_cc_gen in the
    library's configuration.

    Args:
        name: The name of the library.
        runtime: The Coco runtime label (cc_runtime or c_runtime).
        packages: The coco_generate targets.
        popili_version: The library's pin, "" for none.
        public_hdrs: As for the library.
        kwargs: The library's kwargs, for the common attrs.
        use_test_outputs: Whether to take the generated test/mock outputs.

    Returns:
        The _coco_cc_gen target's name, for the cc_library's srcs and deps.
    """
    pin_name = name + "._pin"
    _coco_cc_pin(
        name = pin_name,
        library = name,
        packages = packages,
        popili_version = popili_version,
        runtime = runtime,
        **companion_attrs(kwargs, extra_tags = ["manual"])
    )
    gen_name = name + "._gen"
    _coco_cc_gen(
        name = gen_name,
        library = name,
        packages = packages,
        pinned = pin_name,
        popili_version = popili_version,
        use_test_outputs = use_test_outputs,
        all_hdrs_public = (public_hdrs == None),
        public_hdrs = public_hdrs if public_hdrs != None else [],
        **companion_attrs(kwargs, extra_tags = ["manual"])
    )
    return gen_name

def coco_library(
        name,
        runtime,
        generated_package = None,
        generated_packages = [],
        srcs = [],
        hdrs = [],
        deps = [],
        public_hdrs = None,
        popili_version = "",
        library_rule = None,
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
                        Use bare filenames (e.g., 'ISensor.h') to match by name, or trailing parts
                        of the include path (e.g., 'sensors/ISensor.h') to disambiguate. An entry
                        that matches no header is an error.
        popili_version: The popili version whose runtime the library links, also applied to the
                        generators beneath it; "" for the configured version.
        library_rule: The rule or macro that compiles the library, called with cc_library's
                      attributes. None means rules_cc's cc_library.
        **kwargs: Additional arguments passed to library_rule
    """
    if generated_package and generated_packages:
        fail("Cannot specify both generated_package and generated_packages")
    packages = generated_packages if generated_packages else [generated_package]

    gen_name = _generated_targets(name, runtime, packages, popili_version, public_hdrs, kwargs)

    # The runtime comes with the gen target, at the library's popili_version.
    (library_rule or cc_library)(
        name = name,
        srcs = srcs + [gen_name],
        hdrs = hdrs,
        deps = deps + [gen_name],
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
        popili_version = "",
        library_rule = None,
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
                        Use bare filenames (e.g., 'RunnableMock.h') to match by name, or trailing
                        parts of the include path (e.g., 'runnable/RunnableMock.h') to disambiguate.
                        An entry that matches no header is an error.
        gmock: The GoogleTest/GoogleMock library to use (default: @googletest//:gtest).
               Set to None to omit gmock dependency.
        popili_version: The popili version whose runtime the library links, also applied to the
                        generators beneath it; "" for the configured version.
        library_rule: The rule or macro that compiles the library, called with cc_library's
                      attributes. None means rules_cc's cc_library.
        **kwargs: Additional arguments passed to library_rule
    """
    if generated_package and generated_packages:
        fail("Cannot specify both generated_package and generated_packages")
    packages = generated_packages if generated_packages else [generated_package]

    gen_name = _generated_targets(name, runtime, packages, popili_version, public_hdrs, kwargs, use_test_outputs = True)

    gmock_deps = [gmock] if gmock else []

    # gmock and deps stay in the library's configuration; only the runtime follows popili_version.
    (library_rule or cc_library)(
        name = name,
        srcs = srcs + [gen_name],
        hdrs = hdrs,
        deps = deps + [gen_name] + gmock_deps,
        **kwargs
    )
