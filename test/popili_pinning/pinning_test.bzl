"""Analysis tests for `popili_version` that need the root's registered versions.

The root registers `stable` among other versions, so a pin to the alias `stable` has a toolchain
only once the transition resolves it, and a pin to 1.99.0 has none. The flag itself takes no aliases:
`--@rules_coco//:version=stable` fails saying which version to name. Under
`--@rules_coco//:force_version` even a pin to a version nobody registered is ignored, and the
flag's version is reported as forced. A consumer running a version its package's `popili_versions`
do not list fails naming both; forced, it only warns. The package itself is analysed with the
first version it lists that is registered, unless forced. Which popili each rule runs with a pin,
and that a pin to the default leaves the configuration alone, is asserted by e2e/multi_version; the transition's
decisions by the unit tests of `pin_transition_settings`. Each test fixes both version flags, so
the suite holds whatever the command line sets.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_coco//coco/private:version_resolution.bzl", "resolve_version_alias")  # buildifier: disable=bzl-visibility
load("//test/version_registry:root_versions.bzl", "OLDER_VERSION", "ROOT_REGISTERED_VERSIONS")
load(":popili_evidence.bzl", "assert_popili_version")

_VERSION_FLAG = str(Label("@rules_coco//:version"))
_FORCE_FLAG = str(Label("@rules_coco//:force_version"))

_STABLE = resolve_version_alias("stable")

_REGISTERED = "Registered popili versions: %s (the default), %s." % (
    ROOT_REGISTERED_VERSIONS[0],
    ", ".join(ROOT_REGISTERED_VERSIONS[1:]),
)

def _resolves_stable_impl(ctx):
    env = analysistest.begin(ctx)
    assert_popili_version(env, analysistest.target_under_test(env), _STABLE)
    return analysistest.end(env)

# The flag names a version nobody registered, so only the pin can make the target resolve at all.
alias_pin_beats_flag_test = analysistest.make(
    _resolves_stable_impl,
    config_settings = {_VERSION_FLAG: "1.99.0", _FORCE_FLAG: False},
)

# Forced, every pin, and a package's own transition, is ignored and the target resolves the flag's version.
forced_pin_ignored_test = analysistest.make(
    _resolves_stable_impl,
    config_settings = {_VERSION_FLAG: _STABLE, _FORCE_FLAG: True},
)

def _resolves_older_impl(ctx):
    env = analysistest.begin(ctx)
    assert_popili_version(env, analysistest.target_under_test(env), OLDER_VERSION)
    return analysistest.end(env)

# A package's own transition takes it from the default to the first registered version it lists.
self_pin_test = analysistest.make(
    _resolves_older_impl,
    config_settings = {_VERSION_FLAG: "", _FORCE_FLAG: False},
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

def popili_pinning_tests(name, alias_pinned, unregistered, listing_package, listing_package_consumer, dependent_package, current_popili_version):
    """Declares the pin tests and a test_suite over them.

    Args:
        name: Prefix for the tests and the name of the test_suite.
        alias_pinned: A dict mapping a short name to a target pinned with `popili_version = "stable"`;
            `generate` is a coco_generate.
        unregistered: A coco_generate pinned to a version nobody registered (1.99.0).
        listing_package: A typechecked coco_package whose `popili_versions` list only `OLDER_VERSION`.
        listing_package_consumer: An unpinned target that runs popili on `listing_package`.
        dependent_package: A coco_package without `popili_versions` or a typecheck, depending on
            `listing_package`.
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
            _REGISTERED,
        ],
    )
    expect_message_test(
        name = name + "_pinned_unregistered",
        size = "small",
        target_under_test = unregistered,
        expected = [
            # The package beneath the pin requires a toolchain too and fails first, in the pinned configuration.
            ":base needs popili 1.99.0 (pinned by a target above it), but no registered Coco toolchain provides it.",
            _REGISTERED,
            "coco.toolchain(versions = [...])",
        ],
    )
    forced_pin_ignored_test(
        name = name + "_forced_rescues_unregistered_pin",
        size = "small",
        target_under_test = unregistered,
    )

    # The default is not among the package's popili_versions: the package takes the version it
    # lists and the consumer fails; forced, the package follows the flag and the consumer warns.
    expect_message_test(
        name = name + "_package_versions_message",
        size = "small",
        target_under_test = listing_package_consumer,
        expected = [
            ":listing_verify runs popili %s (the default) on " % _STABLE,
            ":listing, whose popili_versions do not list it: %s. Pin " % OLDER_VERSION,
            "to one of those with popili_version, or add %s to the popili_versions of " % _STABLE,
        ],
    )
    expect_message_test(
        name = name + "_dep_package_versions_message",
        size = "small",
        target_under_test = dependent_package,
        expected = [
            ":dependent gets popili %s (the default), but the popili_versions of its dep " % _STABLE,
            ":listing do not list it: %s. Make the popili_versions of " % OLDER_VERSION,
        ],
    )
    forced_pin_ignored_test(
        name = name + "_forced_package_versions_warns",
        size = "small",
        target_under_test = listing_package_consumer,
    )

    # Both read the package's typecheck script, so it must keep typecheck = True.
    self_pin_test(
        name = name + "_self_pin",
        size = "small",
        target_under_test = listing_package,
    )
    forced_pin_ignored_test(
        name = name + "_forced_self_pin_off",
        size = "small",
        target_under_test = listing_package,
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
        "_package_versions_message",
        "_dep_package_versions_message",
        "_forced_package_versions_warns",
        "_self_pin",
        "_forced_self_pin_off",
        "_alias_flag_message_current_popili_version",
    ]]
    native.test_suite(name = name, tests = tests)
