"""Asserts which execution platform popili-running rules resolve to.

Starlark cannot see a rule's own execution platform, so a probe toolchain type tells it
apart: one probe toolchain is constrained to the foreign platform, the fallback to none.
A rule requiring both the Coco toolchain and the probe resolves on the first registered
execution platform that offers both, which is where any popili-running rule would run.
"""

def _exec_platform_probe_impl(ctx):
    return [platform_common.ToolchainInfo(exec_platform = ctx.attr.exec_platform)]

exec_platform_probe = rule(
    doc = "Names the execution platform the toolchain() wrapping it is constrained to.",
    implementation = _exec_platform_probe_impl,
    attrs = {
        "exec_platform": attr.string(mandatory = True),
    },
)

def _popili_exec_platform_report_impl(ctx):
    resolved = ctx.toolchains["//:exec_platform_probe_type"].exec_platform
    if resolved != ctx.attr.expected:
        fail(
            "%s: expected popili to run on the %r execution platform, " % (ctx.label, ctx.attr.expected) +
            "but the Coco toolchain resolved for %r." % resolved,
        )

    out = ctx.actions.declare_file(ctx.label.name + ".txt")
    ctx.actions.write(out, resolved + "\n")
    return [DefaultInfo(files = depset([out]))]

popili_exec_platform_report = rule(
    doc = "Fails at analysis time unless popili would run on the expected execution platform.",
    implementation = _popili_exec_platform_report_impl,
    attrs = {
        "expected": attr.string(
            doc = "The exec_platform of the probe toolchain expected to resolve alongside the Coco toolchain.",
            mandatory = True,
        ),
    },
    toolchains = [
        "@rules_coco//coco:toolchain_type",
        "//:exec_platform_probe_type",
    ],
)
