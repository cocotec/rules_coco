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
load("@rules_shell//shell:sh_test.bzl", "sh_test")

coco_package(
    name = "base",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
    typecheck = True,
)

coco_verify_test(
    name = "base_verify",
    package = ":base",
)

# This creates two targets:
# - base_fmt_test: Test that checks formatting (bazel test //test/simple:base_fmt_test)
# - base_fmt: Binary that formats the code (bazel run //test/simple:base_fmt)
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

sh_test(
    name = "check_make_variables",
    srcs = ["typecheck.sh"],
    args = ["$(POPILI) $(POPILI_STARTUP_ARGS)"],
    data = [
        ":base",
        "@rules_coco//coco:current_popili_version",
    ],
    toolchains = ["@rules_coco//coco:current_popili_version"],
)
