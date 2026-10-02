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

"""Analysis tests for popili_version pins on coco_package and coco_workspace."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_coco//coco:defs.bzl", "CocoWorkspaceInfo")

# buildifier: disable=bzl-visibility
load("@rules_coco//coco/private:coco.bzl", "CocoPackageInfo")

def _pin_failure_test_impl(ctx):
    env = analysistest.begin(ctx)
    for message in ctx.attr.expected_messages:
        asserts.expect_failure(env, message)
    return analysistest.end(env)

pin_failure_test = analysistest.make(
    _pin_failure_test_impl,
    expect_failure = True,
    attrs = {
        "expected_messages": attr.string_list(
            doc = "Substrings the analysis failure message must contain.",
        ),
    },
)

def _pin_result_test_impl(ctx):
    env = analysistest.begin(ctx)
    info = analysistest.target_under_test(env)[CocoPackageInfo]

    asserts.equals(env, ctx.attr.expected_version, info.popili_version)
    asserts.equals(env, ctx.attr.expected_pinned_by != "", info.popili_pinned)
    if ctx.attr.expected_pinned_by:
        asserts.equals(env, ctx.attr.expected_pinned_by, info.popili_pinned_by.name)
    asserts.equals(env, ctx.attr.expected_version, info.popili_toolchain.version)

    return analysistest.end(env)

pin_result_test = analysistest.make(
    _pin_result_test_impl,
    attrs = {
        "expected_pinned_by": attr.string(
            doc = "Name of the target whose pin decided the version, or '' for unpinned.",
        ),
        "expected_version": attr.string(mandatory = True),
    },
)

def _hand_built_workspace_impl(ctx):
    # Only `files`, the field CocoWorkspaceInfo had before popili_version existed.
    return [CocoWorkspaceInfo(files = depset(ctx.files.workspace))]

hand_built_workspace = rule(
    doc = "A workspace built outside rules_coco, setting only CocoWorkspaceInfo.files.",
    implementation = _hand_built_workspace_impl,
    attrs = {
        "workspace": attr.label(allow_single_file = True, mandatory = True),
    },
)
