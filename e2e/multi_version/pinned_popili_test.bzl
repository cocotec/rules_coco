"""Analysis tests: a target's `popili_version` decides which registered popili it runs.

Which popili a target resolved is read off the action it would run (the run action's executable,
or the text of a test's wrapper script); the binary lives in a version-mangled repository
(`io_cocotec_coco_<os>_<arch>__<version>`), so the path names the version in both bzlmod and
WORKSPACE mode. Nothing is executed.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

_VERSION_FLAG = str(Label("@rules_coco//:version"))

def _popili_command(target):
    for action in target.actions:
        if action.mnemonic in ("CocoGenerate", "CocoDiagram"):
            return action.argv[0]
    executable = target[DefaultInfo].files_to_run.executable
    for action in target.actions:
        if executable in action.outputs.to_list():
            return action.content
    fail("%s runs no popili action and writes no wrapper script" % target.label)

def _impl(ctx):
    env = analysistest.begin(ctx)
    repository = "__%s/bin/popili" % ctx.attr.expected_version.replace(".", "_")
    command = _popili_command(analysistest.target_under_test(env)).replace("\\", "/")
    asserts.true(env, repository in command, "expected popili %s (...%s) in: %s" % (ctx.attr.expected_version, repository, command))
    return analysistest.end(env)

_ATTRS = {"expected_version": attr.string(mandatory = True)}

popili_version_test = analysistest.make(_impl, attrs = _ATTRS)

# The command line asks for 1.5.1: a pin to 1.5.0 must still win, an unpinned target must follow.
popili_version_under_flag_test = analysistest.make(
    _impl,
    attrs = _ATTRS,
    config_settings = {_VERSION_FLAG: "1.5.1"},
)

def pinned_popili_tests(name, pinned, unpinned):
    """Declares the version-selection tests and a test_suite over them.

    Args:
        name: Prefix for the tests and the name of the test_suite.
        pinned: A dict mapping a version to a dict of short name -> target pinned to that version.
        unpinned: A dict of short name -> target without a pin (so on the default, 1.5.0).
    """
    tests = []
    for version, targets in pinned.items():
        for consumer, target in targets.items():
            popili_version_test(
                name = "%s_pinned_%s" % (name, consumer),
                size = "small",
                target_under_test = target,
                expected_version = version,
            )
            popili_version_under_flag_test(
                name = "%s_pin_beats_flag_%s" % (name, consumer),
                size = "small",
                target_under_test = target,
                expected_version = version,
            )
            tests += ["%s_pinned_%s" % (name, consumer), "%s_pin_beats_flag_%s" % (name, consumer)]
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
