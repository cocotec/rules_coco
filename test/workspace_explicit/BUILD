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

# Explicit, non-child workspace: `pkg` is a SIBLING of root `ws`, wired by
# relative path (pkg: `workspace = "../ws"`, ws: `members = ["../pkg"]`) — a
# workspace need not be a filesystem ancestor of its members. typecheck = True
# also covers the typecheck action's workspace inputs.

coco_workspace(
    name = "ws",
    workspace = "ws/Coco.toml",
)

coco_package(
    name = "pkg",
    srcs = glob(["pkg/src/**/*.coco"]),
    package = "pkg/Coco.toml",
    typecheck = True,
    workspace = ":ws",
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
    includes = ["pkg/src"],
)

cc_test(
    name = "unit",
    srcs = ["pkg_test.cc"],
    deps = [
        ":pkg_cc",
        "@googletest//:gtest_main",
    ],
)
