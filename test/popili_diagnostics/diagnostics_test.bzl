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

Shared by the root workspace and e2e/multi_version, which register different versions and no
local distribution, so the message can be checked for a version nobody registered, an alias on
the flag, `local` without a local toolchain, and the registered default when only an execution
platform popili is not published for exists (the host platform is replaced too, because Bazel
always offers the host as an execution platform otherwise). Test rules are also built for that
platform with it listed before the host, so Bazel runs them on it, where popili cannot run.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_coco//coco/private:coco.bzl", "TESTS_FOLLOW_TARGET_PLATFORM")  # buildifier: disable=bzl-visibility

_VERSION_FLAG = str(Label("//:version"))
_RISCV64 = str(Label(":riscv64"))
_RISCV64_CC_TOOLCHAIN = str(Label(":riscv64_stub_cc_toolchain"))

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

alias_version_test = analysistest.make(
    _expect_message_impl,
    attrs = _ATTRS,
    config_settings = {_VERSION_FLAG: "stable"},
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
        _VERSION_FLAG: "",
        "//command_line_option:extra_execution_platforms": [_RISCV64],
        "//command_line_option:host_platform": _RISCV64,
    },
    expect_failure = True,
)

test_platform_mismatch_test = analysistest.make(
    _expect_message_impl,
    attrs = _ATTRS,
    config_settings = {
        "//command_line_option:extra_execution_platforms": [_RISCV64],
        "//command_line_option:extra_toolchains": [_RISCV64_CC_TOOLCHAIN],
        "//command_line_option:platforms": [_RISCV64],
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

def popili_diagnostics_tests(name, registered_versions, targets, test_targets = [], fetch_license = None):
    """Declares the failure-message tests per target, plus a test_suite.

    Args:
        name: Prefix for the tests and the name of the test_suite.
        registered_versions: The versions the workspace registers, the default first.
        targets: A dict mapping a short name to a target that resolves the Coco toolchain.
        test_targets: The short names in `targets` of test rules, which resolve it where the test runs.
        fetch_license: An optional `fetch_license` target, checked to yield no files.
    """
    default = registered_versions[0]
    registered = "Registered popili versions: %s." % ", ".join(
        ["%s (the default)" % default] + registered_versions[1:],
    )
    tests = []
    for consumer, target in targets.items():
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
        alias_version_test(
            name = "%s_alias_version_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
            expected = [
                "needs popili stable (set by --@rules_coco//:version), but stable is an alias",
                "set it to ",
                registered,
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
                "needs popili %s (the default), which is registered, but none of the registered execution platforms can run it." % default,
                registered,
            ],
        )
        tests += [
            "%s_%s_%s" % (name, case, consumer)
            for case in ["unknown_version", "alias_version", "local_without_local", "no_execution_platform"]
        ]

    if TESTS_FOLLOW_TARGET_PLATFORM:
        for consumer in test_targets:
            test_platform_mismatch_test(
                name = "%s_test_platform_mismatch_%s" % (name, consumer),
                size = "small",
                target_under_test = targets[consumer],
                expected = [
                    "needs popili %s (the default), which is registered, but Bazel runs a test on an execution platform matching the test's target platform (" % default,
                    "no registered execution platform both matches it and can run popili",
                    registered,
                ],
            )
            tests.append("%s_test_platform_mismatch_%s" % (name, consumer))

    if fetch_license:
        fetch_license_without_toolchain_test(
            name = "%s_fetch_license_without_toolchain" % name,
            size = "small",
            target_under_test = fetch_license,
        )
        tests.append("%s_fetch_license_without_toolchain" % name)

    native.test_suite(name = name, tests = tests)
