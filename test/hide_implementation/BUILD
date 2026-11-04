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
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")

# componentStyle = "HideImplementation" hides each non-generic component behind
# a pimpl, but generates a generic one whole into its module's header, since a
# class template cannot be pimpl'd. Either way popili writes the same files as
# under "Regular", so coco_generate needs no setting for it.
#
# The package uses standard 2026, which needs popili 1.6, so the generate and
# the libraries are pinned to "testing" (the libraries link its runtime). The
# package stays manual: built on its own it is typechecked by the default
# popili, which rejects standard 2026. Drop the pins and the manual tag once
# 1.6 is stable.

coco_package(
    name = "hide_implementation_test",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
    tags = ["manual"],
)

coco_generate(
    name = "hide_implementation_test_cpp",
    language = "cpp",
    mocks = True,
    package = ":hide_implementation_test",
    popili_version = "testing",
)

coco_cc_library(
    name = "hide_implementation_test_cc",
    generated_package = ":hide_implementation_test_cpp",
    popili_version = "testing",
)

coco_cc_test_library(
    name = "hide_implementation_test_cc_tst",
    generated_package = ":hide_implementation_test_cpp",
    popili_version = "testing",
    deps = [":hide_implementation_test_cc"],
)

cc_test(
    name = "unit",
    srcs = ["test/app_test.cc"],
    deps = [
        ":hide_implementation_test_cc",
        ":hide_implementation_test_cc_tst",
        "@googletest//:gtest_main",
    ],
)
