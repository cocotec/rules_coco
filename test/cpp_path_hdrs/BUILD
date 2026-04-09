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

load("@rules_cc//cc:defs.bzl", "cc_test")
load("@rules_coco//coco:cc.bzl", "coco_cc_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")

coco_package(
    name = "path_hdrs",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

coco_generate(
    name = "path_hdrs_cpp",
    language = "cpp",
    package = ":path_hdrs",
)

# Use path-suffix matching instead of bare basename to select public headers.
# This is the disambiguation syntax: "src/IPublicApi.h" matches by path suffix
# rather than just the filename, avoiding ambiguity when multiple files share
# a basename in different directories.
coco_cc_library(
    name = "path_hdrs_lib",
    generated_package = ":path_hdrs_cpp",
    public_hdrs = ["src/IPublicApi.h"],
)

cc_test(
    name = "unit",
    srcs = ["test/path_hdrs_test.cc"],
    deps = [
        ":path_hdrs_lib",
        "@googletest//:gtest_main",
    ],
)
