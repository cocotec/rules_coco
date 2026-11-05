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

"""Analysis tests for the local licence modes.

A test running popili is kept off remote executors; actions get the same requirements, but
Starlark cannot read an action's execution info, so they are checked for the popili they run
instead: this machine's, even when another platform comes first in --extra_execution_platforms,
as a remote one would. Under local_user, the licence is passed by absolute path rather than as an
input.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load("@rules_coco//coco/private:platforms.bzl", "toolchain_platform_of")  # buildifier: disable=bzl-visibility

def _expected(ctx):
    return {"no-remote-exec": "1"} if ctx.attr.no_remote_exec else {}

def _impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    requirements = target[testing.ExecutionInfo].requirements if testing.ExecutionInfo in target else {}
    asserts.equals(env, _expected(ctx), requirements)
    return analysistest.end(env)

def _settings(license_source):
    return {str(Label("@rules_coco//:license_source")): license_source}

_ATTRS = {"no_remote_exec": attr.bool(mandatory = True)}

# rule() must be called at top level and bound to a global, hence one per mode.
local_license_test = analysistest.make(_impl, attrs = _ATTRS, config_settings = _settings("local_user"))
remote_license_test = analysistest.make(_impl, attrs = _ATTRS, config_settings = _settings("action_environment"))

# The `<os>_<cpu>` part of a popili toolchain repository's name; None when popili is not published
# for the host, which fails the host test.
_HOST_PLATFORM = toolchain_platform_of(HOST_CONSTRAINTS)
_HOST = "%s_%s" % _HOST_PLATFORM if _HOST_PLATFORM else None
_FOREIGN = "osx_aarch64" if _HOST == "linux_x86_64" else "linux_x86_64"

def _action_impl(ctx):
    env = analysistest.begin(ctx)
    expected = _HOST if ctx.attr.host else _FOREIGN
    popilis = [a.argv[0] for a in analysistest.target_actions(env) if a.argv and "io_cocotec_coco_" in a.argv[0]]
    asserts.true(env, popilis, "no action runs popili")
    for popili in popilis:
        asserts.true(env, "_%s__" % expected in popili, "expected the %s popili, got %s" % (expected, popili))
    return analysistest.end(env)

def _action_settings(license_source):
    return dict(_settings(license_source).items() + {
        "//command_line_option:extra_execution_platforms": [str(Label(":" + _FOREIGN))],
    }.items())

_ACTION_ATTRS = {"host": attr.bool(mandatory = True)}

local_license_action_test = analysistest.make(_action_impl, attrs = _ACTION_ATTRS, config_settings = _action_settings("local_user"))
remote_license_action_test = analysistest.make(_action_impl, attrs = _ACTION_ATTRS, config_settings = _action_settings("action_environment"))

def _local_path_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "CocoGenerate"]
    asserts.equals(env, 1, len(actions), "CocoGenerate actions")
    for action in actions:
        licences = [f.path for f in action.inputs.to_list() if f.basename.startswith("licenses_")]
        asserts.equals(env, [], licences, "licence files among the inputs")

        # Absent on a machine without a licence, such as CI, which uses local_acquire.
        argv = action.argv
        if "--override-licenses" in argv:
            path = argv[argv.index("--override-licenses") + 1]
            asserts.true(env, paths.is_absolute(path), "--override-licenses %s is not absolute" % path)
    return analysistest.end(env)

local_user_path_test = analysistest.make(_local_path_test_impl, config_settings = _settings("local_user"))
