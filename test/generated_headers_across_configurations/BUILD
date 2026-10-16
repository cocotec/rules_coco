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
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")
load(":wrapped_cc_library.bzl", "wrapped_cc_library")

coco_package(
    name = "base",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

# The library is pinned to "testing", which the root registers next to the default "stable".
# The pin transitions the unpinned generate beneath it, so the generate lands in another
# configuration (and bin dir) than the library's cc_library and the test reading its headers,
# which stay in the top-level configuration.
coco_generate(
    name = "base_cpp",
    language = "cpp",
    package = ":base",
)

coco_cc_library(
    name = "base_cc",
    generated_package = ":base_cpp",
    popili_version = "testing",
)

cc_test(
    name = "unit",
    srcs = ["test/light.cc"],
    deps = [":base_cc"],
)

# A project's own wrapper of cc_library compiles the generate through library_rule. It builds
# base_cpp in the top-level configuration too, beside the copy beneath base_cc's pin, which the
# compiles above must not pick up even without a sandbox.
coco_cc_library(
    name = "wrapped_cc",
    generated_package = ":base_cpp",
    library_rule = wrapped_cc_library,
)

cc_test(
    name = "wrapped_unit",
    srcs = ["test/wrapped_light.cc"],
    deps = [":wrapped_cc"],
)
