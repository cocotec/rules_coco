"""Analysis tests: selecting the local popili off the host fails with rules_coco's own message.

Since the local toolchain is constrained to the host, making `:foreign` the only execution platform
(the host platform included, which Bazel otherwise always offers) leaves the local toolchain
unresolvable, and the consumer must say that this is a host-only toolchain rather than a missing one.
The registered list is not checked beyond naming `local`: in bzlmod it also holds the extension's
default `stable`, since no module declares `coco.toolchain`; in WORKSPACE mode it is `local` alone.

A test built for `:foreign` fails differently on Bazel 9+: Bazel runs it on an execution platform
matching its target platform, which `:foreign`, listed before the host in .bazelrc, is and the host
is not, so the message must name the test's target platform instead of claiming the host is not
registered.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

_FOREIGN = str(Label("//:foreign"))
_FOREIGN_CC_TOOLCHAIN = str(Label("@rules_coco//test/popili_diagnostics:riscv64_stub_cc_toolchain"))

def _impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "needs the local popili (set by --@rules_coco//:version), but it only runs on the host platform (")
    asserts.expect_failure(env, "no registered execution platform is the host")
    asserts.expect_failure(env, "Registered popili versions: ")
    asserts.expect_failure(env, "local.")
    return analysistest.end(env)

def _test_off_target_platform_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "needs the local popili (set by --@rules_coco//:version), which only runs on the host platform (")
    asserts.expect_failure(env, "matching the test's target platform (%s)" % _FOREIGN)
    asserts.expect_failure(env, "no registered execution platform both matches it and is the host")
    return analysistest.end(env)

local_test_off_target_platform_test = analysistest.make(
    _test_off_target_platform_impl,
    config_settings = {
        "//command_line_option:extra_toolchains": [_FOREIGN_CC_TOOLCHAIN],
        "//command_line_option:platforms": [_FOREIGN],
    },
    expect_failure = True,
)

local_off_host_test = analysistest.make(
    _impl,
    config_settings = {
        "//command_line_option:extra_execution_platforms": [_FOREIGN],
        "//command_line_option:host_platform": _FOREIGN,
    },
    expect_failure = True,
)
