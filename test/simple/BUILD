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

load("@io_cocotec_rules_coco//coco:coco.bzl", "coco_cc_library", "coco_cc_test_library", "coco_package", "coco_package_generate")
load("@rules_cc//cc:defs.bzl", "cc_test")

coco_package(
    name = "base",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

coco_package_generate(
    name = "base_cpp",
    language = "cpp",
    mocks = True,
    package = ":base",
)

coco_cc_library(
    name = "base_cc",
    generated_package = ":base_cpp",
)

coco_cc_test_library(
    name = "base_cc_tst",
    generated_package = ":base_cpp",
    deps = [":base_cc"],
)

cc_test(
    name = "unit",
    srcs = ["test/base.cc"],
    deps = [":base_cc_tst"],
)
