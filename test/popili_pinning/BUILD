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

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_cc//cc:defs.bzl", "cc_test")
load("@rules_coco//coco:cc.bzl", "coco_cc_library", "coco_cc_test_library")
load("@rules_coco//coco:defs.bzl", "coco_fmt_test", "coco_generate", "coco_package", "coco_state_diagram", "coco_verify_test")
load(":pinning_test.bzl", "popili_pinning_tests")

# The root registers only `stable`, so every pin here is the alias: the transition has to resolve
# it to the registered version for anything to build.
coco_package(
    name = "base",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

coco_generate(
    name = "pinned_cpp",
    language = "cpp",
    mocks = True,
    package = ":base",
    popili_version = "stable",
)

coco_cc_library(
    name = "pinned_cc",
    generated_package = ":pinned_cpp",
)

coco_cc_test_library(
    name = "pinned_cc_tst",
    generated_package = ":pinned_cpp",
    deps = [":pinned_cc"],
)

cc_test(
    name = "unit",
    srcs = ["test/base.cc"],
    deps = [":pinned_cc_tst"],
)

coco_verify_test(
    name = "pinned_verify",
    package = ":base",
    popili_version = "stable",
)

coco_fmt_test(
    name = "pinned_fmt",
    package = ":base",
    popili_version = "stable",
)

coco_state_diagram(
    name = "pinned_states",
    package = ":base",
    popili_version = "stable",
    targets = ["Runnable.M"],
)

# Unpinned, for the assertions that its configuration is untouched and that it follows an alias in
# --@rules_coco//:version. Over its own package: under --@rules_coco//:version=stable (or
# force_version) it shares a configuration with :pinned_cpp, and two coco_generates of one package
# in one configuration would write the same files.
coco_package(
    name = "unpinned_base",
    srcs = glob(["unpinned/src/*.coco"]),
    package = "unpinned/Coco.toml",
)

coco_generate(
    name = "unpinned_cpp",
    language = "cpp",
    package = ":unpinned_base",
)

# Unpinned, as the reference configuration under --@rules_coco//:force_version.
coco_verify_test(
    name = "unpinned_verify",
    package = ":base",
)

# No transition of any kind: the bin dir a target without a pin must stay in.
write_file(
    name = "untransitioned",
    out = "untransitioned.txt",
    content = [""],
)

# Pinned to a version nobody registered; reached only by the analysis tests.
coco_generate(
    name = "unregistered_cpp",
    language = "cpp",
    package = ":base",
    popili_version = "1.99.0",
    tags = ["manual"],
)

# A typechecked package: its typecheck script shows the popili the package itself resolved.
coco_package(
    name = "typechecked",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
    typecheck = True,
)

popili_pinning_tests(
    name = "pinning",
    aliased = {
        "cc_runtime": "@rules_coco//coco:cc_runtime",
        "generate": ":unpinned_cpp",
        "package": ":typechecked",
        "verify_test": ":unpinned_verify",
    },
    current_popili_version = "@rules_coco//coco:current_popili_version",
    pinned = {
        "fmt_binary": ":pinned_fmt.format",
        "fmt_test": ":pinned_fmt",
        "generate": ":pinned_cpp",
        "state_diagram": ":pinned_states",
        "verify_test": ":pinned_verify",
    },
    unpinned_verify = ":unpinned_verify",
    unregistered = ":unregistered_cpp",
    untransitioned = ":untransitioned",
)
