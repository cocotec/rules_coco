"""Asserts which popili the Coco toolchain resolves to, without running popili.

The resolved toolchain's binary lives in a version-mangled repository
(`io_cocotec_coco_<os>_<arch>__<suffix>`), so its path is enough to tell which popili a
target would use, and the toolchain's `popili_version` field must agree with it. The rule resolves
`@rules_coco//coco:toolchain_type` itself, in its own configuration, so it sees exactly what
a real popili-running rule in that configuration would see. It has no `popili_version` of its
own, which is what keeps `with_popili_version` useful: the wrapper is how such a rule is given a
version. What the real rules do with their pins is asserted by pinned_popili_test.bzl.
"""

def _popili_version_report_impl(ctx):
    toolchain = ctx.toolchains["@rules_coco//coco:toolchain_type"]
    popili = toolchain.coco.path

    if not ctx.attr.expected_repo_suffix in popili:
        fail(
            "%s: expected the Coco toolchain to resolve to a popili in a repository " % ctx.label +
            "ending %r, but it resolved to %r." % (ctx.attr.expected_repo_suffix, popili),
        )
    if toolchain.popili_version != ctx.attr.expected_version:
        fail(
            "%s: expected the Coco toolchain to be popili %r, " % (ctx.label, ctx.attr.expected_version) +
            "but its version is %r." % toolchain.popili_version,
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
        "expected_version": attr.string(
            doc = "The `popili_version` the resolved toolchain must carry, e.g. '1.5.1'.",
            mandatory = True,
        ),
    },
    toolchains = ["@rules_coco//coco:toolchain_type"],
)
