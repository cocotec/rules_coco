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
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package", "with_popili_version")
load(":wrapped_cc_library.bzl", "wrapped_cc_library")

coco_package(
    name = "base",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

coco_generate(
    name = "base_cpp",
    language = "cpp",
    package = ":base",
)

# The root leaves --@rules_coco//:version unset, so the wrapper puts the generate in another
# configuration (and bin dir) than the library and test reading it.
with_popili_version(
    name = "stable_cpp",
    target = ":base_cpp",
    version = "stable",
)

coco_cc_library(
    name = "base_cc",
    generated_package = ":stable_cpp",
    # The generated files sit at the package root, as the source root `src` is stripped.
    includes = ["."],
)

cc_test(
    name = "unit",
    srcs = ["test/light.cc"],
    deps = [":base_cc"],
)

# A project's own wrapper of cc_library compiles the generate through library_rule. It builds
# base_cpp in this configuration too, beside the copy beneath stable_cpp, which the compiles above
# must not pick up even without a sandbox. Without `includes`, the headers are included by their
# path in the workspace.
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
