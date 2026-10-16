"""Asserts which popili the Coco toolchain resolves to, without running popili.

The resolved toolchain's binary lives in a version-mangled repository
(`io_cocotec_coco_<os>_<arch>__<suffix>`), so its path is enough to tell which popili a
target would use, and the toolchain's `popili_version` field must agree with it. The rule resolves
`@rules_coco//coco:toolchain_type` itself, in its own configuration, so it sees exactly what
a real popili-running rule in that configuration would see -- including the effect of a
`with_popili_version` transition above it.
"""

# buildifier: disable=bzl-visibility
load("@rules_coco//coco/private:version_resolution.bzl", "version_to_repo_suffix")

def _popili_version_report_impl(ctx):
    toolchain = ctx.toolchains["@rules_coco//coco:toolchain_type"]
    popili = toolchain.coco.path
    suffix = "__" + version_to_repo_suffix(ctx.attr.expected_version)

    if not suffix in popili:
        fail(
            "%s: expected the Coco toolchain to resolve to a popili in a repository " % ctx.label +
            "ending %r, but it resolved to %r." % (suffix, popili),
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
        "expected_version": attr.string(
            doc = (
                "The popili version the resolved toolchain must be, e.g. '1.5.1': its repository " +
                "name ends with the mangled version and its `popili_version` field equals it."
            ),
            mandatory = True,
        ),
    },
    toolchains = ["@rules_coco//coco:toolchain_type"],
)
