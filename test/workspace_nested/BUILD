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
load("@rules_coco//coco:cc.bzl", "coco_cc_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package", "coco_verify_test", "coco_workspace")

# Nested workspaces (outer -> inner -> pkg): the outer's [language] standard and
# the inner's [generator] settings both flow down to pkg. pkg uses a .Coco1_2
# feature, so it builds only if the outer's standard reaches it through inner.

coco_workspace(
    name = "outer",
    workspace = "Coco.toml",
)

coco_workspace(
    name = "inner",
    parent = ":outer",
    workspace = "inner/Coco.toml",
)

coco_package(
    name = "pkg",
    srcs = glob(["inner/pkg/src/**/*.coco"]),
    package = "inner/pkg/Coco.toml",
    workspace = ":inner",
)

coco_verify_test(
    name = "pkg_verify",
    package = ":pkg",
)

coco_generate(
    name = "pkg_cpp",
    language = "cpp",
    mocks = True,
    package = ":pkg",
)

coco_cc_library(
    name = "pkg_cc",
    generated_package = ":pkg_cpp",
    includes = ["inner/pkg/src"],
)

cc_test(
    name = "unit",
    srcs = ["pkg_test.cc"],
    deps = [
        ":pkg_cc",
        "@googletest//:gtest_main",
    ],
)
