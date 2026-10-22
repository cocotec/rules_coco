"""Analysis tests: a target's `popili_version` decides which registered popili it runs.

Which popili a target resolved is read off the action it would run (the run action's executable,
or the text of a test's wrapper script), or for a library off the headers of the runtime its
`._gen` target forwards; the binary or runtime lives in a version-mangled repository
(`io_cocotec_coco_<os>_<arch>__<version>`), so the path names the version in both bzlmod and
WORKSPACE mode. A pin to the default (1.5.0) leaves the configuration alone, so its outputs land
next to an unpinned target's; a pin to 1.5.1 does not, which its resolving 1.5.1 without a flag
already shows. Each pin is checked under the flag that makes it matter: a pin to 1.5.0 under
`--@rules_coco//:version=1.5.1`, a pin to 1.5.1 without one. Nothing is executed.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_coco//test/popili_pinning:output_root.bzl", "output_root", "output_root_of")
load("@rules_coco//test/popili_pinning:popili_evidence.bzl", "assert_popili_version")

_VERSION_FLAG = str(Label("@rules_coco//:version"))

def _impl(ctx):
    env = analysistest.begin(ctx)
    assert_popili_version(env, analysistest.target_under_test(env), ctx.attr.expected_version)
    return analysistest.end(env)

_ATTRS = {"expected_version": attr.string(mandatory = True)}

popili_version_test = analysistest.make(_impl, attrs = _ATTRS)

# The command line asks for 1.5.1: a pin to 1.5.0 must still win, an unpinned target must follow.
popili_version_under_flag_test = analysistest.make(
    _impl,
    attrs = _ATTRS,
    config_settings = {_VERSION_FLAG: "1.5.1"},
)

def _configuration_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.equals(env, output_root(ctx.attr.reference[0]), output_root(analysistest.target_under_test(env)), "bin dir of a target pinned to the default, compared with the unpinned reference's")
    return analysistest.end(env)

# Both sides under the same, unset flag, so the comparison holds whatever the command line sets.
_DEFAULT = {_VERSION_FLAG: ""}

configuration_test = analysistest.make(
    _configuration_impl,
    attrs = {
        "reference": attr.label(mandatory = True, cfg = analysis_test_transition(settings = _DEFAULT)),
    },
    config_settings = _DEFAULT,
)

def _expect_message_impl(ctx):
    env = analysistest.begin(ctx)
    for expected in ctx.attr.expected:
        asserts.expect_failure(env, expected)
    return analysistest.end(env)

# A library whose runtime is not the version its generated code came from.
library_version_mismatch_test = analysistest.make(
    _expect_message_impl,
    attrs = {"expected": attr.string_list(mandatory = True)},
    config_settings = _DEFAULT,
    expect_failure = True,
)

def _runtime_extra_dep_once_impl(ctx):
    env = analysistest.begin(ctx)
    extra_dep = ctx.attr.extra_dep[0]
    linked = [
        library
        for linker_input in analysistest.target_under_test(env)[CcInfo].linking_context.linker_inputs.to_list()
        if linker_input.owner == extra_dep.label
        for library in linker_input.libraries
    ]
    asserts.equals(env, 1, len(linked), "copies of %s linked" % extra_dep.label)
    asserts.equals(env, output_root(extra_dep), output_root_of(linked[0]) if linked else None, "bin dir of the linked copy, compared with an unpinned build's")
    return analysistest.end(env)

# A target linking a library pinned to 1.5.1 and, directly, an extra dep of that runtime: the
# runtime's copy is built where unpinned targets are, so the two are one.
runtime_extra_dep_once_test = analysistest.make(
    _runtime_extra_dep_once_impl,
    attrs = {
        "extra_dep": attr.label(mandatory = True, cfg = analysis_test_transition(settings = _DEFAULT)),
    },
    config_settings = _DEFAULT,
)

def pinned_popili_tests(name, pinned, unpinned, reference):
    """Declares the version-selection tests and a test_suite over them.

    Args:
        name: Prefix for the tests and the name of the test_suite.
        pinned: A dict mapping a version to a dict of short name -> target pinned to that version.
        unpinned: A dict of short name -> target without a pin (so on the default, 1.5.0).
        reference: An unpinned target with a generated output, whose bin dir a target pinned to
            the default must share.
    """
    tests = []
    for version, targets in pinned.items():
        for consumer, target in targets.items():
            if version == "1.5.0":
                popili_version_under_flag_test(
                    name = "%s_pin_beats_flag_%s" % (name, consumer),
                    size = "small",
                    target_under_test = target,
                    expected_version = version,
                )
                configuration_test(
                    name = "%s_configuration_%s" % (name, consumer),
                    size = "small",
                    target_under_test = target,
                    reference = reference,
                )
                tests += ["%s_pin_beats_flag_%s" % (name, consumer), "%s_configuration_%s" % (name, consumer)]
            else:
                popili_version_test(
                    name = "%s_pinned_%s" % (name, consumer),
                    size = "small",
                    target_under_test = target,
                    expected_version = version,
                )
                tests.append("%s_pinned_%s" % (name, consumer))
    for consumer, target in unpinned.items():
        popili_version_test(
            name = "%s_unpinned_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
            expected_version = "1.5.0",
        )
        popili_version_under_flag_test(
            name = "%s_unpinned_follows_flag_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
            expected_version = "1.5.1",
        )
        tests += ["%s_unpinned_%s" % (name, consumer), "%s_unpinned_follows_flag_%s" % (name, consumer)]
    native.test_suite(name = name, tests = tests)
