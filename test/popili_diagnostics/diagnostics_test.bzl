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

"""Analysis tests: a build without a matching Coco toolchain fails with rules_coco's own message.

The root registers `stable` and no local distribution, so three of the four cases can be provoked
here: a version nobody registered, `local` without a local toolchain, and the registered default
with only an execution platform popili is not published for (the host platform is replaced too,
because Bazel always offers the host as an execution platform otherwise).
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_coco//coco/private:version_resolution.bzl", "resolve_version_alias")  # buildifier: disable=bzl-visibility

_VERSION_FLAG = str(Label("@rules_coco//:version"))
_RISCV64 = str(Label("//test/popili_diagnostics:riscv64"))

def _expect_message_impl(ctx):
    env = analysistest.begin(ctx)
    for expected in ctx.attr.expected:
        asserts.expect_failure(env, expected)
    return analysistest.end(env)

_ATTRS = {"expected": attr.string_list(mandatory = True)}

unknown_version_test = analysistest.make(
    _expect_message_impl,
    attrs = _ATTRS,
    config_settings = {_VERSION_FLAG: "1.99.0"},
    expect_failure = True,
)

local_without_local_test = analysistest.make(
    _expect_message_impl,
    attrs = _ATTRS,
    config_settings = {_VERSION_FLAG: "local"},
    expect_failure = True,
)

no_execution_platform_test = analysistest.make(
    _expect_message_impl,
    attrs = _ATTRS,
    config_settings = {
        "//command_line_option:extra_execution_platforms": [_RISCV64],
        "//command_line_option:host_platform": _RISCV64,
    },
    expect_failure = True,
)

def _no_files_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.equals(env, [], analysistest.target_under_test(env)[DefaultInfo].files.to_list(), "files of a licence fetch without a toolchain")
    return analysistest.end(env)

fetch_license_without_toolchain_test = analysistest.make(
    _no_files_impl,
    config_settings = {_VERSION_FLAG: "1.99.0"},
)

def popili_diagnostics_tests(name, package, generate, verify_test, cc_runtime, fetch_license):
    """Declares the failure-message tests for every kind of popili consumer, plus a test_suite.

    Args:
        name: Prefix for the tests and the name of the test_suite.
        package: A coco_package.
        generate: A coco_generate of that package.
        verify_test: A coco_verify_test of that package (its popili resolves on the `test` exec group).
        cc_runtime: `@rules_coco//coco:cc_runtime`.
        fetch_license: A `fetch_license` target.
    """
    stable = resolve_version_alias("stable")
    registered = "Registered popili versions: %s (the default)." % stable
    consumers = {
        "cc_runtime": cc_runtime,
        "generate": generate,
        "package": package,
        "verify_test": verify_test,
    }
    tests = []
    for consumer, target in consumers.items():
        unknown_version_test(
            name = "%s_unknown_version_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
            expected = [
                "needs popili 1.99.0 (set by --@rules_coco//:version), but no registered Coco toolchain provides it.",
                registered,
                "coco.toolchain(versions = [...])",
                "target_settings",
            ],
        )
        local_without_local_test(
            name = "%s_local_without_local_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
            expected = [
                "needs the local popili (set by --@rules_coco//:version), but no local Coco toolchain is registered.",
                registered,
                "coco.local_toolchain(popili = ...)",
            ],
        )
        no_execution_platform_test(
            name = "%s_no_execution_platform_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
            expected = [
                "needs popili %s (the default), which is registered, but none of the registered execution platforms can run it" % stable,
                "osx/aarch64, linux/aarch64, linux/x86_64, windows/x86_64",
                registered,
            ],
        )
        tests += ["%s_%s_%s" % (name, case, consumer) for case in ["unknown_version", "local_without_local", "no_execution_platform"]]

    fetch_license_without_toolchain_test(
        name = "%s_fetch_license_without_toolchain" % name,
        size = "small",
        target_under_test = fetch_license,
    )
    tests.append("%s_fetch_license_without_toolchain" % name)

    native.test_suite(name = name, tests = tests)
