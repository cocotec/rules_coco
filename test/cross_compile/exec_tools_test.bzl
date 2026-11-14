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

"""Analysis tests: a toolchain's popili is built for the execution platform that runs it, as any tool is.

A release's popili is a file, the same in every configuration, so only a binary built from source shows the
difference; the fake toolchain's popili is one (write_file). Built for the target platform, it can't run wherever the
target and execution platforms differ: an action cross-compiling, or a test running on the target's platform.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _assert_built_for_exec(env, files, what):
    popili = [f for f in files if f.basename == "popili"]
    asserts.equals(env, 1, len(popili), "popili among the %s" % what)
    for f in popili:
        asserts.true(env, "-exec" in f.root.path, "popili among the %s is built for the target: %s" % (what, f.path))

def _typecheck_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "CocoTypecheck"]
    asserts.equals(env, 1, len(actions), "CocoTypecheck actions")
    for action in actions:
        _assert_built_for_exec(env, action.inputs.to_list(), "typecheck action's inputs")
    return analysistest.end(env)

def _test_runfiles_test_impl(ctx):
    env = analysistest.begin(ctx)
    runfiles = analysistest.target_under_test(env)[DefaultInfo].default_runfiles.files.to_list()
    _assert_built_for_exec(env, runfiles, "test's runfiles")
    return analysistest.end(env)

_SETTINGS = {
    "//command_line_option:extra_toolchains": [str(Label("//test/cross_compile:fake_posix_toolchain"))],
}

exec_typecheck_test = analysistest.make(_typecheck_test_impl, config_settings = _SETTINGS)
exec_test_runfiles_test = analysistest.make(_test_runfiles_test_impl, config_settings = _SETTINGS)

def exec_tools_tests(name, package, test):
    """Declares a test of each place a toolchain's popili runs, plus a test_suite.

    Args:
        name: Prefix for the tests and the name of the test_suite.
        package: A coco_package with `typecheck = True`.
        test: A Coco test of `package`, such as a coco_verify_test.
    """
    exec_typecheck_test(name = name + "_typecheck", size = "small", target_under_test = package)
    exec_test_runfiles_test(name = name + "_test_runfiles", size = "small", target_under_test = test)
    native.test_suite(name = name, tests = [name + "_typecheck", name + "_test_runfiles"])
