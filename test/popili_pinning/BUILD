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

# Analysis tests for popili_version pins. The root module registers only "stable", so the
# cases that need two registered versions live in e2e/multi_version. Nothing here runs popili.
#
# Targets expected to fail analysis are tagged manual, so that `bazel build //...` skips them;
# the tests below still analyse them.

load("@rules_coco//coco:defs.bzl", "coco_package", "coco_workspace")

# buildifier: disable=bzl-visibility
load("@rules_coco//coco/private:version_aliases.bzl", "VERSION_ALIASES")
load(":pinning_tests.bzl", "hand_built_workspace", "pin_failure_test", "pin_result_test")

STABLE = VERSION_ALIASES["stable"]

# An alias pin resolves to the concrete version, and its toolchain is the one resolved.
coco_package(
    name = "pinned_to_alias",
    srcs = glob(["pkg/src/**/*.coco"]),
    package = "pkg/Coco.toml",
    popili_version = "stable",
)

pin_result_test(
    name = "pinned_to_alias_test",
    expected_pinned_by = "pinned_to_alias",
    expected_version = STABLE,
    target_under_test = ":pinned_to_alias",
)

# An unpinned package resolves the default version and reports itself unpinned.
coco_package(
    name = "unpinned",
    srcs = glob(["pkg/src/**/*.coco"]),
    package = "pkg/Coco.toml",
)

pin_result_test(
    name = "unpinned_test",
    expected_version = STABLE,
    target_under_test = ":unpinned",
)

# A workspace pin is inherited by unpinned members, and through nested workspaces.
coco_workspace(
    name = "ws_pinned",
    popili_version = STABLE,
    workspace = "Coco.toml",
)

coco_workspace(
    name = "inner_unpinned",
    parent = ":ws_pinned",
    workspace = "inner/Coco.toml",
)

coco_package(
    name = "inherits_from_workspace",
    srcs = glob(["pkg/src/**/*.coco"]),
    package = "pkg/Coco.toml",
    workspace = ":ws_pinned",
)

pin_result_test(
    name = "inherits_from_workspace_test",
    expected_pinned_by = "ws_pinned",
    expected_version = STABLE,
    target_under_test = ":inherits_from_workspace",
)

coco_package(
    name = "inherits_from_parent_workspace",
    srcs = glob(["inner/nested_pkg/src/**/*.coco"]),
    package = "inner/nested_pkg/Coco.toml",
    workspace = ":inner_unpinned",
)

pin_result_test(
    name = "inherits_from_parent_workspace_test",
    expected_pinned_by = "ws_pinned",
    expected_version = STABLE,
    target_under_test = ":inherits_from_parent_workspace",
)

# A package agreeing with its workspace is fine, whether spelled as an alias or not.
coco_package(
    name = "agrees_with_workspace",
    srcs = glob(["pkg/src/**/*.coco"]),
    package = "pkg/Coco.toml",
    popili_version = "stable",
    workspace = ":ws_pinned",
)

pin_result_test(
    name = "agrees_with_workspace_test",
    expected_pinned_by = "agrees_with_workspace",
    expected_version = STABLE,
    target_under_test = ":agrees_with_workspace",
)

# A package pinning a different version from its workspace is rejected.
coco_package(
    name = "disagrees_with_workspace",
    srcs = glob(["pkg/src/**/*.coco"]),
    package = "pkg/Coco.toml",
    popili_version = "1.5.0",
    tags = ["manual"],
    workspace = ":ws_pinned",
)

pin_failure_test(
    name = "disagrees_with_workspace_test",
    expected_messages = [
        "//test/popili_pinning:disagrees_with_workspace pins popili_version \"1.5.0\"",
        "its workspace //test/popili_pinning:ws_pinned pins \"%s\"" % STABLE,
    ],
    target_under_test = ":disagrees_with_workspace",
)

# So is a nested workspace pinning a different version from its parent.
coco_workspace(
    name = "inner_disagrees",
    parent = ":ws_pinned",
    popili_version = "1.5.0",
    tags = ["manual"],
    workspace = "inner/Coco.toml",
)

pin_failure_test(
    name = "inner_disagrees_test",
    expected_messages = [
        "//test/popili_pinning:inner_disagrees pins popili_version \"1.5.0\"",
        "its parent workspace //test/popili_pinning:ws_pinned pins \"%s\"" % STABLE,
    ],
    target_under_test = ":inner_disagrees",
)

# A pin naming a version that isn't registered fails with the registered versions listed.
coco_package(
    name = "unregistered",
    srcs = glob(["pkg/src/**/*.coco"]),
    package = "pkg/Coco.toml",
    popili_version = "9.9.9",
    tags = ["manual"],
)

pin_failure_test(
    name = "unregistered_test",
    expected_messages = [
        "//test/popili_pinning:unregistered pins popili_version \"9.9.9\", which is not registered",
        "Registered versions: \"%s\" (default)" % STABLE,
    ],
    target_under_test = ":unregistered",
)

coco_workspace(
    name = "ws_unregistered",
    popili_version = "9.9.9",
    tags = ["manual"],
    workspace = "Coco.toml",
)

pin_failure_test(
    name = "ws_unregistered_test",
    expected_messages = [
        "//test/popili_pinning:ws_unregistered pins popili_version \"9.9.9\", which is not registered",
    ],
    target_under_test = ":ws_unregistered",
)

# CocoWorkspaceInfo is public: a workspace provided by a rule outside rules_coco, which sets only
# `files`, counts as unpinned rather than failing analysis.
hand_built_workspace(
    name = "hand_built_ws",
    workspace = "Coco.toml",
)

coco_package(
    name = "in_hand_built_workspace",
    srcs = glob(["pkg/src/**/*.coco"]),
    package = "pkg/Coco.toml",
    workspace = ":hand_built_ws",
)

pin_result_test(
    name = "in_hand_built_workspace_test",
    expected_version = STABLE,
    target_under_test = ":in_hand_built_workspace",
)

coco_package(
    name = "pinned_in_hand_built_workspace",
    srcs = glob(["pkg/src/**/*.coco"]),
    package = "pkg/Coco.toml",
    popili_version = "stable",
    workspace = ":hand_built_ws",
)

pin_result_test(
    name = "pinned_in_hand_built_workspace_test",
    expected_pinned_by = "pinned_in_hand_built_workspace",
    expected_version = STABLE,
    target_under_test = ":pinned_in_hand_built_workspace",
)

coco_workspace(
    name = "under_hand_built_parent",
    parent = ":hand_built_ws",
    workspace = "inner/Coco.toml",
)

coco_package(
    name = "under_hand_built_parent_pkg",
    srcs = glob(["inner/nested_pkg/src/**/*.coco"]),
    package = "inner/nested_pkg/Coco.toml",
    workspace = ":under_hand_built_parent",
)

pin_result_test(
    name = "under_hand_built_parent_test",
    expected_version = STABLE,
    target_under_test = ":under_hand_built_parent_pkg",
)
