"""Analysis tests for `popili_version`.

The root registers `stable` and `testing`, so the pins under test are `stable`, which is also the
default, and an unregistered pin has no toolchain. Which popili a target resolved is read
off the action it would run, whose popili lives in a version-mangled repository
(`io_cocotec_coco_<os>_<arch>__<version>`), off its `$(POPILI)` make variable, or off the headers
of the runtime it forwards. Every pinned consumer is checked under a flag naming a version nobody
registered, where only its pin can make it resolve; that pins share or leave the configuration of
unpinned targets is asserted per consumer by e2e/multi_version, which registers two versions to
choose between, and the transition's decisions by the unit tests of `pin_transition_settings`. An
unpinned target keeps the configuration it has without any transition. The flag itself takes no
aliases: `--@rules_coco//:version=stable` fails saying which version to name.
Every test that compares bin dirs fixes the flags of both sides, so the suite holds whatever the
command line sets.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_coco//coco/private:version_resolution.bzl", "resolve_version_alias")  # buildifier: disable=bzl-visibility
load(":output_root.bzl", "output_root")
load(":popili_evidence.bzl", "assert_popili_version")

_VERSION_FLAG = str(Label("@rules_coco//:version"))
_SOURCE_SETTING = str(Label("@rules_coco//:_version_source"))

_STABLE = resolve_version_alias("stable")

def _resolves_impl(ctx):
    env = analysistest.begin(ctx)
    assert_popili_version(env, analysistest.target_under_test(env), resolve_version_alias(ctx.attr.version))
    return analysistest.end(env)

_VERSION_ATTRS = {"version": attr.string(mandatory = True)}

# The flag names a version nobody registered, so only a pin can make the target resolve at all.
pin_beats_flag_test = analysistest.make(
    _resolves_impl,
    attrs = _VERSION_ATTRS,
    config_settings = {_VERSION_FLAG: "1.99.0"},
)

def _reference(ctx):
    reference = ctx.attr.reference
    return reference[0] if type(reference) == "list" else reference

def _same_configuration_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.equals(env, output_root(_reference(ctx)), output_root(analysistest.target_under_test(env)), "bin dir of the target under test, compared with the reference's")
    return analysistest.end(env)

def _reference_attrs(settings):
    return {"reference": attr.label(mandatory = True, cfg = analysis_test_transition(settings = settings))}

def _same_configuration_under(settings):
    """A test that its target, under `settings`, lands in the bin dir of `reference` under `settings`."""
    return analysistest.make(_same_configuration_impl, attrs = _reference_attrs(settings), config_settings = settings)

_DEFAULT = {_VERSION_FLAG: ""}

# Names the version stable stands for. Also sets the source setting, which no command line does,
# so both sides' analysis_test_transition changes some option even when the command line names
# that version, and neither stays in the unmarked configuration.
_CONCRETE = {_VERSION_FLAG: _STABLE, _SOURCE_SETTING: "pin"}

# Compared with a reference that has no transition at all: the target's own transition changed
# nothing, so its output paths are the ones a target without a transition has.
default_configuration_unchanged_test = _same_configuration_under(_DEFAULT)
concrete_configuration_unchanged_test = _same_configuration_under(_CONCRETE)

def _expect_message_impl(ctx):
    env = analysistest.begin(ctx)
    for expected in ctx.attr.expected:
        asserts.expect_failure(env, expected)
    return analysistest.end(env)

_MESSAGE_ATTRS = {"expected": attr.string_list(mandatory = True)}

expect_message_test = analysistest.make(
    _expect_message_impl,
    attrs = _MESSAGE_ATTRS,
    expect_failure = True,
)

alias_flag_message_test = analysistest.make(
    _expect_message_impl,
    attrs = _MESSAGE_ATTRS,
    config_settings = {_VERSION_FLAG: "stable"},
    expect_failure = True,
)

def _unpinned_tests(name, unpinned, current_popili_version, untransitioned):
    """The tests for unpinned targets; see popili_pinning_tests for the arguments."""
    tests = []
    for consumer, target in unpinned.items():
        default_configuration_unchanged_test(
            name = "%s_unpinned_default_configuration_unchanged_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
            reference = untransitioned,
        )
        concrete_configuration_unchanged_test(
            name = "%s_unpinned_flag_configuration_unchanged_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
            reference = untransitioned,
        )
        tests += ["%s_unpinned_%s_%s" % (name, case, consumer) for case in ["default_configuration_unchanged", "flag_configuration_unchanged"]]

    # The other consumers get this message in test/popili_diagnostics.
    alias_flag_message_test(
        name = "%s_alias_flag_message_current_popili_version" % name,
        size = "small",
        target_under_test = current_popili_version,
        expected = [
            "needs popili stable (set by --@rules_coco//:version), but stable is an alias",
            "set it to %s, the version it stands for." % _STABLE,
        ],
    )
    tests.append("%s_alias_flag_message_current_popili_version" % name)
    return tests

def popili_pinning_tests(name, pinned, unregistered, unpinned, current_popili_version, untransitioned):
    """Declares the pin tests and a test_suite over them.

    Args:
        name: Prefix for the tests and the name of the test_suite.
        pinned: A dict mapping a short name to a target pinned with `popili_version = "stable"`.
        unregistered: A coco_generate pinned to a version nobody registered (1.99.0).
        unpinned: A dict mapping a short name to an unpinned target that resolves popili:
            `generate` (a coco_generate over a package of its own), `verify_test`, `package` (a
            coco_package with typecheck = True) and `cc_runtime` (`@rules_coco//coco:cc_runtime`).
        current_popili_version: `@rules_coco//coco:current_popili_version`.
        untransitioned: A target with no transition and a generated output, such as a write_file.
    """
    tests = []
    for consumer, target in pinned.items():
        pin_beats_flag_test(
            name = "%s_pin_beats_flag_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
            version = "stable",
        )
        tests.append("%s_pin_beats_flag_%s" % (name, consumer))

    expect_message_test(
        name = "%s_pinned_unregistered" % name,
        size = "small",
        target_under_test = unregistered,
        expected = [
            # The package beneath the pin requires a toolchain too and fails first, in the pinned configuration.
            ":base needs popili 1.99.0 (pinned by popili_version on a target above it), but no registered Coco toolchain provides it.",
            "Registered popili versions: %s (the default), %s." % (_STABLE, resolve_version_alias("testing")),
            "coco.toolchain(versions = [...])",
        ],
    )
    tests.append("%s_pinned_unregistered" % name)
    tests += _unpinned_tests(name, unpinned, current_popili_version, untransitioned)

    native.test_suite(name = name, tests = tests)
