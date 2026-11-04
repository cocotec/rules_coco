"""Analysis tests: a bring-your-own toolchain is checked against the popili version a target asks for.

//tools:byo_popili has no target_settings, so toolchain resolution selects it whatever version a
target's configuration asks for, and rules_coco compares that version with the one the toolchain
declares. 1.99.0 is a version it does not provide. Nothing is executed. Every test fixes both
version flags itself, so the suite means the same thing whatever the command line sets.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

_VERSION_FLAG = str(Label("@rules_coco//:version"))
_FORCE_FLAG = str(Label("@rules_coco//:force_version"))

# A version the toolchain does not provide.
UNPROVIDED_VERSION = "1.99.0"

def _expect_message_impl(ctx):
    env = analysistest.begin(ctx)
    for expected in ctx.attr.expected:
        asserts.expect_failure(env, expected)
    return analysistest.end(env)

def _failure_test(settings):
    return analysistest.make(
        _expect_message_impl,
        attrs = {"expected": attr.string_list(mandatory = True)},
        config_settings = settings,
        expect_failure = True,
    )

mismatch_under_pin_test = _failure_test({_VERSION_FLAG: "", _FORCE_FLAG: False})
mismatch_forced_test = _failure_test({_VERSION_FLAG: UNPROVIDED_VERSION, _FORCE_FLAG: True})
unlisted_test = _failure_test({_VERSION_FLAG: UNPROVIDED_VERSION, _FORCE_FLAG: False})
alias_rejected_test = _failure_test({})

def byo_version_tests(name, pinned, unprovided, lists_unprovided, lists_staged, staged_version):
    """Declares the tests and a test_suite over them.

    Args:
        name: Prefix for the tests and the name of the test_suite.
        pinned: A target pinned to `staged_version`.
        unprovided: A coco_generate pinned to UNPROVIDED_VERSION.
        lists_unprovided: A coco_package with `popili_versions = [UNPROVIDED_VERSION]`.
        lists_staged: A coco_package with `popili_versions = [staged_version, UNPROVIDED_VERSION]`.
        staged_version: The version //tools:byo_popili declares.
    """

    # Two fragments: the label between them prints with a repository prefix under bzlmod.
    mismatch = "//tools:byo_popili, which serves every target, is popili %s." % staged_version
    mismatch_under_pin_test(
        name = name + "_pin_mismatch",
        size = "small",
        target_under_test = unprovided,
        expected = [
            # The package beneath the pin is analysed in the pinned configuration and fails first.
            ":byo_toolchain needs popili %s (pinned by a target above it), but the bring-your-own coco_toolchain " % UNPROVIDED_VERSION,
            mismatch,
            "pins and --@rules_coco//:version must name %s or be left out." % staged_version,
        ],
    )

    # Forced, the pin is ignored and the flag's version is checked against the toolchain.
    mismatch_forced_test(
        name = name + "_forced_mismatch",
        size = "small",
        target_under_test = pinned,
        expected = [":byo_toolchain needs popili %s (forced by --@rules_coco//:force_version), but the bring-your-own coco_toolchain " % UNPROVIDED_VERSION, mismatch],
    )

    # A package whose list leaves out the toolchain's version is told to list it, whatever was asked for.
    unlisted_test(
        name = name + "_unlisted",
        size = "small",
        target_under_test = lists_unprovided,
        expected = [
            ":lists_unprovided gets popili %s from the bring-your-own coco_toolchain " % staged_version,
            "popili_versions do not list it: %s. Add %s to its popili_versions" % (UNPROVIDED_VERSION, staged_version),
        ],
    )

    # The flag asks for UNPROVIDED_VERSION, which the package lists, so its own transition keeps it.
    # That the list names the toolchain's version too does not excuse the flag naming another.
    unlisted_test(
        name = name + "_listed_flag_mismatch",
        size = "small",
        target_under_test = lists_staged,
        expected = [":lists_staged needs popili %s (set by --@rules_coco//:version), but the bring-your-own coco_toolchain " % UNPROVIDED_VERSION, mismatch],
    )

    # A toolchain's popili_version must be a version, not an alias.
    alias_rejected_test(
        name = name + "_alias_rejected",
        size = "small",
        target_under_test = "//tools:alias_popili",
        expected = ["popili_version must be the version of the popili binary, such as \"1.5.8\", not \"stable\""],
    )
    native.test_suite(
        name = name,
        tests = [name + suffix for suffix in [
            "_pin_mismatch",
            "_forced_mismatch",
            "_unlisted",
            "_listed_flag_mismatch",
            "_alias_rejected",
        ]],
    )
