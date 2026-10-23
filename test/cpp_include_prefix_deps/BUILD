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

# base's Coco.toml sets includePrefix = "core", which app's generated code includes base by, and base's
# coco_generate sets the same include_prefix, so no library needs `includes`.

load("@rules_cc//cc:defs.bzl", "cc_test")
load("@rules_coco//coco:cc.bzl", "coco_cc_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package", "coco_verify_test")

coco_package(
    name = "base",
    srcs = glob(["base/src/**/*.coco"]),
    package = "base/Coco.toml",
)

coco_verify_test(
    name = "base_verify",
    package = ":base",
)

coco_generate(
    name = "base_cpp",
    include_prefix = "core",
    language = "cpp",
    package = ":base",
)

coco_cc_library(
    name = "base_cc",
    generated_package = ":base_cpp",
)

coco_package(
    name = "app",
    srcs = glob(["app/src/**/*.coco"]),
    package = "app/Coco.toml",
    deps = [":base"],
)

coco_verify_test(
    name = "app_verify",
    package = ":app",
)

coco_generate(
    name = "app_cpp",
    language = "cpp",
    package = ":app",
)

coco_cc_library(
    name = "app_cc",
    generated_package = ":app_cpp",
    deps = [":base_cc"],
)

cc_test(
    name = "unit",
    srcs = ["test/app_test.cc"],
    deps = [
        ":app_cc",
        ":base_cc",
        "@googletest//:gtest_main",
    ],
)
