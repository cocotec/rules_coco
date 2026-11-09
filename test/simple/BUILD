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
load(":license_execution_test.bzl", "local_acquire_path_test", "local_license_action_test", "local_license_test", "local_user_path_test", "remote_license_action_test", "remote_license_test")
load(":popili_rules.bzl", "popili_component_diagram", "popili_typecheck", "popili_typecheck_test")

# test/popili_pinning asserts on these targets rather than copying them.
package(default_visibility = ["//test/popili_pinning:__pkg__"])

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
    mocks = True,
    package = ":base",
    popili_version = "stable",
)

# The library macros pass their attrs on unchanged, so each may be a select(). These are the ones
# a macro used to inspect or wrap in a list; `unit` only compiles when they resolve as plain values.
coco_cc_library(
    name = "base_cc",
    generated_package = select({"//conditions:default": ":base_cpp"}),
    popili_version = "stable",
    # None keeps the default: all generated headers public.
    public_hdrs = select({"//conditions:default": None}),
)

coco_cc_test_library(
    name = "base_cc_tst",
    generated_package = ":base_cpp",
    gmock = select({"//conditions:default": "@googletest//:gtest"}),
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

# Under the local licence modes popili never runs remotely; the others leave that to the user.
local_license_test(
    name = "local_license_execution_test",
    no_remote_exec = True,
    target_under_test = ":base_verify",
)

remote_license_test(
    name = "remote_license_execution_test",
    no_remote_exec = False,
    target_under_test = ":base_verify",
)

# Execution platforms for the action tests, which put the one that isn't the host's first. Under the
# local licence modes popili still runs this machine's binary; the others follow the first platform.
platform(
    name = "linux_x86_64",
    constraint_values = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
)

platform(
    name = "osx_aarch64",
    constraint_values = [
        "@platforms//cpu:aarch64",
        "@platforms//os:osx",
    ],
)

local_license_action_test(
    name = "local_license_action_test",
    host = True,
    target_under_test = ":base_cpp",
)

remote_license_action_test(
    name = "remote_license_action_test",
    host = False,
    target_under_test = ":base_cpp",
)

# The local licence modes pass the licence by path, so its contents stay out of the action key.
local_user_path_test(
    name = "local_user_licence_path_test",
    target_under_test = ":base_cpp",
)

# Acquires a licence as its toolchain is fetched, so it needs COCOTEC_AUTH_TOKEN, as CI passes it
# (--repo_env); without one the fetch fails, and the test with it.
local_acquire_path_test(
    name = "local_acquire_licence_path_test",
    target_under_test = ":base_cpp",
)
