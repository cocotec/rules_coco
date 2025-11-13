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
load("//coco/private:coco.bzl", "popili_version_alias")

package(default_visibility = ["//visibility:public"])

toolchain_type(name = "toolchain_type")

popili_version_alias(name = "current_popili_version")

# Export key public Starlark files
exports_files([
    "cc.bzl",
    "defs.bzl",
    "extensions.bzl",
    "repositories.bzl",
    "toolchain.bzl",
])

# Export all Starlark files for documentation generation and external consumption
filegroup(
    name = "bzl_srcs",
    srcs = glob(["*.bzl"]) + [
        "//coco/private:bzl_srcs",
    ],
)

# Starlark library targets for documentation generation
bzl_library(
    name = "defs",
    srcs = ["defs.bzl"],
    deps = [
        "//coco/private:coco_bzl",
        "//coco/private:licensing_bzl",
    ],
)

bzl_library(
    name = "cc",
    srcs = ["cc.bzl"],
    deps = [
        ":defs",
        "@rules_cc//cc:defs_bzl",
    ],
)

bzl_library(
    name = "repositories",
    srcs = ["repositories.bzl"],
    deps = ["//coco/private:repositories_bzl"],
)

# Unified public bzl_library for external rules to depend on
# This aggregates all public Starlark APIs
bzl_library(
    name = "bzl_lib",
    srcs = glob(["*.bzl"]),
    deps = [
        ":cc",
        ":defs",
        ":repositories",
        "//coco/private:bzl_lib",
    ],
)
