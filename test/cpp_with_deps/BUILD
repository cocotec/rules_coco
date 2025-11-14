# Copyright 2019 Cocotec Limited
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
load("@rules_coco//coco:defs.bzl", "coco_fmt_test", "coco_generate", "coco_package", "coco_verify_test")

# Base package
coco_package(
    name = "base",
    srcs = glob(["base/src/**/*.coco"]),
    package = "base/Coco.toml",
)

coco_verify_test(
    name = "base_verify",
    package = ":base",
)

coco_fmt_test(
    name = "base_fmt_test",
    package = ":base",
)

coco_generate(
    name = "base_cpp",
    language = "cpp",
    mocks = True,
    package = ":base",
)

coco_cc_library(
    name = "base_cc",
    generated_package = ":base_cpp",
    includes = ["base/src"],
)

# Middle package (depends on base)
coco_package(
    name = "middle",
    srcs = glob(["middle/src/**/*.coco"]),
    package = "middle/Coco.toml",
    deps = [":base"],
)

coco_verify_test(
    name = "middle_verify",
    package = ":middle",
)

coco_fmt_test(
    name = "middle_fmt_test",
    package = ":middle",
)

coco_generate(
    name = "middle_cpp",
    language = "cpp",
    package = ":middle",
)

coco_cc_library(
    name = "middle_cc",
    generated_package = ":middle_cpp",
    includes = ["middle/src"],
    deps = [":base_cc"],
)

# App package (depends on middle, transitively on base)
coco_package(
    name = "app",
    srcs = glob(["app/src/**/*.coco"]),
    package = "app/Coco.toml",
    deps = [":middle"],
)

coco_verify_test(
    name = "app_verify",
    package = ":app",
)

coco_fmt_test(
    name = "app_fmt_test",
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
    deps = [":middle_cc"],
)

cc_test(
    name = "unit",
    srcs = ["app/test/app_test.cc"],
    deps = [
        ":app_cc",
        ":base_cc",
        ":middle_cc",
        "@googletest//:gtest_main",
    ],
)
