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
load("@rules_cc//cc:defs.bzl", "cc_toolchain")
load("@rules_coco//coco:cc.bzl", "coco_cc_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package", "coco_state_diagram", "coco_verify_test")
load("@rules_coco//coco/private:licensing.bzl", "fetch_license")  # buildifier: disable=bzl-visibility
load("@rules_coco//coco/private:version_resolution.bzl", "resolve_version_alias")  # buildifier: disable=bzl-visibility
load(":bare_coco_rule.bzl", "bare_coco_rule")
load(":diagnostics_test.bzl", "popili_diagnostics_tests", "unknown_version_test")
load(":stub_cc_toolchain.bzl", "stub_cc_toolchain_config")

coco_package(
    name = "base",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

coco_verify_test(
    name = "base_verify",
    package = ":base",
)

coco_generate(
    name = "base_cpp",
    language = "cpp",
    package = ":base",
)

coco_cc_library(
    name = "base_cc",
    generated_package = ":base_cpp",
    tags = ["manual"],
)

coco_state_diagram(
    name = "base_states",
    package = ":base",
)

# An execution platform no popili is published for; e2e/multi_version uses it too.
platform(
    name = "riscv64",
    constraint_values = [
        "@platforms//cpu:riscv64",
        "@platforms//os:linux",
    ],
)

# A C++ toolchain for any riscv64 platform, for analysing test rules built for one; passed with
# --extra_toolchains, also by e2e/local_toolchain.
stub_cc_toolchain_config(name = "stub_cc_toolchain_config")

filegroup(name = "empty")

cc_toolchain(
    name = "stub_cc_toolchain",
    all_files = ":empty",
    compiler_files = ":empty",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    toolchain_config = ":stub_cc_toolchain_config",
)

toolchain(
    name = "riscv64_stub_cc_toolchain",
    target_compatible_with = ["@platforms//cpu:riscv64"],
    toolchain = ":stub_cc_toolchain",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
    visibility = ["//visibility:public"],
)

# What @io_cocotec_licensing_fetch//:licenses is when COCOTEC_AUTH_TOKEN is set; only analysed.
write_file(
    name = "fake_auth_token",
    out = "fake_auth_token.secret",
    content = ["not-a-token"],
)

fetch_license(
    name = "fetch_license",
    auth_token = ":fake_auth_token",
    product = "popili",
    tags = ["manual"],
)

popili_diagnostics_tests(
    name = "diagnostics",
    fetch_license = ":fetch_license",
    registered_versions = [
        resolve_version_alias("stable"),
        resolve_version_alias("testing"),
    ],
    targets = {
        # The library's ._gen, not the cc_library, which needs a C++ toolchain for riscv64 too.
        "cc_library": ":base_cc._gen",
        "cc_runtime": "@rules_coco//coco:cc_runtime",
        "diagram": ":base_states",
        "generate": ":base_cpp",
        "package": ":base",
        "verify_test": ":base_verify",
    },
    test_targets = ["verify_test"],
)

# A custom rule without TOOLCHAIN_ATTRIBUTES gets a simpler message rather than a crash.
bare_coco_rule(
    name = "bare",
    tags = ["manual"],
)

unknown_version_test(
    name = "bare_unknown_version",
    size = "small",
    expected = ["needs a Coco toolchain, but no toolchain of type @rules_coco//coco:toolchain_type resolved."],
    target_under_test = ":bare",
)
