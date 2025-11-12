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

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//coco:__pkg__"])

# Export all Starlark files for documentation generation and external consumption
filegroup(
    name = "bzl_srcs",
    srcs = glob(["*.bzl"]),
)

# Wrapper bzl_library for external dependencies that don't provide bzl_library targets
# This uses the bzl_srcs filegroup pattern from rules_rust
bzl_library(
    name = "bazel_tools_bzl_lib",
    srcs = ["@bazel_tools//tools:bzl_srcs"],
)

# Starlark library targets for internal implementation files
bzl_library(
    name = "coco_bzl",
    srcs = ["coco.bzl"],
    deps = [
        ":version_aliases_bzl",
        "@bazel_skylib//lib:paths",
        "@bazel_skylib//rules:common_settings",
        "@rules_cc//cc:defs_bzl",
    ],
)

bzl_library(
    name = "repositories_bzl",
    srcs = ["repositories.bzl"],
    deps = [
        ":bazel_tools_bzl_lib",
        ":common_repositories_bzl",
        ":known_shas_bzl",
    ],
)

bzl_library(
    name = "common_repositories_bzl",
    srcs = ["common_repositories.bzl"],
    deps = [":known_shas_bzl"],
)

bzl_library(
    name = "known_shas_bzl",
    srcs = ["known_shas.bzl"],
)

bzl_library(
    name = "version_aliases_bzl",
    srcs = ["version_aliases.bzl"],
)

bzl_library(
    name = "licensing_bzl",
    srcs = ["licensing.bzl"],
)

# Unified bzl_library aggregating all private implementation
# Visibility restricted to //coco package only
bzl_library(
    name = "bzl_lib",
    srcs = glob(["*.bzl"]),
    deps = [
        ":bazel_tools_bzl_lib",
        ":coco_bzl",
        ":common_repositories_bzl",
        ":known_shas_bzl",
        ":licensing_bzl",
        ":repositories_bzl",
        ":version_aliases_bzl",
    ],
)
