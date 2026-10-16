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

load("@rules_cc//cc:defs.bzl", "cc_library", "cc_test")
load("@rules_coco//coco:cc.bzl", "coco_cc_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")

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
    # The generated files sit at the package root, as the source root `src` is stripped.
    includes = ["."],
    popili_version = "testing",
)

cc_test(
    name = "unit",
    srcs = ["test/light.cc"],
    deps = [":base_cc"],
)

# The README's plain cc_library over a coco_generate: the sources through srcs, the headers and
# their include root through deps. It builds base_cpp in the top-level configuration too, beside
# the copy beneath base_cc's pin, which the compiles above must not pick up even without a sandbox.
cc_library(
    name = "plain_cc",
    srcs = [":base_cpp"],
    deps = [
        ":base_cpp",
        "@rules_coco//coco:cc_runtime",
    ],
)

cc_test(
    name = "plain_unit",
    srcs = ["test/plain_light.cc"],
    deps = [":plain_cc"],
)
