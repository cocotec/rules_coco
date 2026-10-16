"""Analysis tests: a target's `popili_version`, or a `with_popili_version` above it, decides which
registered popili it runs.

Which popili a target resolved is read off the action it would run (the run action's executable,
the text of a test's wrapper script, or a genrule's command); the binary lives in a version-mangled
repository (`io_cocotec_coco_<os>_<arch>__<version>`), so the path names the version in both bzlmod
and WORKSPACE mode. A wrapper has no actions of its own, so what it did to a pinned target is read
off that target's configuration: its bin dir must be the one a pin to the wrapper's version
produces. Nothing is executed. Every test fixes both version flags itself, so the suite means the
same thing whatever the command line sets.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

_VERSION_FLAG = str(Label("@rules_coco//:version"))
_FORCE_FLAG = str(Label("@rules_coco//:force_version"))

def _popili_command(target):
    for action in target.actions:
        if action.mnemonic in ("CocoGenerate", "CocoDiagram"):
            return action.argv[0]
        if action.mnemonic == "Genrule":
            return " ".join(action.argv)
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

# Nothing on the command line: a pin decides, an unpinned target gets the default.
popili_version_test = analysistest.make(
    _impl,
    attrs = _ATTRS,
    config_settings = {_VERSION_FLAG: "", _FORCE_FLAG: False},
)

# The command line asks for 1.5.1: a pin to 1.5.0 must still win, an unpinned target must follow.
popili_version_under_flag_test = analysistest.make(
    _impl,
    attrs = _ATTRS,
    config_settings = {_VERSION_FLAG: "1.5.1", _FORCE_FLAG: False},
)

# Forced: every pin is ignored, and the flag (or, empty, the default) applies to everything.
popili_version_forced_test = analysistest.make(
    _impl,
    attrs = _ATTRS,
    config_settings = {_VERSION_FLAG: "1.5.1", _FORCE_FLAG: True},
)

popili_version_forced_default_test = analysistest.make(
    _impl,
    attrs = _ATTRS,
    config_settings = {_VERSION_FLAG: "", _FORCE_FLAG: True},
)

def _output_root(target):
    return target[DefaultInfo].files.to_list()[0].root.path

def _same_configuration_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.equals(env, _output_root(ctx.attr.reference[0]), _output_root(analysistest.target_under_test(env)), "bin dir of a wrapped target, compared with a pin to the wrapper's version")
    return analysistest.end(env)

def _same_configuration_test(settings):
    return analysistest.make(
        _same_configuration_impl,
        attrs = {"reference": attr.label(mandatory = True, cfg = analysis_test_transition(settings = settings))},
        config_settings = settings,
    )

# A wrapper to 1.5.0 around a target pinned to 1.5.1 lands it where a pin to 1.5.0 would, with and
# without --@rules_coco//:version=1.5.1; forced, both the wrapper and the pin are ignored and the
# two targets share the command line's configuration instead.
wrapper_shares_pin_configuration_test = _same_configuration_test({_VERSION_FLAG: "", _FORCE_FLAG: False})
wrapper_shares_pin_configuration_under_flag_test = _same_configuration_test({_VERSION_FLAG: "1.5.1", _FORCE_FLAG: False})
wrapper_shares_forced_configuration_test = _same_configuration_test({_VERSION_FLAG: "1.5.1", _FORCE_FLAG: True})

def _wrapper_on_package_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "wraps the coco_package ")
    asserts.expect_failure(env, "in with_popili_version, which does not pin the targets that read the package")
    asserts.expect_failure(env, "Set popili_version = \"1.5.1\" on the coco_generate, coco_verify_test, coco_fmt_test or diagram targets that read the package instead")
    return analysistest.end(env)

wrapper_on_package_test = analysistest.make(
    _wrapper_on_package_impl,
    config_settings = {_VERSION_FLAG: "", _FORCE_FLAG: False},
    expect_failure = True,
)

def _wrapper_ignored_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "expected the Coco toolchain to resolve to a popili in a repository ending \"__1_5_1\", but it resolved to")
    asserts.expect_failure(env, "__1_5_0/")
    return analysistest.end(env)

# Forced without a version, a with_popili_version(version = "1.5.1") wrapper leaves its target on
# the default; the popili_version_report beneath it, which expects 1.5.1, then fails by design.
wrapper_ignored_when_forced_test = analysistest.make(
    _wrapper_ignored_impl,
    config_settings = {_VERSION_FLAG: "", _FORCE_FLAG: True},
    expect_failure = True,
)

def pinned_popili_tests(name, pinned, unpinned, wrapped, wrapped_generate, wrapped_generate_reference, wrapped_package):
    """Declares the version-selection tests and a test_suite over them.

    Args:
        name: Prefix for the tests and the name of the test_suite.
        pinned: A dict mapping a version to a dict of short name -> target pinned to that version,
            or given it by a with_popili_version around a target that has actions of its own.
        unpinned: A dict of short name -> target without a pin (so on the default, 1.5.0).
        wrapped: A with_popili_version(version = "1.5.1") around a popili_version_report expecting 1.5.1.
        wrapped_generate: A with_popili_version(version = "1.5.0") around a coco_generate pinned to 1.5.1.
        wrapped_generate_reference: A coco_generate pinned to 1.5.0.
        wrapped_package: A with_popili_version(version = "1.5.1") around a coco_package.
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
    for consumer, target in [item for targets in pinned.values() for item in targets.items()] + unpinned.items():
        popili_version_forced_test(
            name = "%s_forced_flag_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
            expected_version = "1.5.1",
        )
        popili_version_forced_default_test(
            name = "%s_forced_default_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
            expected_version = "1.5.0",
        )
        tests += ["%s_forced_flag_%s" % (name, consumer), "%s_forced_default_%s" % (name, consumer)]
    wrapper_ignored_when_forced_test(
        name = "%s_wrapper_ignored_when_forced" % name,
        size = "small",
        target_under_test = wrapped,
    )
    tests.append("%s_wrapper_ignored_when_forced" % name)
    for case, test in {
        "wrapper_shares_forced_configuration": wrapper_shares_forced_configuration_test,
        "wrapper_shares_pin_configuration": wrapper_shares_pin_configuration_test,
        "wrapper_shares_pin_configuration_under_flag": wrapper_shares_pin_configuration_under_flag_test,
    }.items():
        test(
            name = "%s_%s" % (name, case),
            size = "small",
            target_under_test = wrapped_generate,
            reference = wrapped_generate_reference,
        )
        tests.append("%s_%s" % (name, case))
    wrapper_on_package_test(
        name = "%s_wrapper_on_package_rejected" % name,
        size = "small",
        target_under_test = wrapped_package,
    )
    tests.append("%s_wrapper_on_package_rejected" % name)
    native.test_suite(name = name, tests = tests)
