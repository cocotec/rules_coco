"""Asserts which popili the Coco toolchain resolves to, without running popili.

The resolved toolchain's binary lives in a version-mangled repository
(`io_cocotec_coco_<os>_<arch>__<suffix>`), so its path is enough to tell which popili a
target would use. The expected version is given as written in `coco.toolchain`, aliases
included, so the assertion follows `stable` as rules_coco moves it.
"""

# buildifier: disable=bzl-visibility
load("@rules_coco//coco/private:version_aliases.bzl", "VERSION_ALIASES")

# An in-repo test of rules_coco's own default, so it may read the private alias table.
# buildifier: disable=bzl-visibility
load("@rules_coco//coco/private:version_resolution.bzl", "version_to_repo_suffix")

def _popili_version_report_impl(ctx):
    # Resolved in this target's own configuration, like a coco_package built directly does.
    popili = ctx.toolchains["@rules_coco//coco:toolchain_type"].coco.path
    version = VERSION_ALIASES.get(ctx.attr.expected_version, ctx.attr.expected_version)
    suffix = "__" + version_to_repo_suffix(version)

    if not suffix in popili:
        fail(
            "%s: expected the Coco toolchain to resolve to popili %s (%r), in a repository " % (ctx.label, ctx.attr.expected_version, version) +
            "containing %r, but it resolved to %r." % (suffix, popili),
        )

    out = ctx.actions.declare_file(ctx.label.name + ".txt")
    ctx.actions.write(out, popili + "\n")
    return [DefaultInfo(files = depset([out]))]

popili_version_report = rule(
    doc = "Fails at analysis time unless the resolved popili comes from the expected version's repository.",
    implementation = _popili_version_report_impl,
    attrs = {
        "expected_version": attr.string(
            doc = "The version the toolchain must resolve to, as written in coco.toolchain, e.g. 'stable' or '1.5.1'.",
            mandatory = True,
        ),
    },
    toolchains = ["@rules_coco//coco:toolchain_type"],
)
