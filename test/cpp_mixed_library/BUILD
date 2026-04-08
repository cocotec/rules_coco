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
    name = "sensor",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

coco_generate(
    name = "sensor_cpp",
    language = "cpp",
    package = ":sensor",
)

# Mixed library: Coco-generated code + hand-written C++ code.
# Generated headers are public (via CcInfo), generated sources are compiled.
# Hand-written headers are also public.
coco_cc_library(
    name = "sensor_lib",
    srcs = ["handwritten/sensor_wrapper.cc"],
    hdrs = ["handwritten/sensor_wrapper.h"],
    generated_package = ":sensor_cpp",
)

# Downstream test that includes both generated and hand-written headers.
# This proves that generated headers are public via the library's CcInfo.
cc_test(
    name = "unit",
    srcs = ["test/sensor_test.cc"],
    deps = [
        ":sensor_lib",
        "@googletest//:gtest_main",
    ],
)
