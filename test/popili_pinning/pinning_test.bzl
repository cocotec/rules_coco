"""Analysis tests for `popili_version` that need the root's registered versions.

The root registers `stable` and `testing`, so a pin to the alias `stable` has a toolchain only
once the transition resolves it, and a pin to 1.99.0 has none. The flag itself takes no aliases:
`--@rules_coco//:version=stable` fails saying which version to name. Under
`--@rules_coco//:force_version` even a pin to a version nobody registered is ignored, and the
flag's version is reported as forced. Which popili each rule runs with a pin, and that a pin to
the default leaves the configuration alone, is asserted by e2e/multi_version; the transition's
decisions by the unit tests of `pin_transition_settings`. Each test fixes both version flags, so
the suite holds whatever the command line sets.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_coco//coco/private:version_resolution.bzl", "resolve_version_alias")  # buildifier: disable=bzl-visibility
load(":popili_evidence.bzl", "assert_popili_version")

_VERSION_FLAG = str(Label("@rules_coco//:version"))
_FORCE_FLAG = str(Label("@rules_coco//:force_version"))

_STABLE = resolve_version_alias("stable")

def _resolves_stable_impl(ctx):
    env = analysistest.begin(ctx)
    assert_popili_version(env, analysistest.target_under_test(env), _STABLE)
    return analysistest.end(env)

# The flag names a version nobody registered, so only the pin can make the target resolve at all.
alias_pin_beats_flag_test = analysistest.make(
    _resolves_stable_impl,
    config_settings = {_VERSION_FLAG: "1.99.0", _FORCE_FLAG: False},
)

# Forced, the pin to 1.99.0 is ignored and the target resolves the flag's version.
forced_pin_ignored_test = analysistest.make(
    _resolves_stable_impl,
    config_settings = {_VERSION_FLAG: _STABLE, _FORCE_FLAG: True},
)

def _expect_message_impl(ctx):
    env = analysistest.begin(ctx)
    for expected in ctx.attr.expected:
        asserts.expect_failure(env, expected)
    return analysistest.end(env)

_MESSAGE_ATTRS = {"expected": attr.string_list(mandatory = True)}

expect_message_test = analysistest.make(
    _expect_message_impl,
    attrs = _MESSAGE_ATTRS,
    config_settings = {_VERSION_FLAG: "", _FORCE_FLAG: False},
    expect_failure = True,
)

# The flag names a version nobody registered and the pin names one that is: forced, the flag wins.
forced_flag_beats_pin_test = analysistest.make(
    _expect_message_impl,
    attrs = _MESSAGE_ATTRS,
    config_settings = {_VERSION_FLAG: "1.99.0", _FORCE_FLAG: True},
    expect_failure = True,
)

alias_flag_message_test = analysistest.make(
    _expect_message_impl,
    attrs = _MESSAGE_ATTRS,
    config_settings = {_VERSION_FLAG: "stable", _FORCE_FLAG: False},
    expect_failure = True,
)

def popili_pinning_tests(name, alias_pinned, unregistered, current_popili_version):
    """Declares the pin tests and a test_suite over them.

    Args:
        name: Prefix for the tests and the name of the test_suite.
        alias_pinned: A dict mapping a short name to a target pinned with `popili_version = "stable"`;
            `generate` is a coco_generate.
        unregistered: A coco_generate pinned to a version nobody registered (1.99.0).
        current_popili_version: `@rules_coco//coco:current_popili_version`.
    """
    tests = []
    for consumer, target in alias_pinned.items():
        alias_pin_beats_flag_test(
            name = "%s_alias_pin_beats_flag_%s" % (name, consumer),
            size = "small",
            target_under_test = target,
        )
        tests.append("%s_alias_pin_beats_flag_%s" % (name, consumer))
    forced_flag_beats_pin_test(
        name = name + "_forced_flag_beats_pin",
        size = "small",
        target_under_test = alias_pinned["generate"],
        expected = [
            # The package shares the forced configuration and fails first.
            ":base needs popili 1.99.0 (forced by --@rules_coco//:force_version), but no registered Coco toolchain provides it.",
            "Registered popili versions: %s (the default), %s." % (_STABLE, resolve_version_alias("testing")),
        ],
    )
    expect_message_test(
        name = name + "_pinned_unregistered",
        size = "small",
        target_under_test = unregistered,
        expected = [
            # The package beneath the pin requires a toolchain too and fails first, in the pinned configuration.
            ":base needs popili 1.99.0 (pinned by a target above it), but no registered Coco toolchain provides it.",
            "Registered popili versions: %s (the default), %s." % (_STABLE, resolve_version_alias("testing")),
            "coco.toolchain(versions = [...])",
        ],
    )
    forced_pin_ignored_test(
        name = name + "_forced_rescues_unregistered_pin",
        size = "small",
        target_under_test = unregistered,
    )

    # The other consumers get this message in test/popili_diagnostics.
    alias_flag_message_test(
        name = name + "_alias_flag_message_current_popili_version",
        size = "small",
        target_under_test = current_popili_version,
        expected = [
            "needs popili stable (set by --@rules_coco//:version), but stable is an alias",
            "set it to %s, the version it stands for." % _STABLE,
        ],
    )
    tests += [name + suffix for suffix in [
        "_forced_flag_beats_pin",
        "_pinned_unregistered",
        "_forced_rescues_unregistered_pin",
        "_alias_flag_message_current_popili_version",
    ]]
    native.test_suite(name = name, tests = tests)
