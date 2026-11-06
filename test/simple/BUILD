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
load("@rules_coco//coco:cc.bzl", "coco_cc_library", "coco_cc_test_library")
load("@rules_coco//coco:defs.bzl", "coco_fmt_test", "coco_generate", "coco_package", "coco_verify_test")
load(":popili_rules.bzl", "popili_component_diagram", "popili_typecheck", "popili_typecheck_test")

# test/popili_pinning asserts on these targets rather than copying them.
package(default_visibility = ["//test/popili_pinning:__pkg__"])

coco_package(
    name = "base",
    srcs = glob(["src/**/*.coco"]),
    cpp_mocks = "GMock",
    package = "Coco.toml",
    typecheck = True,
)

coco_verify_test(
    name = "base_verify",
    package = ":base",
)

# This creates two targets:
# - base_fmt_test: Test that checks formatting (bazel test //test/simple:base_fmt_test)
# - base_fmt_test.format: Binary that formats the code (bazel run //test/simple:base_fmt_test.format)
coco_fmt_test(
    name = "base_fmt_test",
    package = ":base",
)

# Pinned to the alias `stable`, which the root registers first, so without a flag the pins change
# nothing; the libraries are pinned like the generator they build from, so the runtime they link
# is the generator's version.
coco_generate(
    name = "base_cpp",
    language = "cpp",
    package = ":base",
    popili_version = "stable",
)

coco_cc_library(
    name = "base_cc",
    generated_package = ":base_cpp",
    popili_version = "stable",
)

coco_cc_test_library(
    name = "base_cc_tst",
    generated_package = ":base_cpp",
    popili_version = "stable",
    deps = [":base_cc"],
)

cc_test(
    name = "unit",
    srcs = ["test/base.cc"],
    deps = [":base_cc_tst"],
)

# Rules defined with popili_rule. The test is unpinned, so that it follows the flag like the
# verify test; the action and the binary are pinned like the generator.
popili_typecheck_test(
    name = "base_typecheck",
    package = ":base",
)

popili_component_diagram(
    name = "base_component_diagram",
    component = "Comp",
    package = ":base",
    popili_version = "stable",
)

popili_typecheck(
    name = "base_typecheck_binary",
    package = ":base",
    popili_version = "stable",
)
