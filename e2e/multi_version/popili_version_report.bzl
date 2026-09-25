"""Asserts which popili a target resolves to, without running popili.

Every resolved popili lives in a version-mangled repository
(`io_cocotec_coco_<os>_<arch>__<suffix>`), and every C/C++ runtime in
`io_cocotec_coco_cc_runtime__<suffix>`, so file paths are enough to tell which version a
target would use. Everything is checked during analysis: no licence, network or popili
execution is needed, and it reads identically in WORKSPACE and bzlmod mode.

What is checked depends on which attribute is set:

- none: the rule resolves `@rules_coco//coco:toolchain_type` itself, in its own
  configuration, so it sees exactly what a popili-running rule there would see;
- `package`: the toolchain the coco_package resolved and forwards to its consumers, plus
  the warnings it raised about pinned dependencies;
- `generated`: the toolchain a coco_generate target generated its code with;
- `library`: the C++ runtime linked into a coco_cc_library, which must be exactly one.
"""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

# buildifier: disable=bzl-visibility
load("@rules_coco//coco/private:coco.bzl", "CocoCcGeneratedInfo", "CocoPackageInfo")

_RUNTIME_REPO = "io_cocotec_coco_cc_runtime__"

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

def _check_warnings(ctx, info):
    warnings = info.popili_warnings
    if len(warnings) != len(ctx.attr.expected_warnings):
        fail("%s: expected %d popili warning(s) from %s, got %d: %r" % (
            ctx.label,
            len(ctx.attr.expected_warnings),
            ctx.attr.package.label,
            len(warnings),
            warnings,
        ))
    for expected in ctx.attr.expected_warnings:
        if not [w for w in warnings if expected in w]:
            fail("%s: no popili warning from %s contains %r; got %r" % (
                ctx.label,
                ctx.attr.package.label,
                expected,
                warnings,
            ))

def _check_runtime(ctx):
    repos = {}
    for header in ctx.attr.library[CcInfo].compilation_context.headers.to_list():
        for segment in header.path.split("/"):
            if _RUNTIME_REPO in segment:
                repos[segment] = True
    expected = [r for r in repos if r.endswith(_RUNTIME_REPO + ctx.attr.expected_repo_suffix.lstrip("_"))]
    if len(repos) != 1 or len(expected) != 1:
        fail("%s: expected %s to link exactly the runtime ending %r, but it links %r." % (
            ctx.label,
            ctx.attr.library.label,
            ctx.attr.expected_repo_suffix,
            sorted(repos.keys()),
        ))
    return sorted(repos.keys())[0]

def _popili_version_report_impl(ctx):
    set_attrs = [a for a in ["package", "generated", "library"] if getattr(ctx.attr, a)]
    if len(set_attrs) > 1:
        fail("%s: set at most one of package, generated and library" % ctx.label)
    if ctx.attr.expected_warnings and not ctx.attr.package:
        fail("%s: expected_warnings needs package" % ctx.label)

    if ctx.attr.package:
        info = ctx.attr.package[CocoPackageInfo]
        report = _check_toolchain(ctx, info.popili_toolchain, str(ctx.attr.package.label))
        _check_warnings(ctx, info)
    elif ctx.attr.generated:
        info = ctx.attr.generated[CocoCcGeneratedInfo]
        report = _check_toolchain(ctx, info.popili_toolchain, str(ctx.attr.generated.label))
    elif ctx.attr.library:
        report = _check_runtime(ctx)
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
        "expected_warnings": attr.string_list(
            doc = "With `package`: one substring per expected pinned-dependency warning. " +
                  "Empty asserts there are none.",
        ),
        "generated": attr.label(
            doc = "A coco_generate target whose code-generation toolchain to check.",
            providers = [CocoCcGeneratedInfo],
        ),
        "library": attr.label(
            doc = "A coco_cc_library whose linked C++ runtime to check.",
            providers = [CcInfo],
        ),
        "package": attr.label(
            doc = "A coco_package whose resolved toolchain and warnings to check.",
            providers = [CocoPackageInfo],
        ),
    },
    toolchains = [config_common.toolchain_type("@rules_coco//coco:toolchain_type", mandatory = False)],
)
