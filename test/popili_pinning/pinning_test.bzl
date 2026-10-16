"""Analysis tests for `popili_version` and aliases in `--@rules_coco//:version`.

The root registers `stable` only, so the pins under test are that alias, and a pin to any other
version has no toolchain. Which popili a target resolved is read off the action it would run,
whose popili lives in a version-mangled repository (`io_cocotec_coco_<os>_<arch>__<version>`),
off its `$(POPILI)` make variable, or off the headers of the runtime it forwards. An alias in the
flag itself (`--@rules_coco//:version=stable`) is resolved by the transition of every rule that
resolves popili, so an unpinned target under it resolves the version the alias names, in the
configuration `--@rules_coco//:version=<that version>` produces; an alias naming an unregistered
version fails naming that version. Every test that compares bin dirs fixes the flags of both
sides, so the suite holds whatever the command line sets.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_coco//coco/private:version_resolution.bzl", "resolve_version_alias", "version_to_repo_suffix")  # buildifier: disable=bzl-visibility

_VERSION_FLAG = str(Label("@rules_coco//:version"))
_SOURCE_SETTING = str(Label("@rules_coco//:_version_source"))

_STABLE = resolve_version_alias("stable")

# An alias the root does not register (its version differs from stable's).
_UNREGISTERED_ALIAS = "testing"

def _popili_evidence(target):
    """Text naming the repository of the popili a target resolved.

    The popili a run action executes, the text of a test's wrapper script or of the typecheck
    script, `$(POPILI)` for `current_popili_version`, or the headers of the runtime a runtime
    target forwards.
    """
    if platform_common.TemplateVariableInfo in target:
        return target[platform_common.TemplateVariableInfo].variables["POPILI"]
    if CcInfo in target:
        return " ".join([header.path for header in target[CcInfo].compilation_context.headers.to_list()])
    typecheck_script = None
    for action in target.actions:
        if action.mnemonic in ("CocoGenerate", "CocoDiagram"):
            return action.argv[0]
        if action.mnemonic == "CocoTypecheck":
            typecheck_script = action.argv[0]
    executable = target[DefaultInfo].files_to_run.executable
    for action in target.actions:
        for output in action.outputs.to_list():
            if output == executable or output.path == typecheck_script:
                return action.content
    fail("%s runs no popili action and writes no wrapper script" % target.label)

def _assert_popili_version(env, target, version):
    repository = "__%s/" % version_to_repo_suffix(version)
    evidence = _popili_evidence(target).replace("\\", "/")
    asserts.true(env, repository in evidence, "expected popili %s (...%s) in: %s" % (version, repository, evidence))

def _resolves_impl(ctx):
    env = analysistest.begin(ctx)
    _assert_popili_version(env, analysistest.target_under_test(env), resolve_version_alias(ctx.attr.version))
    return analysistest.end(env)

_VERSION_ATTRS = {"version": attr.string(mandatory = True)}

resolves_pinned_test = analysistest.make(_resolves_impl, attrs = _VERSION_ATTRS)

# The flag names a version nobody registered, so only a pin can make the target resolve at all.
pin_beats_flag_test = analysistest.make(
    _resolves_impl,
    attrs = _VERSION_ATTRS,
    config_settings = {_VERSION_FLAG: "1.99.0"},
)

# The flag names the alias; the target under test has no pin.
alias_flag_resolves_test = analysistest.make(
    _resolves_impl,
    attrs = _VERSION_ATTRS,
    config_settings = {_VERSION_FLAG: "stable"},
)

def _output_root(target):
    for file in target[DefaultInfo].files.to_list():
        if not file.is_source:
            return file.root.path
    fail("%s has no generated file to read its bin dir off" % target.label)

def _reference(ctx):
    reference = ctx.attr.reference
    return reference[0] if type(reference) == "list" else reference

def _same_configuration_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.equals(env, _output_root(_reference(ctx)), _output_root(analysistest.target_under_test(env)), "bin dir of the target under test, compared with the reference's")
    return analysistest.end(env)

def _configuration_differs_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.false(env, _output_root(_reference(ctx)) == _output_root(analysistest.target_under_test(env)), "a pinned target keeps the configuration of the untransitioned reference")
    return analysistest.end(env)

def _same_configuration_under(settings, reference_settings = None):
    """A test that its target, under `settings`, lands in the bin dir of `reference` under `reference_settings` (`settings` by default)."""
    return analysistest.make(
        _same_configuration_impl,
        attrs = {"reference": attr.label(mandatory = True, cfg = analysis_test_transition(settings = reference_settings or settings))},
        config_settings = settings,
    )

_DEFAULT = {_VERSION_FLAG: ""}

# The alias and the resolved settings differ, so each side's analysis_test_transition must change
# some option whatever the command line's version flag is, or the side equal to the command line
# would stay in the unmarked configuration: both set the source setting, which no command line does.
_RESOLVED = {_VERSION_FLAG: _STABLE, _SOURCE_SETTING: "pin"}
_ALIASED = {_VERSION_FLAG: "stable", _SOURCE_SETTING: "pin"}

# Compared with a reference that has no transition at all: the target's own transition changed
# nothing, so its output paths are the ones a target without a transition has.
unpinned_configuration_unchanged_test = _same_configuration_under(_DEFAULT)
unaliased_configuration_unchanged_test = _same_configuration_under(_RESOLVED)

pinned_configuration_differs_test = analysistest.make(
    _configuration_differs_impl,
    attrs = {"reference": attr.label(mandatory = True, cfg = analysis_test_transition(settings = _DEFAULT))},
    config_settings = _DEFAULT,
)

# Under the alias the target lands where the flag naming the alias's version puts the reference.
alias_shares_resolved_configuration_test = _same_configuration_under(_ALIASED, _RESOLVED)

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

# The flag names an alias of a version nobody registered.
alias_unregistered_test = analysistest.make(
    _expect_message_impl,
    attrs = _MESSAGE_ATTRS,
    config_settings = {_VERSION_FLAG: _UNREGISTERED_ALIAS},
    expect_failure = True,
)

def _alias_flag_tests(name, aliased, current_popili_version, untransitioned):
    """The tests for an alias in --@rules_coco//:version; see popili_pinning_tests for the arguments."""
    tests = []
    for consumer, target in aliased.items():
        alias_flag_resolves_test(
            name = "%s_alias_flag_resolves_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
            version = "stable",
        )
        alias_shares_resolved_configuration_test(
            name = "%s_alias_shares_resolved_configuration_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
            reference = target,
        )
        unpinned_configuration_unchanged_test(
            name = "%s_unpinned_configuration_unchanged_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
            reference = untransitioned,
        )
        unaliased_configuration_unchanged_test(
            name = "%s_unaliased_configuration_unchanged_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
            reference = untransitioned,
        )
        tests += ["%s_%s_%s" % (name, case, consumer) for case in ["alias_flag_resolves", "alias_shares_resolved_configuration", "unpinned_configuration_unchanged", "unaliased_configuration_unchanged"]]
    alias_flag_resolves_test(
        name = "%s_alias_flag_resolves_current_popili_version" % name,
        size = "small",
        target_under_test = current_popili_version,
        version = "stable",
    )
    tests.append("%s_alias_flag_resolves_current_popili_version" % name)
    for consumer in ["generate", "cc_runtime"]:
        alias_unregistered_test(
            name = "%s_alias_unregistered_%s" % (name, consumer),
            size = "small",
            target_under_test = aliased[consumer],
            expected = [
                "needs popili %s (set by --@rules_coco//:version), but no registered Coco toolchain provides it." % resolve_version_alias(_UNREGISTERED_ALIAS),
                "Registered popili versions: %s (the default)." % _STABLE,
            ],
        )
        tests.append("%s_alias_unregistered_%s" % (name, consumer))
    return tests

def popili_pinning_tests(name, pinned, unregistered, aliased, current_popili_version, untransitioned):
    """Declares the pin tests and a test_suite over them.

    Args:
        name: Prefix for the tests and the name of the test_suite.
        pinned: A dict mapping a short name to a target pinned with `popili_version = "stable"`.
        unregistered: A coco_generate pinned to a version nobody registered (1.99.0).
        aliased: A dict mapping a short name to an unpinned target with an action or a runtime to
            read the resolved popili off: `generate` (a coco_generate over a package of its own),
            `verify_test`, `package` (a coco_package with typecheck = True) and `cc_runtime`
            (`@rules_coco//coco:cc_runtime`).
        current_popili_version: `@rules_coco//coco:current_popili_version`.
        untransitioned: A target with no transition and a generated output, such as a write_file.
    """
    tests = []
    for consumer, target in pinned.items():
        resolves_pinned_test(
            name = "%s_resolves_pinned_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
            version = "stable",
        )
        pin_beats_flag_test(
            name = "%s_pin_beats_flag_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
            version = "stable",
        )
        pinned_configuration_differs_test(
            name = "%s_pinned_configuration_differs_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
            reference = untransitioned,
        )
        tests += ["%s_%s_%s" % (name, case, consumer) for case in ["resolves_pinned", "pin_beats_flag", "pinned_configuration_differs"]]

    expect_message_test(
        name = "%s_pinned_unregistered" % name,
        size = "small",
        target_under_test = unregistered,
        expected = [
            # The package beneath the pin requires a toolchain too and fails first, in the pinned configuration.
            ":base needs popili 1.99.0 (pinned by popili_version on a target above it), but no registered Coco toolchain provides it.",
            "Registered popili versions: %s (the default)." % _STABLE,
            "coco.toolchain(versions = [...])",
        ],
    )
    tests.append("%s_pinned_unregistered" % name)
    tests += _alias_flag_tests(name, aliased, current_popili_version, untransitioned)

    native.test_suite(name = name, tests = tests)
