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

# Two independent Coco packages
coco_package(
    name = "sensors",
    srcs = glob(["sensors/src/**/*.coco"]),
    package = "sensors/Coco.toml",
)

coco_package(
    name = "actuators",
    srcs = glob(["actuators/src/**/*.coco"]),
    package = "actuators/Coco.toml",
)

coco_generate(
    name = "sensors_cpp",
    language = "cpp",
    package = ":sensors",
)

coco_generate(
    name = "actuators_cpp",
    language = "cpp",
    package = ":actuators",
)

# Merge both packages into a single library using generated_packages.
# Downstream targets get headers from both packages via one dependency.
coco_cc_library(
    name = "hardware_lib",
    generated_packages = [
        ":sensors_cpp",
        ":actuators_cpp",
    ],
)

# Downstream test includes headers from both packages via the merged library.
cc_test(
    name = "unit",
    srcs = ["test/merged_test.cc"],
    deps = [
        ":hardware_lib",
        "@googletest//:gtest_main",
    ],
)
