"""Analysis tests: a build without a matching Coco toolchain fails with rules_coco's own message.

Two versions are registered here and no local distribution, so the message can be checked for a
version nobody registered, for `local` without a local toolchain, and for the registered default
when only an execution platform popili is not published for exists (the host platform is replaced
too, because Bazel always offers the host as an execution platform otherwise).
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

_VERSION_FLAG = str(Label("@rules_coco//:version"))
_RISCV64 = str(Label("//:riscv64"))

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

def popili_diagnostics_tests(name, targets):
    """Declares the three failure-message tests per target, plus a test_suite.

    Args:
        name: Prefix for the tests and the name of the test_suite.
        targets: A dict mapping a short name to a target that resolves the Coco toolchain.
    """
    registered = "Registered popili versions: 1.5.0 (the default), 1.5.1."
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
                "needs popili 1.5.0 (the default), which is registered, but none of the registered execution platforms can run it",
                "osx/aarch64, linux/aarch64, linux/x86_64, windows/x86_64",
                registered,
            ],
        )
        tests += ["%s_%s_%s" % (name, case, consumer) for case in ["unknown_version", "local_without_local", "no_execution_platform"]]
    native.test_suite(name = name, tests = tests)
