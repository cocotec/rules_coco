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
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package", "coco_verify_test", "coco_workspace")
load("@rules_coco//coco/private:version_resolution.bzl", "resolve_version_alias")  # buildifier: disable=bzl-visibility
load("//test/popili_pinning:pinning_test.bzl", "expect_message_test")
load("//test/version_registry:root_versions.bzl", "OLDER_VERSION")

# Nested workspaces (outer -> inner -> pkg): the outer's [language] standard and
# the inner's [generator] settings both flow down to pkg. pkg uses a .Coco1_2
# feature, so it builds only if the outer's standard reaches it through inner.

# The outer workspace claims the default popili version for every member: inner and pkg inherit
# the claim, and pkg's consumers check against it.
coco_workspace(
    name = "outer",
    popili_versions = ["stable"],
    workspace = "Coco.toml",
)

coco_workspace(
    name = "inner",
    parent = ":outer",
    workspace = "inner/Coco.toml",
)

coco_package(
    name = "pkg",
    srcs = glob(["inner/pkg/src/**/*.coco"]),
    package = "inner/pkg/Coco.toml",
    workspace = ":inner",
)

coco_verify_test(
    name = "pkg_verify",
    package = ":pkg",
)

coco_generate(
    name = "pkg_cpp",
    language = "cpp",
    mocks = True,
    package = ":pkg",
)

coco_cc_library(
    name = "pkg_cc",
    generated_package = ":pkg_cpp",
)

cc_test(
    name = "unit",
    srcs = ["pkg_test.cc"],
    deps = [
        ":pkg_cc",
        "@googletest//:gtest_main",
    ],
)

# Reached only by the analysis tests: a nested workspace and a member each listing fewer versions
# than the workspace they belong to, and a member inheriting a list without the default, whose
# unpinned consumer fails the check against it. The lists name a registered version other than the
# default.
coco_workspace(
    name = "narrower",
    parent = ":outer",
    popili_versions = [OLDER_VERSION],
    tags = ["manual"],
    workspace = "inner/Coco.toml",
)

coco_package(
    name = "narrower_pkg",
    srcs = glob(["inner/pkg/src/**/*.coco"]),
    package = "inner/pkg/Coco.toml",
    popili_versions = [OLDER_VERSION],
    tags = ["manual"],
    workspace = ":inner",
)

coco_workspace(
    name = "older_only",
    popili_versions = [OLDER_VERSION],
    tags = ["manual"],
    workspace = "Coco.toml",
)

coco_package(
    name = "inherits_older",
    srcs = glob(["inner/pkg/src/**/*.coco"]),
    package = "inner/pkg/Coco.toml",
    tags = ["manual"],
    workspace = ":older_only",
)

STABLE = resolve_version_alias("stable")

expect_message_test(
    name = "narrower_workspace_test",
    size = "small",
    expected = [
        ":narrower's popili_versions (%s) leave out %s, which its parent " % (OLDER_VERSION, STABLE),
        ":outer claims for every member package: %s. A member may support more versions than its workspace, never fewer" % STABLE,
    ],
    target_under_test = ":narrower",
)

expect_message_test(
    name = "narrower_package_test",
    size = "small",
    expected = [
        ":narrower_pkg's popili_versions (%s) leave out %s, which its workspace " % (OLDER_VERSION, STABLE),
        ":inner claims for every member package: %s." % STABLE,
    ],
    target_under_test = ":narrower_pkg",
)

expect_message_test(
    name = "inherited_versions_checked_test",
    size = "small",
    expected = [
        ":inherits_older gets popili %s (the default), which the popili_versions it inherits from its workspace " % STABLE,
        ":older_only do not list: %s. Build it beneath a target pinned to one of those" % OLDER_VERSION,
    ],
    target_under_test = ":inherits_older",
)
