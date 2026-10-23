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

# A package's includePrefix need not be in its own Coco.toml: inherits gets "ws" from its workspace, and receiver
# gets "exported" from exporter, which sets exportConfig. app's generated code includes them by those prefixes, so
# each coco_generate mirrors the effective value in include_prefix, and no library needs `includes`.

load("@rules_cc//cc:defs.bzl", "cc_test")
load("@rules_coco//coco:cc.bzl", "coco_cc_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package", "coco_verify_test", "coco_workspace")

coco_workspace(
    name = "workspace",
    workspace = "ws/Coco.toml",
)

coco_package(
    name = "inherits",
    srcs = glob(["ws/inherits/src/**/*.coco"]),
    package = "ws/inherits/Coco.toml",
    workspace = ":workspace",
)

coco_verify_test(
    name = "inherits_verify",
    package = ":inherits",
)

coco_generate(
    name = "inherits_cpp",
    include_prefix = "ws",
    language = "cpp",
    package = ":inherits",
)

coco_cc_library(
    name = "inherits_cc",
    generated_package = ":inherits_cpp",
)

coco_package(
    name = "exporter",
    srcs = glob(["exporter/src/**/*.coco"]),
    package = "exporter/Coco.toml",
)

coco_verify_test(
    name = "exporter_verify",
    package = ":exporter",
)

coco_generate(
    name = "exporter_cpp",
    include_prefix = "exported",
    language = "cpp",
    package = ":exporter",
)

coco_cc_library(
    name = "exporter_cc",
    generated_package = ":exporter_cpp",
)

coco_package(
    name = "receiver",
    srcs = glob(["receiver/src/**/*.coco"]),
    package = "receiver/Coco.toml",
    deps = [":exporter"],
)

coco_verify_test(
    name = "receiver_verify",
    package = ":receiver",
)

coco_generate(
    name = "receiver_cpp",
    include_prefix = "exported",
    language = "cpp",
    package = ":receiver",
)

coco_cc_library(
    name = "receiver_cc",
    generated_package = ":receiver_cpp",
    deps = [":exporter_cc"],
)

coco_package(
    name = "app",
    srcs = glob(["app/src/**/*.coco"]),
    package = "app/Coco.toml",
    deps = [
        ":inherits",
        ":receiver",
    ],
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
    deps = [
        ":inherits_cc",
        ":receiver_cc",
    ],
)

cc_test(
    name = "unit",
    srcs = ["test/app_test.cc"],
    deps = [
        ":app_cc",
        "@googletest//:gtest_main",
    ],
)
