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
load("@rules_coco//coco:defs.bzl", "coco_fmt_test", "coco_generate", "coco_package", "coco_verify_test")

coco_package(
    name = "base",
    srcs = glob(["base/source/**/*.coco"]),
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

coco_package(
    name = "app",
    srcs = glob(["app/sources/**/*.coco"]),
    package = "app/Coco.toml",
    deps = [":base"],
)

coco_generate(
    name = "app_cpp",
    cpp_header_file_extension = ".hpp",
    cpp_regenerate_packages = [":base"],
    language = "cpp",
    package = ":app",
)

coco_cc_library(
    name = "app_cc",
    generated_package = ":app_cpp",
)

cc_test(
    name = "cpp_test",
    srcs = ["app/test/cpp_test.cc"],
    deps = [
        ":app_cc",
        "@googletest//:gtest_main",
    ],
)

# Commented out pending Popili support for --include-prefix in C
# coco_generate(
#     name = "app_c",
#     c_header_file_extension = ".hh",
#     c_regenerate_packages = [":base"],
#     language = "c",
#     package = ":app",
# )
#
# coco_c_library(
#     name = "app_c_lib",
#     generated_package = ":app_c",
# )
#
# cc_test(
#     name = "c_test",
#     srcs = ["app/test/c_test.c"],
#     deps = [
#         ":app_c_lib",
#     ],
# )

coco_generate(
    name = "app_csharp",
    csharp_regenerate_packages = [":base"],
    language = "csharp",
    package = ":app",
)

cc_test(
    name = "csharp_test",
    srcs = ["app/test/csharp_validator.cc"],
    args = ["test/regenerate_packages/app/sources"],
    data = [":app_csharp"],
)

coco_verify_test(
    name = "app_verify",
    package = ":app",
)

coco_fmt_test(
    name = "app_fmt_test",
    package = ":app",
)
