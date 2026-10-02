"""Asserts which popili the Coco toolchain resolves to, without running popili.

The resolved toolchain's binary lives in a version-mangled repository
(`io_cocotec_coco_<os>_<arch>__<suffix>`), so its path is enough to tell which popili a
target would use. The rule resolves `@rules_coco//coco:toolchain_type` itself, in its own
configuration, so it sees exactly what a real popili-running rule in that configuration
would see -- including the effect of a `with_popili_version` transition above it.
"""

def _popili_version_report_impl(ctx):
    popili = ctx.toolchains["@rules_coco//coco:toolchain_type"].coco.path

    if not ctx.attr.expected_repo_suffix in popili:
        fail(
            "%s: expected the Coco toolchain to resolve to a popili in a repository " % ctx.label +
            "ending %r, but it resolved to %r." % (ctx.attr.expected_repo_suffix, popili),
        )

    out = ctx.actions.declare_file(ctx.label.name + ".txt")
    ctx.actions.write(out, popili + "\n")
    return [DefaultInfo(files = depset([out]))]

popili_version_report = rule(
    doc = "Fails at analysis time unless the resolved popili comes from the expected version's repository.",
    implementation = _popili_version_report_impl,
    attrs = {
        "expected_repo_suffix": attr.string(
            doc = "The mangled version the toolchain repository name must end with, e.g. '__1_5_1'.",
            mandatory = True,
        ),
    },
    toolchains = ["@rules_coco//coco:toolchain_type"],
)
