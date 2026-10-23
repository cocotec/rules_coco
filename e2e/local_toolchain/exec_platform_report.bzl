"""Asserts which execution platform popili-running rules resolve to, and which popili.

Starlark cannot see a rule's own execution platform, so a probe toolchain type tells it
apart: one probe toolchain is constrained to the foreign platform, the fallback to none.
A rule requiring both the Coco toolchain and the probe resolves on the first registered
execution platform that offers both, which is where any popili-running rule would run.

Only the analysis test registers :foreign, listed before the host. Registered for the whole
build, it would also attract unrelated exec tools without constraints, such as the shell
launcher of Bazel 9's coverage helper on Windows, which then needs a C++ toolchain for it.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

PopiliExecPlatformInfo = provider(
    doc = "The execution platform the Coco toolchain resolved for, as named by the probe, and its version.",
    fields = {
        "exec_platform": "The exec_platform of the resolved probe toolchain.",
        "popili_version": "The `popili_version` of the resolved Coco toolchain.",
    },
)

def _exec_platform_probe_impl(ctx):
    return [platform_common.ToolchainInfo(exec_platform = ctx.attr.exec_platform)]

exec_platform_probe = rule(
    doc = "Names the execution platform the toolchain() wrapping it is constrained to.",
    implementation = _exec_platform_probe_impl,
    attrs = {
        "exec_platform": attr.string(mandatory = True),
    },
)

def _popili_exec_platform_impl(ctx):
    return [PopiliExecPlatformInfo(
        exec_platform = ctx.toolchains["//:exec_platform_probe_type"].exec_platform,
        popili_version = ctx.toolchains["@rules_coco//coco:toolchain_type"].popili_version,
    )]

popili_exec_platform = rule(
    doc = "Reports the execution platform popili would run on, and which popili.",
    implementation = _popili_exec_platform_impl,
    toolchains = [
        "@rules_coco//coco:toolchain_type",
        "//:exec_platform_probe_type",
    ],
)

def _popili_exec_platform_test_impl(ctx):
    env = analysistest.begin(ctx)
    info = analysistest.target_under_test(env)[PopiliExecPlatformInfo]
    asserts.equals(env, ctx.attr.expected, info.exec_platform, "execution platform the Coco toolchain resolved for")
    asserts.equals(env, ctx.attr.expected_version, info.popili_version, "popili_version of the Coco toolchain")
    return analysistest.end(env)

popili_exec_platform_test = analysistest.make(
    _popili_exec_platform_test_impl,
    attrs = {
        "expected": attr.string(
            doc = "The exec_platform of the probe toolchain expected to resolve alongside the Coco toolchain.",
            mandatory = True,
        ),
        "expected_version": attr.string(
            doc = "The `popili_version` the resolved Coco toolchain must carry.",
            mandatory = True,
        ),
    },
    config_settings = {
        "//command_line_option:extra_execution_platforms": [str(Label("//:foreign")), str(Label("@platforms//host"))],
    },
)
