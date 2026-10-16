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
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package", "coco_verify_test")
load("@rules_coco//coco/private:licensing.bzl", "fetch_license")  # buildifier: disable=bzl-visibility
load(":diagnostics_test.bzl", "popili_diagnostics_tests")

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

# An execution platform no popili is published for.
platform(
    name = "riscv64",
    constraint_values = [
        "@platforms//cpu:riscv64",
        "@platforms//os:linux",
    ],
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
    cc_runtime = "@rules_coco//coco:cc_runtime",
    fetch_license = ":fetch_license",
    generate = ":base_cpp",
    package = ":base",
    verify_test = ":base_verify",
)
