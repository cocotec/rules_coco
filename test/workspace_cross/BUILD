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

# Cross-workspace dependency: `lib` is in workspace `ws_lib`, `app` is in a
# DIFFERENT workspace `ws_app` and depends on it. Exercises dep-propagation:
# resolving `app` needs lib's ws_lib Coco.toml, which reaches app's action only
# because coco_package unions each dep's workspace_files into its own.

coco_workspace(
    name = "ws_lib",
    workspace = "ws_lib/Coco.toml",
)

coco_workspace(
    name = "ws_app",
    workspace = "ws_app/Coco.toml",
)

coco_package(
    name = "lib",
    srcs = glob(["lib/src/**/*.coco"]),
    package = "lib/Coco.toml",
    workspace = ":ws_lib",
)

coco_package(
    name = "app",
    srcs = glob(["app/src/**/*.coco"]),
    package = "app/Coco.toml",
    workspace = ":ws_app",
    deps = [":lib"],
)

coco_verify_test(
    name = "lib_verify",
    package = ":lib",
)

coco_verify_test(
    name = "app_verify",
    package = ":app",
)

coco_generate(
    name = "lib_cpp",
    language = "cpp",
    mocks = True,
    package = ":lib",
)

coco_generate(
    name = "app_cpp",
    language = "cpp",
    package = ":app",
)

coco_cc_library(
    name = "lib_cc",
    generated_package = ":lib_cpp",
    includes = ["lib/src"],
)

coco_cc_library(
    name = "app_cc",
    generated_package = ":app_cpp",
    includes = ["app/src"],
    deps = [":lib_cc"],
)

cc_test(
    name = "unit",
    srcs = ["app_test.cc"],
    deps = [
        ":app_cc",
        ":lib_cc",
        "@googletest//:gtest_main",
    ],
)
