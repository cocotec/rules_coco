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

load("@rules_cc//cc:defs.bzl", "cc_test")
load("@rules_coco//coco:cc.bzl", "coco_cc_library", "coco_cc_test_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package", "with_popili_version")

# componentStyle = "HideImplementation" hides each non-generic component behind
# a pimpl, but generates a generic one whole into its module's header, since a
# class template cannot be pimpl'd. Either way popili writes the same files as
# under "Regular", so coco_generate needs no setting for it.
#
# The package uses standard 2026, which needs popili 1.6, so the generate is
# pinned to "testing". The package stays manual: built on its own it is
# typechecked by the default popili, which rejects standard 2026. The libraries
# are wrapped so that they link the "testing" runtime, and are manual unwrapped.
# Drop the pins, wrappers and manual tags once 1.6 is stable.

coco_package(
    name = "hide_implementation_test",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
    tags = ["manual"],
)

coco_generate(
    name = "hide_implementation_test_cpp",
    include_prefix = "hide_implementation",
    language = "cpp",
    mocks = True,
    package = ":hide_implementation_test",
    popili_version = "testing",
)

coco_cc_library(
    name = "hide_implementation_test_cc_impl",
    generated_package = ":hide_implementation_test_cpp",
    tags = ["manual"],
)

with_popili_version(
    name = "hide_implementation_test_cc",
    target = ":hide_implementation_test_cc_impl",
    version = "testing",
)

coco_cc_test_library(
    name = "hide_implementation_test_cc_tst_impl",
    generated_package = ":hide_implementation_test_cpp",
    tags = ["manual"],
    deps = [":hide_implementation_test_cc"],
)

with_popili_version(
    name = "hide_implementation_test_cc_tst",
    target = ":hide_implementation_test_cc_tst_impl",
    version = "testing",
)

# The mocks carry gtest in the "testing" configuration; gtest_main from the
# default one would link a second gtest, which Linux rejects.
with_popili_version(
    name = "gtest_main_testing",
    target = "@googletest//:gtest_main",
    version = "testing",
)

cc_test(
    name = "unit",
    srcs = ["test/app_test.cc"],
    deps = [
        ":gtest_main_testing",
        ":hide_implementation_test_cc",
        ":hide_implementation_test_cc_tst",
    ],
)
