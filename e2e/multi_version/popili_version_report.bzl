"""Asserts which popili a target resolves to, without running popili.

Every resolved popili lives in a version-mangled repository
(`io_cocotec_coco_<os>_<arch>__<suffix>`), so file paths are enough to tell which version a
target would use. Everything is checked during analysis: no licence, network or popili
execution is needed, and it reads identically in WORKSPACE and bzlmod mode.

What is checked depends on which attribute is set:

- none: the rule resolves `@rules_coco//coco:toolchain_type` itself, in its own
  configuration, so it sees exactly what a popili-running rule there would see;
- `package`: the toolchain the coco_package resolved and forwards to its consumers.
"""

# buildifier: disable=bzl-visibility
load("@rules_coco//coco/private:coco.bzl", "CocoPackageInfo")

def _check_toolchain(ctx, toolchain, what):
    popili = toolchain.coco.path
    if ctx.attr.expected_repo_suffix + "/" not in popili:
        fail(
            "%s: expected %s to use a popili in a repository ending %r, but it uses %r." % (
                ctx.label,
                what,
                ctx.attr.expected_repo_suffix,
                popili,
            ),
        )
    return popili

def _popili_version_report_impl(ctx):
    if ctx.attr.package:
        info = ctx.attr.package[CocoPackageInfo]
        report = _check_toolchain(ctx, info.popili_toolchain, str(ctx.attr.package.label))
    else:
        toolchain = ctx.toolchains["@rules_coco//coco:toolchain_type"]
        if toolchain == None:
            fail("%s: no Coco toolchain resolved" % ctx.label)
        report = _check_toolchain(ctx, toolchain, "the Coco toolchain")

    out = ctx.actions.declare_file(ctx.label.name + ".txt")
    ctx.actions.write(out, report + "\n")
    return [DefaultInfo(files = depset([out]))]

popili_version_report = rule(
    doc = "Fails at analysis time unless the target uses the expected popili version.",
    implementation = _popili_version_report_impl,
    attrs = {
        "expected_repo_suffix": attr.string(
            doc = "The mangled version the repository name must end with, e.g. '__1_5_1'.",
            mandatory = True,
        ),
        "package": attr.label(
            doc = "A coco_package whose resolved toolchain to check.",
            providers = [CocoPackageInfo],
        ),
    },
    toolchains = [config_common.toolchain_type("@rules_coco//coco:toolchain_type", mandatory = False)],
)
