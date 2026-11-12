# Copyright 2019 Cocotec Limited
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Core Coco package rules and providers."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:shell.bzl", "shell")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load(":common_attrs.bzl", "companion_attrs")
load(":source_roots.bzl", "leaves_directory", "relative_path", "resolve_source_roots", "source_root_for")
load(":version_registry.bzl", "CocoVersionRegistryInfo")
load(":version_resolution.bzl", "FORCE_VERSION_FLAG", "LOCAL_VERSION", "TOOLCHAIN_TYPE", "VERSION_FLAG", "license_protocol_version", "resolve_version_alias")

CocoPackageInfo = provider(
    doc = "Information about a Coco package",
    fields = {
        "dep_package_files": "All Coco.toml files for all transitive dependencies",
        "direct_srcs": "The .coco files that are direct sources of this package only",
        "direct_test_srcs": "The .coco files that are direct test_sources of this package only",
        "generators": "The package's generator settings, mirroring `[generator.<language>]` in Coco.toml: a dict " +
                      "from \"cpp\", \"c\" and \"csharp\" to a struct of that language's coco_package attributes, " +
                      "with the CocoPackageInfo of each regenerated package in `regenerate_packages`",
        "name": "The name of the package",
        "package_file": "The Coco.toml file for this package",
        "popili_versions": "The popili versions this package is compatible with, aliases resolved ([] when unconstrained)",
        "source_roots": "Directories relative to the Coco.toml directory that hold this package's sources (`sources` in Coco.toml)",
        "srcs": "All .coco files that are sources of this package or any of its transitive dependencies",
        "test_source_roots": "Directories relative to the Coco.toml directory that hold this package's test sources (`testSources` in Coco.toml)",
        "test_srcs": "All .coco files that are test_sources of this package or any of its transitive dependencies",
        "typecheck_marker": "Marker file indicating typecheck passed (or None if typecheck disabled)",
        "workspace_files": "Coco.toml files for any enclosing workspaces of this package or its transitive dependencies",
    },
)

CocoWorkspaceInfo = provider(
    doc = "Information about a Coco workspace root whose shared settings flow down to member packages",
    fields = {
        "files": "Coco.toml files a member must ship: this workspace's root manifest plus any parent workspaces",
        "popili_versions": "The popili versions every member package is claimed to work with, aliases resolved, the parent's when this workspace sets none; [] when unconstrained",
    },
)

CocoCcGeneratedInfo = provider(
    doc = "Generated C/C++ code from a Coco package",
    fields = {
        "headers": "Generated header files as a depset",
        "include_root": "The directory the generated files' include paths are relative to, as an exec path",
        "popili_version": "The version of the popili that generated the code, as its toolchain declares it",
        "sources": "Generated implementation files as a depset",
        "test_headers": "Generated test/mock header files as a depset",
        "test_sources": "Generated test/mock implementation files as a depset",
    },
)

CocoCSharpGeneratedInfo = provider(
    doc = "Generated C# code from a Coco package",
    fields = {
        "sources": "Generated .cs files as a depset",
        "test_sources": "Generated test/mock .cs files as a depset",
    },
)

LICENSE_ATTRIBUTES = {
    "_auth_token_path": attr.label(default = Label("//:auth_token_path")),
    "_license_file_fetch": attr.label(default = Label("@io_cocotec_licensing_fetch//:licenses")),
    # Every licenses_<n>.lic found locally; see _local_user_license_file.
    "_license_files_local": attr.label(default = Label("@io_cocotec_licensing_local//:licenses")),
    "_license_source": attr.label(default = Label("//:license_source")),
    "_license_token": attr.label(default = Label("//:license_token")),
}

COCO_TOOLCHAIN_TYPE_LABEL = TOOLCHAIN_TYPE

# Optional only so that `_coco_toolchain` can replace Bazel's generic "No matching toolchains
# found" with a message naming the version and the registered ones; every rule declaring it still
# needs a Coco toolchain.
COCO_TOOLCHAIN_TYPE = config_common.toolchain_type(COCO_TOOLCHAIN_TYPE_LABEL, mandatory = False)

_DEFAULT_TEST_TOOLCHAIN_TYPE = "@bazel_tools//tools/test:default_test_toolchain_type"

# Whether Bazel keeps a test on an execution platform matching its target platform (Bazel 9+), through
# the default test toolchain type. WORKSPACE mode gets @bazel_features from Bazel 8's WORKSPACE suffix,
# which may predate the flag, hence getattr.
TESTS_FOLLOW_TARGET_PLATFORM = getattr(bazel_features.toolchains, "has_default_test_toolchain_type", False)

# rule() kwargs for test rules: on Bazel 9+ resolve popili on the `test` exec group, where the test action runs,
# alongside the (optional) default test toolchain type; on Bazel 8 the implicit group already copies the rule's toolchains.
# The `platform` fragment comes along because `_coco_toolchain` reads it to name the test's target platform.
COCO_TEST_RULE_ARGS = {
    "exec_groups": {"test": exec_group(toolchains = [
        COCO_TOOLCHAIN_TYPE,
        config_common.toolchain_type(_DEFAULT_TEST_TOOLCHAIN_TYPE, mandatory = False),
    ])},
    "fragments": ["platform"],
} if TESTS_FOLLOW_TARGET_PLATFORM else {
    "toolchains": [COCO_TOOLCHAIN_TYPE],
}

# rule() kwargs for executable rules, which `bazel run` executes on the host: on Bazel 9+ the (optional)
# default test toolchain type makes the default exec group prefer an execution platform matching the
# target platform (the host, for a plain `bazel run`) over the first one with popili; Bazel 8 has no
# such type, so there the rule's actions are constrained to the host's OS and CPU instead.
COCO_RUN_RULE_ARGS = {
    "toolchains": [
        COCO_TOOLCHAIN_TYPE,
        config_common.toolchain_type(_DEFAULT_TEST_TOOLCHAIN_TYPE, mandatory = False),
    ],
} if TESTS_FOLLOW_TARGET_PLATFORM else {
    "exec_compatible_with": HOST_CONSTRAINTS,
    "toolchains": [COCO_TOOLCHAIN_TYPE],
}

# What a rule needs for `_coco_toolchain`'s full message: the configured version and the registry.
TOOLCHAIN_ATTRIBUTES = {
    "_force_version": attr.label(default = Label("//:force_version")),
    "_pinned_from": attr.label(default = Label("//coco/private:pinned_from")),
    "_version": attr.label(default = Label("//:version")),
    "_version_registry": attr.label(
        default = Label("@coco_toolchains//:registry"),
        providers = [CocoVersionRegistryInfo],
    ),
}

POPILI_VERSION_ATTRIBUTES = {
    "popili_version": attr.string(
        doc = "The registered popili version this target and everything beneath it, including the " +
              "coco_package it reads, run with: a version such as `\"1.5.1\"` or an alias such as " +
              "`\"stable\"`. It wins over `--@rules_coco//:version`, unless `--@rules_coco//:force_version` " +
              "is set, which ignores every pin. Empty (the default) uses the version that flag selects, or " +
              "the first registered version when the flag is unset too.",
    ),
}

# What the hub registered, as a build setting so that transitions can read it.
_REGISTERED_VERSIONS_SETTING = str(Label("@coco_toolchains//:registered_versions"))

def _effective_version(version, registered_versions):
    """The popili version a configuration effectively asks for.

    Pure, so that other transitions, such as a package's self-pin, and the diagnostics that name
    the default can share it.

    Args:
        version: The value of `--@rules_coco//:version` in the configuration.
        registered_versions: The hub's registered versions in registration order.

    Returns:
        The flag when it is set, else the default (the first registered version unless that is
        `local`, which is never the default), else "".
    """
    if version:
        return version
    if registered_versions and registered_versions[0] != LOCAL_VERSION:
        return registered_versions[0]
    return ""

# The value `--@rules_coco//:version` had outside any pin, as a one-element list inside a pin and
# empty outside one; only the pin transition sets it. It lets the runtime's extra deps go back to
# the configuration of unpinned targets, so a binary that also links them gets one copy, and
# messages tell a version set by a pin above a target from one set on the command line.
_PINNED_FROM_SETTING = str(Label("//coco/private:pinned_from"))

def _pin_transition_settings(pin, version, registered_versions, forced = False, pinned_from = []):
    """Decides what a popili-resolving rule's transition changes.

    Args:
        pin: The target's `popili_version`, "" when unpinned or the rule has none.
        version: The value of `--@rules_coco//:version` in the incoming configuration.
        registered_versions: The hub's registered versions in registration order.
        forced: The value of `--@rules_coco//:force_version` in the incoming configuration.
        pinned_from: The incoming `pinned_from` setting: `[outer version]` inside a pin, else `[]`.

    Returns:
        The dict the transition returns: `{}` when forced (every pin is ignored and the build is
        analysed in the command line's configuration), without a pin, or when the pin (aliases
        resolved) is the version the incoming configuration effectively asks for, so the
        configuration and its output paths are shared; the configuration outside any pin when
        the pin is the version that one effectively asks for; else the version flag set to the
        resolved pin, recording the version outside any pin.
    """
    if forced or not pin:
        return {}
    resolved = resolve_version_alias(pin)
    if resolved == _effective_version(version, registered_versions):
        return {}
    outer = pinned_from[0] if pinned_from else version
    if resolved == _effective_version(outer, registered_versions):
        return {VERSION_FLAG: outer, _PINNED_FROM_SETTING: []}
    return {VERSION_FLAG: resolved, _PINNED_FROM_SETTING: [outer]}

def _popili_version_pin_impl(settings, attr):
    return _pin_transition_settings(
        getattr(attr, "popili_version", ""),
        settings[VERSION_FLAG],
        settings[_REGISTERED_VERSIONS_SETTING],
        settings[FORCE_VERSION_FLAG],
        pinned_from = settings[_PINNED_FROM_SETTING],
    )

popili_version_pin = transition(
    implementation = _popili_version_pin_impl,
    inputs = [VERSION_FLAG, FORCE_VERSION_FLAG, _REGISTERED_VERSIONS_SETTING, _PINNED_FROM_SETTING],
    outputs = [VERSION_FLAG, _PINNED_FROM_SETTING],
)

def _satisfies_popili_versions(version, versions):
    """Whether a toolchain declaring `version` satisfies a package's `popili_versions` (aliases resolved).

    An empty list is unconstrained; the local toolchain satisfies a list only when it names `local`.
    """
    return not versions or version in versions

def _first_registered(versions, registered_versions):
    """The first of `versions` (aliases resolved) that is a registered release, else None.

    `local` is skipped: like the default, a package's own transition never picks the local popili,
    which only runs on the host; it is only ever selected explicitly.
    """
    for version in versions:
        if version != LOCAL_VERSION and version in registered_versions:
            return version
    return None

def _package_transition_settings(versions, version, registered_versions, forced = False, pinned_from = []):
    """Decides what a coco_package's own transition changes, so that it is analysed with a version it lists.

    Args:
        versions: The package's `popili_versions` as written, aliases allowed.
        version: The value of `--@rules_coco//:version` in the incoming configuration.
        registered_versions: The hub's registered versions in registration order.
        forced: The value of `--@rules_coco//:force_version` in the incoming configuration.
        pinned_from: The incoming `pinned_from` setting: `[outer version]` inside a pin, else `[]`.

    Returns:
        The dict the transition returns: `{}` when forced (the self-pin is off), when the list is
        empty, when the flag is an alias (the package then fails saying so, like every target),
        when the version the incoming configuration effectively asks for satisfies the list, or
        when no listed release is registered (the package then fails saying so); else what a pin
        to the first registered listed release returns, never `local`, so that the standalone
        build and a consumer pinned to that version analyse the package once.
    """
    if forced or not versions or resolve_version_alias(version) != version:
        return {}
    resolved = [resolve_version_alias(listed) for listed in versions]
    if _satisfies_popili_versions(_effective_version(version, registered_versions), resolved):
        return {}
    first = _first_registered(resolved, registered_versions)
    if not first:
        return {}
    return _pin_transition_settings(first, version, registered_versions, pinned_from = pinned_from)

def _package_self_pin_impl(settings, attr):
    return _package_transition_settings(
        attr.popili_versions,
        settings[VERSION_FLAG],
        settings[_REGISTERED_VERSIONS_SETTING],
        settings[FORCE_VERSION_FLAG],
        pinned_from = settings[_PINNED_FROM_SETTING],
    )

# Analyses a coco_package with a version its popili_versions list, when the configuration's is not.
_package_self_pin = transition(
    implementation = _package_self_pin_impl,
    inputs = [VERSION_FLAG, FORCE_VERSION_FLAG, _REGISTERED_VERSIONS_SETTING, _PINNED_FROM_SETTING],
    outputs = [VERSION_FLAG, _PINNED_FROM_SETTING],
)

def _unpin_transition_settings(version, pinned_from):
    """The settings of the configuration outside any pin, given a configuration's.

    Args:
        version: The value of `--@rules_coco//:version` in the incoming configuration.
        pinned_from: The incoming `pinned_from` setting.

    Returns:
        The dict the transition returns: the version outside any pin and no record of a pin.
    """
    return {VERSION_FLAG: pinned_from[0] if pinned_from else version, _PINNED_FROM_SETTING: []}

def _popili_version_unpin_impl(settings, _attr):
    return _unpin_transition_settings(settings[VERSION_FLAG], settings[_PINNED_FROM_SETTING])

# For what a pinned target builds but popili does not affect, such as the runtime's extra deps:
# analysed where unpinned targets are, so it is built once however many versions are pinned.
popili_version_unpin = transition(
    implementation = _popili_version_unpin_impl,
    inputs = [VERSION_FLAG, _PINNED_FROM_SETTING],
    outputs = [VERSION_FLAG, _PINNED_FROM_SETTING],
)

# License files are now obtained from the toolchain, not passed as attributes

def _resolves_on_test_exec_group(ctx):
    # Every test rule has a `test` exec group, so ask whether it carries the Coco toolchain type: a
    # group declared with COCO_TEST_RULE_ARGS does, and so does Bazel 8's implicit one, which copies
    # the rule's toolchains.
    return "test" in ctx.exec_groups and COCO_TOOLCHAIN_TYPE_LABEL in ctx.exec_groups["test"].toolchains

def _resolved_coco_toolchain(ctx):
    """Returns the resolved Coco toolchain, failing with a specific message when there is none."""
    if _resolves_on_test_exec_group(ctx):
        toolchain = ctx.exec_groups["test"].toolchains[COCO_TOOLCHAIN_TYPE_LABEL]
    else:
        toolchain = ctx.toolchains[COCO_TOOLCHAIN_TYPE_LABEL]
    if toolchain == None:
        fail(_missing_toolchain_message(ctx))
    return toolchain

def _coco_toolchain(ctx):
    """Returns the resolved Coco toolchain.

    Fails with a specific message when there is none, or when the toolchain declares another popili
    version than the target asks for, which only a bring-your-own toolchain can do.
    """
    toolchain = _resolved_coco_toolchain(ctx)
    conflict = _toolchain_version_conflict(ctx, toolchain)
    if conflict:
        fail(conflict)
    return toolchain

def _version_source(version, pin, pinned_from = None, forced = False, self_pin = False):
    """Words where a target's configured popili version came from.

    A target without a pin of its own tells the flag on the command line from a pin on a target
    above it by `pinned_from`, which only a pin sets. A custom rule without that attribute cannot
    tell them apart, so the phrase then names both.

    Args:
        version: The value of `--@rules_coco//:version` in the target's configuration.
        pin: The target's `popili_version`, "" when it has none.
        pinned_from: The `pinned_from` setting in the target's configuration, or None when the
            rule cannot read it.
        forced: The value of `--@rules_coco//:force_version` in the target's configuration.
        self_pin: Whether the target is a coco_package whose own transition may have pinned it to
            this version, which it does like a target above it would; the two cannot be told apart.

    Returns:
        A phrase interpolated as "(%s)" in messages: "forced by --@rules_coco//:force_version"
        (with "the default, " in front when the version flag is empty), "pinned by popili_version"
        (naming the pin as written when it is an alias), "pinned by a target above it" (or "pinned
        by its popili_versions or a target above it" with `self_pin`), "set by
        --@rules_coco//:version", "set by --@rules_coco//:version or a popili_version pin above
        it" when `pinned_from` is unknown, or "the default".
    """
    if forced:
        if version:
            return "forced by --%s" % FORCE_VERSION_FLAG
        return "the default, forced by --%s" % FORCE_VERSION_FLAG
    if pin:
        if pin == version:
            return "pinned by popili_version"
        return "pinned by popili_version = %r" % pin
    if pinned_from:
        if self_pin:
            return "pinned by its popili_versions or a target above it"
        return "pinned by a target above it"
    if version:
        if pinned_from == None:
            return "set by --%s or a popili_version pin above it" % VERSION_FLAG
        return "set by --%s" % VERSION_FLAG
    return "the default"

def _version_source_of(ctx, self_pin = False):
    """Where this target's configured popili version came from, as `_version_source` words it.

    Reads what a rule with TOOLCHAIN_ATTRIBUTES has; a custom rule may lack `_pinned_from` and
    `_force_version`. `self_pin` is for a coco_package whose own transition may have pinned it to
    this version.
    """
    pinned_from = getattr(ctx.attr, "_pinned_from", None)
    force = getattr(ctx.attr, "_force_version", None)
    return _version_source(
        ctx.attr._version[BuildSettingInfo].value,
        getattr(ctx.attr, "popili_version", ""),
        pinned_from[BuildSettingInfo].value if pinned_from else None,
        force[BuildSettingInfo].value if force else False,
        self_pin = self_pin,
    )

def _describe_registered_versions(registry):
    if not registry.versions:
        return "none"
    default = _effective_version("", registry.versions)
    described = []
    for version in registry.versions:
        if version == default:
            described.append("%s (the default)" % version)
        else:
            described.append(version)
    return ", ".join(described)

def _register_versions_phrase(what):
    return (
        "register %s with coco.toolchain(versions = [...]) in MODULE.bazel or " % what +
        "coco_repositories(versions = [...]) in WORKSPACE"
    )

def _sentence(phrase):
    """Capitalises a phrase and ends it with a full stop."""
    return phrase[0].upper() + phrase[1:] + "."

def _register_versions_hint(what):
    return _sentence(_register_versions_phrase(what))

_REGISTER_LOCAL_PHRASE = (
    "register a popili distribution from the local filesystem with coco.local_toolchain(popili = ...) " +
    "in MODULE.bazel or coco_local_repositories(path = ...) / coco_repositories(local_popili = ...) in WORKSPACE"
)

_REGISTER_LOCAL_HINT = _sentence(_REGISTER_LOCAL_PHRASE)

def _missing_popili_message(label, version, registry, source = None, test_target_platform = None):
    """Words the failure of a rule whose Coco toolchain did not resolve.

    Decided after toolchain resolution, so it never second-guesses resolution: the registry is
    consulted only to say what is registered and what to do about it.

    Args:
        label: The failing target's label.
        version: The value of `--@rules_coco//:version` in the target's configuration, "" for
            the default.
        registry: The hub's `CocoVersionRegistryInfo` (or any struct with its fields).
        source: Where the version came from, as `_version_source` words it; None words a set
            version as set by the flag.
        test_target_platform: For a test that lost popili to the execution platform Bazel runs
            tests on, its target platform, as `_test_target_platform` returns it; else None.

    Returns:
        The message to fail with.
    """
    if source == None:
        source = _version_source(version, "", [])
    registered = "Registered popili versions: %s." % _describe_registered_versions(registry)

    if version == LOCAL_VERSION:
        if LOCAL_VERSION not in registry.versions:
            return (
                "%s needs the local popili (%s), but no local Coco toolchain is registered. %s %s" %
                (label, source, registered, _REGISTER_LOCAL_HINT)
            )
        if test_target_platform:
            return (
                "%s needs the local popili (%s), which only runs on the host, but Bazel runs a test on an " %
                (label, source) +
                "execution platform matching the test's target platform (%s), and no registered " % test_target_platform +
                "execution platform both matches it and is the host. Build the test for the host " +
                "(--platforms=@platforms//host), with the host registered as an execution platform " +
                "(--extra_execution_platforms=@platforms//host), or select a published release. %s" % registered
            )
        return (
            "%s needs the local popili (%s), but it only runs on the host and no registered execution " %
            (label, source) +
            "platform is the host. Register the host as an execution platform " +
            "(--extra_execution_platforms=@platforms//host), or select a published release. %s" % registered
        )

    if not version:
        version = _effective_version("", registry.versions)
        if not version:
            return (
                "%s needs the default popili version, but none is registered: the local popili never " % label +
                "becomes the default and is selected only with --%s=%s. %s %s" %
                (VERSION_FLAG, LOCAL_VERSION, registered, _register_versions_hint("a version"))
            )

    # The hub's config_settings match version numbers only; transitions resolve aliases, the flag does not.
    resolved = resolve_version_alias(version)
    if resolved != version:
        return (
            "%s needs popili %s (%s), but %s is an alias, which --%s does not resolve: set it to %s, " %
            (label, version, source, version, VERSION_FLAG, resolved) +
            "the version it stands for. %s" % registered +
            ("" if resolved in registry.versions else " " + _register_versions_hint(resolved))
        )

    if version not in registry.versions:
        return (
            "%s needs popili %s (%s), but no registered Coco toolchain provides it. %s %s" %
            (label, version, source, registered, _register_versions_hint("it"))
        )

    if test_target_platform:
        return (
            "%s needs popili %s (%s), which is registered, but Bazel runs a test on an execution platform " %
            (label, version, source) +
            "matching the test's target platform (%s), and no registered execution platform both " % test_target_platform +
            "matches it and can run popili. Build the test for a platform popili is available for, register " +
            "a matching execution platform popili is available for (--extra_execution_platforms), or bring " +
            "your own coco_toolchain for such a platform. %s" % registered
        )

    return (
        "%s needs popili %s (%s), which is registered, but none of the registered execution platforms " %
        (label, version, source) +
        "can run it. Register an execution platform popili is available for (--extra_execution_platforms), " +
        "or bring your own coco_toolchain for the execution platform you have. %s" % registered
    )

def _test_target_platform(ctx):
    """The target platform of a test that lost popili to Bazel's choice of test platform, else None.

    The `test` exec group takes the execution platform resolving the most of its toolchains, so a
    resolved default test toolchain without a Coco toolchain means that no execution platform the
    test may run on (by default, those matching its target platform) can run popili.
    """
    if not _resolves_on_test_exec_group(ctx) or not TESTS_FOLLOW_TARGET_PLATFORM:
        return None
    if ctx.exec_groups["test"].toolchains[_DEFAULT_TEST_TOOLCHAIN_TYPE] == None:
        return None
    return str(ctx.fragments.platform.platform)

def _missing_toolchain_message(ctx):
    # A custom rule may declare COCO_TOOLCHAIN_TYPE without TOOLCHAIN_ATTRIBUTES, which the full message needs.
    if not hasattr(ctx.attr, "_version_registry"):
        return (
            "%s needs a Coco toolchain, but no toolchain of type %s resolved. " %
            (ctx.label, COCO_TOOLCHAIN_TYPE_LABEL) +
            "Only rules_coco's own rules choose the version with popili_version and say which " +
            "versions are registered."
        )
    return _missing_popili_message(
        ctx.label,
        ctx.attr._version[BuildSettingInfo].value,
        ctx.attr._version_registry[CocoVersionRegistryInfo],
        source = _version_source_of(ctx),
        test_target_platform = _test_target_platform(ctx),
    )

def _requested_version(pin, version, forced = False):
    """The popili version a target asks for by name, "" when it asks for none in particular.

    Args:
        pin: The target's `popili_version`, "" when unpinned or the rule has none.
        version: The value of `--@rules_coco//:version` in the target's configuration.
        forced: The value of `--@rules_coco//:force_version` in the target's configuration.

    Returns:
        The pin with aliases resolved, unless forced, which ignores every pin; else the flag, which
        a pin above the target set when it is not the command line's; "" when neither names a
        version and the target takes the default, whatever toolchain provides it.
    """
    if pin and not forced:
        return resolve_version_alias(pin)
    return version

def _describe_popili(version):
    """Words a popili version in a message: "the local popili" or "popili <version>"."""
    return "the local popili" if version == LOCAL_VERSION else "popili %s" % version

def _toolchain_version_mismatch_message(label, version, source, toolchain_label, toolchain_version):
    """Words the failure of a rule whose resolved Coco toolchain is another popili version than it asked for.

    Only a bring-your-own toolchain gets here: the hub's toolchain() entries carry target_settings
    on the version flag, so each resolves for its own version only, whereas a bring-your-own one,
    registered without target_settings as docs/toolchains.md shows, serves every target.

    Args:
        label: The failing target's label.
        version: The popili version the target asked for by name, as `_requested_version` returns it.
        source: Where that version came from, as `_version_source` words it.
        toolchain_label: The label of the resolved `coco_toolchain`.
        toolchain_version: The `popili_version` the resolved toolchain declares.

    Returns:
        The message to fail with.
    """
    return (
        "%s needs %s (%s), but the bring-your-own coco_toolchain %s, which serves every target, is popili %s. " %
        (label, _describe_popili(version), source, toolchain_label, toolchain_version) +
        "With a bring-your-own toolchain, popili_version pins and --%s must name %s or be left out." %
        (VERSION_FLAG, toolchain_version)
    )

def _toolchain_version_conflict(ctx, toolchain, source = None):
    """The message a target fails with when its toolchain is another popili version than it asked for, else None.

    A target asking for no version in particular takes whatever toolchain resolves. A coco_package
    is no exception, whatever its `popili_versions` list: the flag and pins name a version as they
    do for every target. A custom rule declaring COCO_TOOLCHAIN_TYPE without TOOLCHAIN_ATTRIBUTES
    cannot be checked, and one without `_force_version` is checked as unforced. `source` words
    where the version came from, `_version_source_of(ctx)` when None.
    """
    if not hasattr(ctx.attr, "_version_registry"):
        return None
    force = getattr(ctx.attr, "_force_version", None)
    requested = _requested_version(
        getattr(ctx.attr, "popili_version", ""),
        ctx.attr._version[BuildSettingInfo].value,
        force[BuildSettingInfo].value if force else False,
    )
    if not requested or requested == toolchain.popili_version:
        return None
    return _toolchain_version_mismatch_message(
        ctx.label,
        requested,
        source or _version_source_of(ctx),
        toolchain.label,
        toolchain.popili_version,
    )

def _or_list(phrases):
    """Joins remedies as "a, b, or c", capitalised and ending in a full stop."""
    return _sentence(phrases[0] if len(phrases) == 1 else ", ".join(phrases[:-1]) + ", or " + phrases[-1])

def _package_versions_conflict(label, version, source, package, versions, forced = False, of_dep = False, pinned_above = False, common = None):
    """The message a target fails with when it runs a popili version a coco_package does not list in popili_versions, else None.

    An empty list is unconstrained. Matching is exact: aliases are resolved when the list is read off
    the attribute, and the local toolchain satisfies a list only when it names `local`. A package's
    own list is checked by `_own_package_versions_message`.

    Args:
        label: The failing target's label.
        version: The popili version the resolved toolchain declares.
        source: Where the target's configured version came from, as `_version_source` words it.
        package: The label of the coco_package whose list is checked: one the target reads, or a
            direct dep of one.
        versions: That package's `popili_versions`, aliases resolved.
        forced: The value of `--@rules_coco//:force_version` in the target's configuration; the
            message then names no remedy, since the caller only warns.
        of_dep: Whether `label` is a coco_package and `package` one of its direct deps.
        pinned_above: Whether a `popili_version` pin on a target above `label` set the version, so
            that a pin on `label` itself would part it from that target.
        common: With `of_dep`, a registered release that `label`'s own list and every list of its
            deps name, which it could build with instead; else None.

    Returns:
        The message to fail with, or None when the version is listed.
    """
    if _satisfies_popili_versions(version, versions):
        return None
    listed = ", ".join(versions)
    runs = _describe_popili(version)
    add = "add %s to the popili_versions of %s" % (version, package)
    if of_dep:
        head = "%s gets %s (%s), but the popili_versions of its dep %s do not list it: %s." % (label, runs, source, package, listed)
        if common:
            # The package lists `version`, so its own transition left it: reordering the list alone
            # changes nothing unless `version` leaves it too, whatever selected `version`.
            remedies = [
                "build %s with %s, which its popili_versions and those of its deps all list, " % (label, common) +
                "by listing it first and leaving %s out of its popili_versions, or by selecting it with a pin above it or --%s" % (version, VERSION_FLAG),
                add,
            ]
        else:
            remedies = ["make the popili_versions of %s list only versions %s lists too" % (label, package), add]
    else:
        head = "%s runs %s (%s) on %s, whose popili_versions do not list it: %s." % (label, runs, source, package, listed)
        if pinned_above:
            remedies = ["change the popili_version pin above %s to one of those" % label, add]
        else:
            remedies = ["pin %s to one of those with popili_version" % label, add]
    return head if forced else head + " " + _or_list(remedies)

def _inherited_versions_conflict(label, versions, inherited, inherited_label, relation):
    """The message a coco_package or coco_workspace fails with when its own popili_versions leave out a version its workspace claims, else None.

    Args:
        label: The target's label.
        versions: Its own `popili_versions`, aliases resolved; `[]` inherits and never conflicts.
        inherited: The effective `popili_versions` of its workspace or parent, aliases resolved.
        inherited_label: That workspace's label.
        relation: The edge the list comes down, for the message: "workspace" or "parent".
    """
    missing = [version for version in inherited if version not in versions]
    if not versions or not missing:
        return None
    return (
        "%s's popili_versions (%s) leave out %s, which its %s %s claims for every member package: %s. " +
        "A member may support more versions than its workspace, never fewer: add the missing ones, " +
        "sharing the list through a .bzl constant, or drop popili_versions to inherit them."
    ) % (label, ", ".join(versions), ", ".join(missing), relation, inherited_label, ", ".join(inherited))

def _own_package_versions_message(label, version, source, versions, effective, toolchain_label, registry, forced = False, inherited_from = None):
    """The message a coco_package gets when the toolchain it resolved is not in its own popili_versions, else None.

    Unforced, its transition gave it a listed release whenever one is registered, so only three
    causes remain: a bring-your-own toolchain, which serves every target, is another version than
    the configuration asks for, or one no hub registered; no listed release is registered, `local`
    aside, which the transition never picks; or the list is inherited from its workspace, which its
    transition cannot see.

    Args:
        label: The package's label.
        version: The popili version the resolved toolchain declares.
        source: Where the package's configured version came from, as `_version_source` words it.
        versions: The package's `popili_versions`, aliases resolved.
        effective: The version its configuration effectively asks for, as `_effective_version`
            gives it.
        toolchain_label: The resolved toolchain's label.
        registry: The hub's `CocoVersionRegistryInfo`.
        forced: The value of `--@rules_coco//:force_version` in the package's configuration; the
            message then names no remedy, since the package only warns.
        inherited_from: The label of the workspace `versions` are inherited from, None when they
            are the package's own.

    Returns:
        The message to fail with (or, forced, to warn with), or None when the version is listed.
    """
    if _satisfies_popili_versions(version, versions):
        return None
    listed = ", ".join(versions)
    runs = _describe_popili(version)

    # Every cause names the list where it is written, which is where a version is added.
    if inherited_from:
        its_list = "the popili_versions it inherits from its workspace %s" % inherited_from
        the_list = "the popili_versions %s inherits from its workspace %s" % (label, inherited_from)
    else:
        its_list = "its popili_versions"
        the_list = "%s's popili_versions" % label
    head = "%s gets %s (%s), which %s do not list: %s." % (label, runs, source, its_list, listed)
    if forced:
        return head

    # A hub toolchain is always the version asked for, and a registered one.
    if version != effective or version not in registry.versions:
        return (
            "%s gets %s from the bring-your-own coco_toolchain %s, which serves every target, but %s " % (label, runs, toolchain_label, its_list) +
            "do not list it: %s. Add %s to %s, or bring a toolchain of one of those versions." %
            (listed, version, its_list)
        )
    if not _first_registered(versions, registry.versions):
        releases = [listed_version for listed_version in versions if listed_version != LOCAL_VERSION]
        remedies = []
        if LOCAL_VERSION in versions and LOCAL_VERSION in registry.versions:
            what = "No release among %s (%s) is registered, and the local popili is only ever selected explicitly" % (the_list, listed)
            remedies.append("select the local popili with --%s=%s or a popili_version pin above it" % (VERSION_FLAG, LOCAL_VERSION))
        else:
            what = "None of %s (%s) is registered" % (the_list, listed)
        remedies.append("add %s to %s" % (version, its_list))
        if releases:
            remedies.append(_register_versions_phrase("one of %s" % ", ".join(releases)))
        if LOCAL_VERSION in versions and LOCAL_VERSION not in registry.versions:
            remedies.append(_REGISTER_LOCAL_PHRASE + " and select it with --%s=%s" % (VERSION_FLAG, LOCAL_VERSION))
        return (
            "%s, so it gets %s (%s), which it does not list. Registered popili versions: %s. " %
            (what, runs, source, _describe_registered_versions(registry)) + _or_list(remedies)
        )
    if inherited_from:
        return (
            head + " Build it beneath a target pinned to one of those, set --%s to one, or write the list on " % VERSION_FLAG +
            "the package itself, which then builds with the first registered one."
        )

    # Not reached: its transition gave it a listed version.
    return head

def _common_version(versions, dep_lists, registered_versions):
    """The first registered release in `versions` that every list in `dep_lists` names, else None.

    Args:
        versions: A coco_package's own `popili_versions`, aliases resolved.
        dep_lists: Its direct deps' `popili_versions`, aliases resolved.
        registered_versions: The hub's registered versions.
    """
    for candidate in versions:
        if candidate != LOCAL_VERSION and candidate in registered_versions and all([
            _satisfies_popili_versions(candidate, dep_versions)
            for dep_versions in dep_lists
        ]):
            return candidate
    return None

def _report_package_versions_conflicts(ctx, toolchain, lists, of_dep = False, source = None, own_versions = None, registry = None):
    """Fails when `toolchain` is not in one of `lists`; under --@rules_coco//:force_version it warns instead.

    Args:
        ctx: The rule context.
        toolchain: The resolved Coco toolchain.
        lists: (package label, popili_versions) pairs: the packages a target reads, or a
            coco_package's direct deps.
        of_dep: Whether `ctx` is a coco_package and `lists` hold its direct deps'.
        source: Where the version came from, as `_version_source` words it; worked out from `ctx`
            when None and a list conflicts.
        own_versions: With `of_dep`, the package's own `popili_versions`, aliases resolved, so
            that a conflict can name a release it and every dep list; else None.
        registry: With `own_versions`, the hub's `CocoVersionRegistryInfo`.

    A custom rule without `_force_version` is checked as unforced, and one without `_version` has
    its version worded as configured.
    """
    force = getattr(ctx.attr, "_force_version", None)
    forced = force[BuildSettingInfo].value if force else False
    pinned_from = getattr(ctx.attr, "_pinned_from", None)
    pinned_above = bool(pinned_from and pinned_from[BuildSettingInfo].value) and not getattr(ctx.attr, "popili_version", "")
    common = None
    for package, versions in lists:
        if _satisfies_popili_versions(toolchain.popili_version, versions):
            continue
        if source == None:
            source = _version_source_of(ctx) if hasattr(ctx.attr, "_version") else "as configured"
        if own_versions and not common:
            common = _common_version(own_versions, [dep_versions for _, dep_versions in lists], registry.versions)
        conflict = _package_versions_conflict(
            ctx.label,
            toolchain.popili_version,
            source,
            package,
            versions,
            forced,
            of_dep,
            pinned_above = pinned_above,
            common = common,
        )
        if forced:
            print(conflict)  # buildifier: disable=print
        else:
            fail(conflict)

def _check_package_versions(ctx, packages):
    """Checks the popili this target runs against the `popili_versions` of the coco_packages it reads.

    Called once per popili-running rule. Their deps' lists need no check here: a package listing
    this version is analysed with it, as is one with no list, and has checked its deps' lists
    against it itself. The toolchain is resolved first, so that a missing toolchain fails with its
    own message even when `packages` is empty, and returned for the rule to use.
    """
    toolchain = _coco_toolchain(ctx)
    _report_package_versions_conflicts(
        ctx,
        toolchain,
        [(package.label, package[CocoPackageInfo].popili_versions) for package in packages],
    )
    return toolchain

def _runtime_path(file, is_test):
    return file.short_path if is_test else file.path

def _runtime_dirname(file, is_test):
    # File.dirname, but via the runtime path (short_path for tests) so
    # external-repo deps resolve in the runfiles tree; "." avoids an empty arg.
    return paths.dirname(_runtime_path(file, is_test)) or "."

def _package_info(package):
    """The CocoPackageInfo of a coco_package target, or `package` itself if it is a struct.

    The struct has CocoPackageInfo's fields: a coco_package's own, before it returns the provider.
    """
    return package if hasattr(package, "package_file") else package[CocoPackageInfo]

def _coco_startup_args(ctx, package, is_test):
    """Build startup arguments for popili.

    Args:
        ctx: Rule context
        package: The coco_package target, a struct with CocoPackageInfo's fields (see
                 `_package_info`), or None for base args only
        is_test: Whether this is for a test (affects path resolution)

    Returns:
        List of startup arguments
    """
    arguments = [
        "--no-license-server",
        "--no-crash-reporter",
        "--no-auto-download",
        "--override-preferences",
        _runtime_path(_coco_toolchain(ctx).preferences_file, is_test),
        "--terminal=plain",
    ]

    # Handle auth token file for action_file mode
    license_source = _get_license_source(ctx)
    if license_source == "action_file":
        auth_token_path = _get_auth_token_path(ctx)
        if auth_token_path:
            arguments.append("--machine-auth-token")
            arguments.append(auth_token_path)
    else:
        # Handle license file for other modes
        license_file = _get_license_file_from_toolchain(ctx)
        if license_file:
            arguments.append("--override-licenses")
            arguments.append(_runtime_path(license_file, is_test))
    if package:
        info = _package_info(package)
        arguments += [
            "--package",
            _runtime_dirname(info.package_file, is_test),
        ]
        for dep_file in info.dep_package_files.to_list():
            arguments += ["--import-path", _runtime_dirname(dep_file, is_test)]
    return arguments

def _get_license_source(ctx):
    cli_license_source = ctx.attr._license_source[BuildSettingInfo].value
    if cli_license_source:
        return cli_license_source
    toolchain_license_source = _coco_toolchain(ctx).license_source
    if toolchain_license_source:
        return toolchain_license_source
    return "local_user"

def _get_auth_token_path(ctx):
    """Get the auth token file path from CLI flag or toolchain.

    Returns the path string (not a File object) for use with action_file licensing mode.
    """
    cli_auth_token_path = ctx.attr._auth_token_path[BuildSettingInfo].value
    if cli_auth_token_path:
        return cli_auth_token_path
    toolchain_auth_token_path = _coco_toolchain(ctx).auth_token_path
    if toolchain_auth_token_path:
        return toolchain_auth_token_path
    return ""

def _get_license_file_from_toolchain(ctx):
    """Get the appropriate license file based on license_source.

    Reads license_source from the toolchain (repository default) with optional
    CLI override via --@rules_coco//:license_source flag.
    """

    # Even with the flag set, so a missing toolchain fails here rather than as an empty fetch.
    _coco_toolchain(ctx)
    license_source = _get_license_source(ctx)
    if license_source == "local_acquire":
        files = ctx.attr._license_file_fetch[DefaultInfo].files.to_list()
        return files[0] if files else None
    if license_source == "local_user":
        return _local_user_license_file(ctx)
    return None

def _local_user_license_file(ctx):
    """The user's licence file for the licence protocol version of the toolchain's popili.

    The toolchain's `license_protocol_version` when set, else the one its `popili_version`
    reads. The local toolchain, whose version is unknown, gets the file of the newest protocol
    version.
    """
    toolchain = _coco_toolchain(ctx)
    name = "licenses_%d.lic" % (toolchain.license_protocol_version or license_protocol_version(toolchain.popili_version))
    files = [
        file
        for file in ctx.attr._license_files_local[DefaultInfo].files.to_list()
        if file.basename == name
    ]
    return files[0] if files else None

# The `HOME` that build actions on a POSIX exec platform run popili with. Bazel starts actions with
# an empty environment, and popili before 1.5.2 crashes when `$HOME` is unset and the user is not
# in `/etc/passwd` (as in containers run with an arbitrary uid). popili needs nothing from its
# home directory here: the startup arguments name its preferences and licence explicitly.
_ACTION_HOME = "/nonexistent"

def _coco_env(ctx, for_action):
    """Returns the environment popili runs with.

    Args:
        ctx: The rule context.
        for_action: Whether popili runs in a build action, whose environment is otherwise empty,
            rather than in a test or `bazel run` script, which keeps its caller's `HOME`.
    """
    env = {}
    if for_action and not _is_windows(ctx):
        env["HOME"] = _ACTION_HOME

    license_source = _get_license_source(ctx)
    if license_source == "token":
        cli_license_token = ctx.attr._license_token[BuildSettingInfo].value
        toolchain_license_token = _coco_toolchain(ctx).license_token
        env["COCOTEC_AUTH_TOKEN"] = cli_license_token if cli_license_token else (toolchain_license_token if toolchain_license_token else "")

    return env

def _coco_runfiles(ctx, package, is_test):
    direct = [
        _coco_toolchain(ctx).preferences_file,
    ]
    transitive = []
    if is_test:
        direct.append(_coco_toolchain(ctx).coco)
    license_file = _get_license_file_from_toolchain(ctx)
    if license_file:
        direct.append(license_file)
    if package:
        info = _package_info(package)
        direct.append(info.package_file)
        transitive.append(info.srcs)
        transitive.append(info.test_srcs)
        transitive.append(info.dep_package_files)
        transitive.append(info.workspace_files)

        # Include typecheck marker if present to ensure codegen waits for typecheck
        if info.typecheck_marker:
            direct.append(info.typecheck_marker)
    return depset(
        direct = direct,
        transitive = transitive,
    )

def _run_coco(ctx, package, verb, mnemonic, arguments, outputs):
    ctx.actions.run(
        executable = _coco_toolchain(ctx).coco,
        tools = [
            _coco_toolchain(ctx).coco,
        ],
        env = _coco_env(ctx, for_action = True),
        mnemonic = mnemonic,
        progress_message = "%s %s" % (verb, package[CocoPackageInfo].name),
        inputs = _coco_runfiles(ctx, package, False),
        outputs = outputs,
        arguments = _coco_startup_args(ctx, package, False) + arguments,
    )

def _is_windows(ctx):
    """Returns True when the exec platform is Windows.

    The generated .bat/.sh scripts run the popili binary from the toolchain, which Bazel resolves
    for the exec platform, so the script flavour must follow that platform too. The target
    platform is irrelevant: `--platforms=//:windows` from a Linux host must still emit a .sh for
    the Linux executor. Starlark has no direct exec-platform API, and the toolchain target itself
    is analysed in the target configuration, so the binary is the signal: a Windows popili is
    `popili.exe` (cmd.exe needs the extension to run it), everything else is not.
    """
    return _coco_toolchain(ctx).coco.extension == "exe"

def _bat_set(name, value):
    """Returns a cmd.exe `SET` line that assigns `value` to `name` verbatim.

    Inside `SET "name=value"` cmd.exe only expands `%`, which `%%` escapes. A `"` or line break
    cannot be represented, so such values fail analysis instead of producing a broken script.
    """
    if "\"" in value or "\n" in value or "\r" in value:
        fail("Cannot pass %s to a Windows wrapper script: the value contains a double quote or line break" % name)
    return "SET \"%s=%s\"" % (name, value.replace("%", "%%"))

def _create_coco_wrapper_script(ctx, package, arguments, marker = None):
    """Creates a platform-specific wrapper script for running Coco commands.

    Args:
        ctx: The rule context
        package: The coco_package target, a struct as `_package_info` takes it, or None
        arguments: List of command arguments (after startup args)
        marker: None for a test or `bazel run` script, which finds popili and its inputs in its
            runfiles; else a file for a build action's script to create once popili succeeds,
            with popili and its inputs at their execution paths

    Returns:
        The wrapper script file
    """
    is_test = marker == None
    coco_path = _runtime_path(_coco_toolchain(ctx).coco, is_test)
    is_windows = _is_windows(ctx)
    if is_windows:
        coco_path = coco_path.replace("/", "\\")

    # Build the full command
    full_arguments = [coco_path] + _coco_startup_args(ctx, package, is_test) + arguments
    command = " ".join(full_arguments)
    env = _coco_env(ctx, for_action = not is_test)

    # Create platform-specific wrapper script
    if marker and is_windows:
        wrapper_script = ctx.actions.declare_file(ctx.label.name + "_typecheck.bat")
        wrapper_lines = ["@echo off"]
        for k, v in env.items():
            wrapper_lines.append(_bat_set(k, v))
        wrapper_lines.append("%s || exit /b 1" % command)
        wrapper_lines.append("type nul > \"%s\"" % marker.path.replace("/", "\\"))
    elif marker:
        wrapper_script = ctx.actions.declare_file(ctx.label.name + "_typecheck.sh")
        wrapper_lines = ["#!/bin/sh", "set -e"]
        for k, v in env.items():
            wrapper_lines.append("export %s=%s" % (k, shell.quote(v)))
        wrapper_lines.append("%s && : > \"%s\"" % (command, marker.path))
    elif is_windows:
        wrapper_script = ctx.actions.declare_file(ctx.label.name + "-cmd.bat")
        wrapper_lines = []
        for k, v in env.items():
            wrapper_lines.append(_bat_set(k, v))
        wrapper_lines.append("")
        wrapper_lines.append(command)
    else:
        wrapper_script = ctx.actions.declare_file(ctx.label.name + "-cmd.sh")
        wrapper_lines = [
            "#!/bin/sh",
            "exec env \\",
        ]
        for k, v in env.items():
            wrapper_lines.append("  %s=%s \\" % (k, shell.quote(v)))
        wrapper_lines.append(command)

    ctx.actions.write(
        output = wrapper_script,
        content = "\n".join(wrapper_lines),
        is_executable = True,
    )

    return wrapper_script

# Exported for the runtimes (cc_runtime.bzl, c_runtime.bzl), which resolve the toolchain without
# running popili. An implementation detail, not for end users; rules that run popili are built
# with popili_rule below instead.
coco_toolchain_or_fail = _coco_toolchain

def _run_typecheck(ctx, package):
    """Run typecheck and produce a marker file on success.

    Args:
        ctx: Rule context
        package: A struct with CocoPackageInfo's fields, as `_package_info` takes it

    Returns:
        The typecheck marker file
    """
    marker = ctx.actions.declare_file(ctx.label.name + ".typecheck")
    script = _create_coco_wrapper_script(ctx, package, ["typecheck"], marker = marker)
    ctx.actions.run(
        executable = script,
        tools = [_coco_toolchain(ctx).coco, script],
        mnemonic = "CocoTypecheck",
        progress_message = "Typechecking %s" % ctx.label.name,
        inputs = _coco_runfiles(ctx, package, False),
        outputs = [marker],
    )
    return marker

def _require_coco_toml(file, attr):
    if file.basename != "Coco.toml":
        fail("%s must point to a file called exactly 'Coco.toml'" % attr.capitalize(), attr = attr)

def _include_prefix(ctx, attr_name):
    """A validated include prefix attribute: the package's effective includePrefix, "" by default."""
    prefix = getattr(ctx.attr, attr_name)
    if prefix and (prefix == "." or paths.normalize(prefix) != prefix or paths.is_absolute(prefix) or leaves_directory(prefix)):
        fail("%s must be a normalised relative path within the include root, such as \"my/pkg\", " % attr_name +
             "not \"%s\"" % prefix, attr = attr_name)
    return prefix

def _regenerate_packages(ctx, attr_name, dep_package_files):
    """The CocoPackageInfo of each package in a *_regenerate_packages attribute.

    Each must be among the package's transitive deps, as popili regenerates only dependencies: so
    their sources are already inputs of the package's generate actions, and depending on them adds
    no testonly or visibility constraint that the deps do not.
    """
    infos = []
    for regen in getattr(ctx.attr, attr_name):
        info = regen[CocoPackageInfo]
        if info.package_file not in dep_package_files:
            fail("%s is not a dependency of %s: list it in deps, directly or through another package, " % (regen.label, ctx.label) +
                 "to regenerate it", attr = attr_name)
        infos.append(info)
    return infos

def _generators(ctx, dep_package_files):
    """The generator settings of the package, as CocoPackageInfo.generators holds them.

    The C and C++ structs have the fields `_compute_output_paths` takes.
    `dep_package_files` is a list of the Coco.toml files of the package's transitive deps.
    """
    return {
        "c": struct(
            file_name_mangler = ctx.attr.c_file_name_mangler,
            header_prefix = ctx.attr.c_header_file_prefix,
            header_extension = ctx.attr.c_header_file_extension,
            impl_prefix = ctx.attr.c_implementation_file_prefix,
            impl_extension = ctx.attr.c_implementation_file_extension,
            include_prefix = _include_prefix(ctx, "c_include_prefix"),
            mocks = False,
            flat_hierarchy = ctx.attr.c_flat_file_hierarchy,
            regenerate_packages = _regenerate_packages(ctx, "c_regenerate_packages", dep_package_files),
        ),
        "cpp": struct(
            file_name_mangler = ctx.attr.cpp_file_name_mangler,
            header_prefix = ctx.attr.cpp_header_file_prefix,
            header_extension = ctx.attr.cpp_header_file_extension,
            impl_prefix = ctx.attr.cpp_implementation_file_prefix,
            impl_extension = ctx.attr.cpp_implementation_file_extension,
            include_prefix = _include_prefix(ctx, "cpp_include_prefix"),
            mocks = ctx.attr.cpp_mocks != "None",
            flat_hierarchy = ctx.attr.cpp_flat_file_hierarchy,
            regenerate_packages = _regenerate_packages(ctx, "cpp_regenerate_packages", dep_package_files),
        ),
        "csharp": struct(
            include_prefix = "",
            mocks = ctx.attr.csharp_mocks != "None",
            regenerate_packages = _regenerate_packages(ctx, "csharp_regenerate_packages", dep_package_files),
        ),
    }

def _coco_package_impl(ctx):
    _require_coco_toml(ctx.file.package, "package")

    # The effective list: the package's own, else its workspace's. Only the own list reaches the
    # package's transition, which cannot see the workspace.
    own_versions = [resolve_version_alias(version) for version in ctx.attr.popili_versions]
    popili_versions = own_versions
    inherited_from = None
    if ctx.attr.workspace:
        workspace = ctx.attr.workspace[CocoWorkspaceInfo]
        conflict = _inherited_versions_conflict(ctx.label, own_versions, workspace.popili_versions, ctx.attr.workspace.label, "workspace")
        if conflict:
            fail(conflict)
        if not own_versions:
            popili_versions = workspace.popili_versions
            inherited_from = ctx.attr.workspace.label

    # Resolved also without typecheck: a package always needs a toolchain, and its own list and its
    # deps' lists are checked against it at analysis, whether or not anything runs popili on it.
    toolchain = _resolved_coco_toolchain(ctx)
    forced = ctx.attr._force_version[BuildSettingInfo].value
    registry = ctx.attr._version_registry[CocoVersionRegistryInfo]

    # Its own transition only ever pins it to the first registered release it lists, so any other
    # version was selected above it; that one it cannot tell from a pin above it to the same.
    version = ctx.attr._version[BuildSettingInfo].value
    source = _version_source_of(ctx, self_pin = bool(own_versions) and version == _first_registered(own_versions, registry.versions))
    own = _own_package_versions_message(
        ctx.label,
        toolchain.popili_version,
        source,
        popili_versions,
        _effective_version(version, registry.versions),
        toolchain.label,
        registry,
        forced,
        inherited_from = inherited_from,
    )
    if own and not forced:
        fail(own)

    # Forced, a bring-your-own toolchain of another version fails here, before the warning; a list
    # naming the toolchain's version does not excuse the flag or a pin naming another.
    conflict = _toolchain_version_conflict(ctx, toolchain, source)
    if conflict:
        fail(conflict)
    if own:
        print(own)  # buildifier: disable=print

    # Direct deps only: a dep listing this version, or none, is analysed with it and has checked
    # its own deps; one that does not list it fails here.
    deps_popili_versions = [(dep.label, dep[CocoPackageInfo].popili_versions) for dep in ctx.attr.deps]

    # Only an own list steers the package's build, so only it can name a version to build with.
    _report_package_versions_conflicts(ctx, toolchain, deps_popili_versions, of_dep = True, source = source, own_versions = own_versions, registry = registry)
    package_file = ctx.file.package
    dep_package_files = depset(
        direct = [dep[CocoPackageInfo].package_file for dep in ctx.attr.deps],
        transitive = [dep[CocoPackageInfo].dep_package_files for dep in ctx.attr.deps],
    )
    generators = _generators(ctx, dep_package_files.to_list())
    srcs = depset(
        direct = ctx.files.srcs,
        transitive = [dep[CocoPackageInfo].srcs for dep in ctx.attr.deps],
    )
    test_srcs = depset(
        direct = ctx.files.test_srcs,
        transitive = [dep[CocoPackageInfo].test_srcs for dep in ctx.attr.deps],
    )

    # Workspace Coco.toml files for this package and its deps, so popili can resolve inherited settings
    workspace_transitive = [dep[CocoPackageInfo].workspace_files for dep in ctx.attr.deps]
    if ctx.attr.workspace:
        workspace_transitive.append(ctx.attr.workspace[CocoWorkspaceInfo].files)
    workspace_files = depset(transitive = workspace_transitive)

    package_dir = package_file.dirname
    source_roots = resolve_source_roots(package_dir, ctx.files.srcs, ctx.attr.source_roots, "source_roots", ctx.label)
    test_source_roots = []
    if ctx.files.test_srcs:
        test_source_roots = resolve_source_roots(package_dir, ctx.files.test_srcs, ctx.attr.test_source_roots, "test_source_roots", ctx.label)

    # Conditionally run typecheck
    typecheck_marker = None
    if ctx.attr.typecheck:
        typecheck_marker = _run_typecheck(ctx, struct(
            package_file = package_file,
            dep_package_files = dep_package_files,
            srcs = srcs,
            test_srcs = test_srcs,
            typecheck_marker = None,
            workspace_files = workspace_files,
        ))

    # Build the list of files for DefaultInfo
    default_files_direct = [package_file]
    if typecheck_marker:
        default_files_direct.append(typecheck_marker)

    return [
        CocoPackageInfo(
            name = ctx.attr.name,
            package_file = package_file,
            dep_package_files = dep_package_files,
            direct_srcs = depset(ctx.files.srcs),
            direct_test_srcs = depset(ctx.files.test_srcs),
            generators = generators,
            popili_versions = popili_versions,
            source_roots = source_roots,
            srcs = srcs,
            test_source_roots = test_source_roots,
            test_srcs = test_srcs,
            typecheck_marker = typecheck_marker,
            workspace_files = workspace_files,
        ),
        DefaultInfo(files = depset(direct = default_files_direct, transitive = [srcs, test_srcs, dep_package_files, workspace_files])),
    ]

def _include_prefix_doc(language, section):
    return ("Must match the package's effective `generator.%s.includePrefix`: the value in its Coco.toml, or " % section +
            "else the one it inherits from its workspace or receives from a dependency with `exportConfig = true`. " +
            "Default `\"\"`, popili's default. Generated %s headers are included as `<prefix>/<path below the " % language +
            "source root>`, the way popili's own generated code includes them: `#include \"Foo.h\"` by default, " +
            "`#include \"motor/Foo.h\"` for `\"motor\"`. A mismatch fails when compiling this package's generated " +
            "code, with the header not found under the Coco.toml prefix.")

# The coco_package attributes that mirror the [generator.<language>] settings in Coco.toml, which
# coco_generate needs to predict the files popili writes.
_GENERATOR_ATTRIBUTES = {
    "c_file_name_mangler": attr.string(
        default = "Unaltered",
        doc = "C file naming style. Must match Coco.toml generator.c.fileNameMangler. " +
              "Options: \"Unaltered\" (default), \"UnalteredButValid\", \"LowerCamelCase\", " +
              "\"LowerCamelCasePrefixUnderscore\", \"UpperCamelCase\", \"LowerUnderscore\", " +
              "\"UpperUnderscore\", \"CapsUpperUnderscore\".",
    ),
    "c_flat_file_hierarchy": attr.bool(
        default = False,
        doc = "Use a flat directory structure for C files. Must match " +
              "Coco.toml generator.c.flatFileHierarchy. Disabled by default.",
    ),
    "c_header_file_extension": attr.string(
        default = ".h",
        doc = "File extension for C headers. Defaults to \".h\".",
    ),
    "c_header_file_prefix": attr.string(
        default = "",
        doc = "Prefix for C header file names. Empty by default.",
    ),
    "c_implementation_file_extension": attr.string(
        default = ".c",
        doc = "File extension for C implementation files. Defaults to \".c\".",
    ),
    "c_implementation_file_prefix": attr.string(
        default = "",
        doc = "Prefix for C implementation file names. Empty by default.",
    ),
    "c_include_prefix": attr.string(
        doc = _include_prefix_doc("C", "c"),
    ),
    "c_regenerate_packages": attr.label_list(
        providers = [CocoPackageInfo],
        default = [],
        doc = "Other coco_package targets to regenerate with this package's C generator settings, each " +
              "a direct or transitive dep. Must match Coco.toml generator.c.regeneratePackages.",
    ),
    "cpp_file_name_mangler": attr.string(
        default = "Unaltered",
        doc = "C++ file naming style. Must match Coco.toml generator.cpp.fileNameMangler. " +
              "Options: \"Unaltered\" (default), \"UnalteredButValid\", \"LowerCamelCase\", " +
              "\"LowerCamelCasePrefixUnderscore\", \"UpperCamelCase\", \"LowerUnderscore\", " +
              "\"UpperUnderscore\", \"CapsUpperUnderscore\".",
    ),
    "cpp_flat_file_hierarchy": attr.bool(
        default = False,
        doc = "Use a flat directory structure for C++ files. Must match " +
              "Coco.toml generator.cpp.flatFileHierarchy. Disabled by default.",
    ),
    "cpp_header_file_extension": attr.string(
        default = ".h",
        doc = "File extension for C++ headers. Defaults to \".h\".",
    ),
    "cpp_header_file_prefix": attr.string(
        default = "",
        doc = "Prefix for C++ header file names. Empty by default.",
    ),
    "cpp_implementation_file_extension": attr.string(
        default = ".cc",
        doc = "File extension for C++ implementation files. Defaults to \".cc\".",
    ),
    "cpp_implementation_file_prefix": attr.string(
        default = "",
        doc = "Prefix for C++ implementation file names. Empty by default.",
    ),
    "cpp_include_prefix": attr.string(
        doc = _include_prefix_doc("C++", "cpp"),
    ),
    "cpp_mocks": attr.string(
        default = "None",
        values = ["None", "GMock", "GMockNumberMacros"],
        doc = "Must match the package's `generator.cpp.generateMocks`. Defaults to \"None\". Anything else " +
              "declares the `*Mock.*` files popili writes as test outputs of a C++ coco_generate, used by " +
              "`coco_cc_test_library`.",
    ),
    "cpp_regenerate_packages": attr.label_list(
        providers = [CocoPackageInfo],
        default = [],
        doc = "Other coco_package targets to regenerate with this package's C++ generator settings, each " +
              "a direct or transitive dep. Must match Coco.toml generator.cpp.regeneratePackages.",
    ),
    "csharp_mocks": attr.string(
        default = "None",
        values = ["None", "NSubstitute"],
        doc = "Must match the package's `generator.csharp.generateMocks`. Defaults to \"None\". " +
              "\"NSubstitute\" declares the `*Mock.cs` files popili writes as test outputs of a C# coco_generate.",
    ),
    "csharp_regenerate_packages": attr.label_list(
        providers = [CocoPackageInfo],
        default = [],
        doc = "Other coco_package targets to regenerate with this package's C# generator settings, each " +
              "a direct or transitive dep. Must match Coco.toml generator.csharp.regeneratePackages.",
    ),
}

_coco_package = rule(
    implementation = _coco_package_impl,
    cfg = _package_self_pin,
    attrs = dict(LICENSE_ATTRIBUTES.items() + TOOLCHAIN_ATTRIBUTES.items() + _GENERATOR_ATTRIBUTES.items() + {
        "deps": attr.label_list(
            providers = [CocoPackageInfo],
            doc = "Other coco_package targets this package depends on.",
        ),
        "package": attr.label(
            mandatory = True,
            allow_single_file = [".toml"],
            doc = "Label pointing to the Coco.toml file for this package.",
        ),
        "popili_versions": attr.string_list(
            doc = "The popili versions this package is compatible with, such as " +
                  "`[\"1.5.0\", \"1.5.1\"]`. Aliases such as `\"stable\"` are allowed. A target that runs " +
                  "another popili version on this package fails; under `--@rules_coco//:force_version` " +
                  "this is a warning instead. The local toolchain satisfies the list only when it " +
                  "names `\"local\"` and when `--@rules_coco//:version=local` is passed. The " +
                  "package itself is built with the version selected for it (via the default, " +
                  "the flag, or a consumer's pin) when the list has it, otherwise with " +
                  "the **first** listed release that is registered. Empty (the default) inherits " +
                  "the list of its `workspace`, if any. A list of its own must include every version " +
                  "the workspace lists: a member may support more versions than its workspace, never fewer.",
        ),
        "source_roots": attr.string_list(
            doc = "Directories, relative to Coco.toml, that hold the .coco sources. Must match " +
                  "Coco.toml package.sources. When empty, the common directory of `srcs` is used, " +
                  "which is right whenever all sources sit directly below a single root. Set it when " +
                  "there are several roots, or when every source is in a subdirectory of the root.",
        ),
        "srcs": attr.label_list(
            allow_files = [".coco"],
            mandatory = True,
            doc = "The .coco source files for this package.",
        ),
        "test_source_roots": attr.string_list(
            doc = "Directories, relative to Coco.toml, that hold the .coco test sources. Must match " +
                  "Coco.toml package.testSources. When empty, the common directory of `test_srcs` is used.",
        ),
        "test_srcs": attr.label_list(
            allow_files = [".coco"],
            allow_empty = True,
            doc = "The .coco test source files for this package.",
        ),
        "typecheck": attr.bool(
            default = False,
            doc = "Run typecheck validation during package creation. When enabled, " +
                  "the build fails if typecheck errors are found. Disabled by default.",
        ),
        "workspace": attr.label(
            providers = [CocoWorkspaceInfo],
            doc = "Optional coco_workspace whose Coco.toml settings this package inherits.",
        ),
    }.items()),
    toolchains = [
        COCO_TOOLCHAIN_TYPE,
    ],
)

def _coco_package_macro_impl(name, visibility, **kwargs):
    _coco_package(
        name = name,
        visibility = visibility,
        **kwargs
    )

coco_package = macro(
    doc = """Define a Coco package from a Coco.toml and its .coco source files.

A coco_package is the unit the other Coco rules operate on: pass it to
coco_generate to produce code, to coco_verify_test to verify it, or to
coco_fmt_test to check formatting. Packages may depend on other packages via
`deps`, and may inherit shared settings from a coco_workspace via `workspace`.

The `c_*`, `cpp_*` and `csharp_*` attributes mirror the package's generator
settings in Coco.toml (`[generator.c]`, `[generator.cpp]` and
`[generator.csharp]`), which coco_generate needs to know the files popili
writes.""",
    inherit_attrs = _coco_package,
    implementation = _coco_package_macro_impl,
)

def _coco_workspace_impl(ctx):
    _require_coco_toml(ctx.file.workspace, "workspace")

    parent_transitive = []
    popili_versions = [resolve_version_alias(version) for version in ctx.attr.popili_versions]
    if ctx.attr.parent:
        parent = ctx.attr.parent[CocoWorkspaceInfo]
        parent_transitive.append(parent.files)
        conflict = _inherited_versions_conflict(ctx.label, popili_versions, parent.popili_versions, ctx.attr.parent.label, "parent")
        if conflict:
            fail(conflict)
        popili_versions = popili_versions or parent.popili_versions
    files = depset(direct = [ctx.file.workspace], transitive = parent_transitive)

    return [
        CocoWorkspaceInfo(
            files = files,
            popili_versions = popili_versions,
        ),
        DefaultInfo(files = files),
    ]

_coco_workspace = rule(
    implementation = _coco_workspace_impl,
    attrs = {
        "parent": attr.label(
            providers = [CocoWorkspaceInfo],
            doc = "An enclosing coco_workspace, when this workspace is nested inside another",
        ),
        "popili_versions": attr.string_list(
            doc = "The popili versions every member package is known to work with, such as " +
                  "`[\"1.5.0\", \"1.5.1\"]`; aliases such as `\"stable\"` are allowed. Empty (the default) " +
                  "inherits the `parent`'s list, if any. Member packages without `popili_versions` of their " +
                  "own inherit the list and are checked against it like a package that lists it. A member or " +
                  "nested workspace with a list of its own must include every version listed here, otherwise " +
                  "it fails: a member may support more versions than its workspace, never fewer.",
        ),
        "workspace": attr.label(
            mandatory = True,
            allow_single_file = [".toml"],
            doc = "Label pointing to the workspace's root Coco.toml (must contain a [workspace] section)",
        ),
    },
    doc = "Declares a Coco workspace root whose shared settings flow down to member coco_package targets.",
)

def _coco_workspace_macro_impl(name, visibility, **kwargs):
    _coco_workspace(
        name = name,
        visibility = visibility,
        **kwargs
    )

coco_workspace = macro(
    doc = """Declares a Coco workspace root.

A workspace's Coco.toml carries shared settings that popili applies to member
packages. Reference this target from a coco_package's `workspace` attribute.""",
    inherit_attrs = _coco_workspace,
    implementation = _coco_workspace_macro_impl,
)

# The file name mangler styles rules_coco implements.
FILE_NAME_MANGLER_STYLES = [
    "Unaltered",
    "UnalteredButValid",
    "LowerCamelCase",
    "LowerCamelCasePrefixUnderscore",
    "UpperCamelCase",
    "LowerUnderscore",
    "UpperUnderscore",
    "CapsUpperUnderscore",
]

# The styles that keep the input's underscores and separate words with one.
# LowerCamelCasePrefixUnderscore is *not* one of them: apart from the leading
# underscore it is plain LowerCamelCase.
_UNDERSCORE_STYLES = ["LowerUnderscore", "UpperUnderscore", "CapsUpperUnderscore"]
_LOWER_CAMEL_CASE_STYLES = ["LowerCamelCase", "LowerCamelCasePrefixUnderscore"]
_ASCII_LOWER = "abcdefghijklmnopqrstuvwxyz"
_ASCII_UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
_ASCII_DIGITS = "0123456789"

# These deliberately test ASCII membership rather than using Starlark's
# .isalpha()/.islower(), which are Unicode-aware. popili's helpers are
# ASCII-only, so this keeps the two implementations identical: anything
# outside ASCII is dropped by every style except Unaltered.

def _is_ascii_lower(char):
    return len(char) == 1 and char in _ASCII_LOWER

def _is_ascii_upper(char):
    return len(char) == 1 and char in _ASCII_UPPER

def _is_alpha(char):
    return _is_ascii_lower(char) or _is_ascii_upper(char)

def _is_valid_character(char):
    """The characters popili's name mangler keeps: alphanumeric or underscore."""
    return char == "_" or (len(char) == 1 and char in _ASCII_DIGITS) or _is_alpha(char)

def _starts_new_word(previous, current):
    """Does this character begin a new word, as popili's name mangler sees it?

    A new word starts only at an underscore, or at a lower->upper transition.
    This is why runs of capitals are never split (ABCDef -> abcdef) and why a
    digit suppresses the boundary that follows it (Level2Sensor -> level2sensor).
    """
    return current == "_" or (_is_ascii_lower(previous) and _is_ascii_upper(current))

def _mangle_name(name, style):
    """Apply name mangling based on the specified style.

    rules_coco has to predict the file names popili will write,
    so this implementation has to be identical to popili's.

    Args:
        name: The name to mangle
        style: One of FILE_NAME_MANGLER_STYLES

    Returns:
        The mangled name
    """
    if style not in FILE_NAME_MANGLER_STYLES:
        fail("Unsupported file name mangler style: %s" % style)

    is_underscore_style = style in _UNDERSCORE_STYLES
    is_lower_camel_case = style in _LOWER_CAMEL_CASE_STYLES

    buffer = []
    if style == "LowerCamelCasePrefixUnderscore":
        buffer.append("_")

    is_new_word = True
    is_first_word = True
    previous = ""

    for current in name.elems():
        # Unaltered keeps every character, including ones that are not valid
        # identifier characters.
        if style == "Unaltered":
            buffer.append(current)
            previous = current
            continue

        # Characters that are neither alphanumeric nor '_' are dropped, but
        # they still break the current word.
        if not _is_valid_character(current):
            is_new_word = True
            previous = current
            continue

        # UnalteredButValid keeps every valid character as it is.
        if style == "UnalteredButValid":
            buffer.append(current)
            previous = current
            continue

        # The *CamelCase styles drop underscores; the *Underscore styles keep
        # them verbatim.
        if current == "_" and not is_underscore_style:
            is_new_word = True
            previous = current
            continue

        is_new_word = is_new_word or previous == "" or _starts_new_word(previous, current)

        should_be_upper = False
        if is_new_word:
            should_be_upper = (
                style == "UpperUnderscore" or
                style == "CapsUpperUnderscore" or
                style == "UpperCamelCase" or
                (is_lower_camel_case and not is_first_word)
            )

            # Add a separator, but never double an underscore that the input
            # already supplied.
            if (is_underscore_style and not is_first_word and current != "_" and
                (not buffer or buffer[-1] != "_")):
                buffer.append("_")

            is_first_word = False

        # CapsUpperUnderscore is the only style that upper-cases every
        # character rather than just the first of each word.
        if style == "CapsUpperUnderscore":
            should_be_upper = True

        buffer.append(current.upper() if should_be_upper else current.lower())
        previous = current
        is_new_word = False

    # Ensure the result starts with a letter.
    if style != "LowerCamelCasePrefixUnderscore" and (not buffer or not _is_alpha(buffer[0])):
        buffer.insert(0, "I" if style in ["UpperUnderscore", "UpperCamelCase"] else "i")

    return "".join(buffer)

def _join_path(components):
    """Join non-empty path components with "/"."""
    return "/".join([c for c in components if c])

def _output_file_names(base_name, config):
    """Compute the four output file names for an already-mangled base name.

    popili appends the "Mock" suffix *after* mangling, and mangles neither the
    suffix nor the prefixes.

    Args:
        base_name: The mangled base name
        config: Language configuration struct

    Returns:
        A struct with header, impl, mock_header and mock_impl names
    """
    mock_header = None
    mock_impl = None
    if config.mocks:
        mock_header = config.header_prefix + base_name + "Mock" + config.header_extension
        mock_impl = config.impl_prefix + base_name + "Mock" + config.impl_extension

    return struct(
        header = config.header_prefix + base_name + config.header_extension,
        impl = config.impl_prefix + base_name + config.impl_extension,
        mock_header = mock_header,
        mock_impl = mock_impl,
    )

def _compute_output_paths(module_path, config):
    """Compute output paths for a module, relative to the source root.

    popili mangles *every* component of a module's path, not just the file
    stem.

    This is a pure function so it can be unit tested; the caller is responsible
    for prepending the root output directory and declaring the files.

    Args:
        module_path: Path components relative to the source root, extension
            stripped, e.g. ["Geometry", "Dims"]
        config: Language configuration struct

    Returns:
        A struct with header, impl, mock_header and mock_impl paths
    """
    components = module_path
    if config.flat_hierarchy:
        # popili takes only the final component under a flat hierarchy
        components = components[-1:]

    mangled = [_mangle_name(component, config.file_name_mangler) for component in components]
    directory = _join_path(mangled[:-1])
    names = _output_file_names(mangled[-1], config)

    return struct(
        header = _join_path([directory, names.header]),
        impl = _join_path([directory, names.impl]),
        mock_header = _join_path([directory, names.mock_header]) if names.mock_header else None,
        mock_impl = _join_path([directory, names.mock_impl]) if names.mock_impl else None,
    )

def _module_path_for(src, package_dir, root_output_dir):
    """Path components of a source file relative to the source root.

    Mirrors how popili derives a module's path from the source path relative
    to the sources root. That path is what gets mangled, component by
    component.

    Args:
        src: Source file
        package_dir: Directory containing the package's Coco.toml
        root_output_dir: Source root relative to the package (e.g. "src" or "../shared")

    Returns:
        A list of path components with the .coco extension stripped
    """
    relative_to_root = relative_path(relative_path(src.path, package_dir), root_output_dir)

    stem = relative_to_root
    if stem.endswith(".coco"):
        stem = stem[:-len(".coco")]

    return stem.split("/")

def _make_path_builder(ctx, output_dir):
    """Create a path builder that declares files below the output directory.

    Args:
        ctx: Rule context
        output_dir: Path from the BUILD file to the output directory

    Returns:
        Function(output_path) -> declared file
    """
    return lambda output_path: ctx.actions.declare_file(_join_path([output_dir, output_path]))

def _declare_language_outputs(ctx, headers, sources, mock_headers, mock_sources, config, path_builder, module_path):
    """Core logic for declaring output files.

    Args:
        ctx: Rule context
        headers: List to append regular header outputs to
        sources: List to append regular source outputs to
        mock_headers: List to append mock header outputs to
        mock_sources: List to append mock source outputs to
        config: The package's generator settings for the language
        path_builder: Function(relative_path) -> declared file
        module_path: Source path components relative to the source root
    """
    if ctx.attr.language == "cpp" or ctx.attr.language == "c":
        output_paths = _compute_output_paths(module_path, config)

        headers.append(path_builder(output_paths.header))
        sources.append(path_builder(output_paths.impl))

        if output_paths.mock_header:
            mock_headers.append(path_builder(output_paths.mock_header))
            mock_sources.append(path_builder(output_paths.mock_impl))
    elif ctx.attr.language == "csharp":
        # C# generation - simple .cs files, always hierarchical.
        #
        # popili's C# generator has neither a file name mangle style nor a
        # flat hierarchy option, so there is nothing to honour here: it rejects
        # fileNameMangler under [generator.csharp] outright and writes each
        # path component verbatim. Components are used as-is and the hierarchy
        # is always preserved.
        #
        # Note this is about *file* names only: C# identifiers are still
        # mangled.
        directory = _join_path(module_path[:-1])
        base_name = module_path[-1]
        sources.append(path_builder(_join_path([directory, base_name + ".cs"])))

        if config.mocks:
            mock_sources.append(path_builder(_join_path([directory, base_name + "Mock.cs"])))
    else:
        fail("unrecognised language")

def _add_outputs(ctx, headers, sources, mock_headers, mock_sources, config, path_builder, src, package_dir, source_roots):
    """Declare the outputs for one source file.

    Regenerated packages pass their own package_dir and source_roots with the current package's
    path builder.

    Args:
        ctx: Rule context
        headers: List to append regular header outputs to
        sources: List to append regular source outputs to
        mock_headers: List to append mock header outputs to
        mock_sources: List to append mock source outputs to
        config: The package's generator settings for the language
        path_builder: Declares outputs below the output directory
        src: Source file
        package_dir: Directory containing the Coco.toml of the package src belongs to
        source_roots: Source roots of that package, which coco_package has checked cover src
    """
    source_root = source_root_for(relative_path(src.path, package_dir), source_roots)
    module_path = _module_path_for(src, package_dir, source_root)
    _declare_language_outputs(ctx, headers, sources, mock_headers, mock_sources, config, path_builder, module_path)

def _coco_package_generate_impl(ctx):
    package = ctx.attr.package
    info = package[CocoPackageInfo]
    srcs = info.direct_srcs
    test_srcs = info.direct_test_srcs
    package_dir = info.package_file.dirname
    config = info.generators[ctx.attr.language]

    headers = []
    sources = []
    mock_headers = []
    mock_sources = []
    test_headers = []
    test_sources = []

    # Each coco_generate has an include root of its own, so its headers resolve only through this
    # target. popili puts the include prefix in #include strings but not in the paths it writes,
    # so the output directory is the root plus the prefix.
    bin_package = _join_path([ctx.bin_dir.path, ctx.label.workspace_root, ctx.label.package])
    root_dir = _join_path(["_coco", ctx.label.name])
    output_dir = _join_path([root_dir, config.include_prefix])
    include_root = _join_path([bin_package, root_dir])
    path_builder = _make_path_builder(ctx, output_dir)

    # Regenerated packages are deps of the package, which checked their popili_versions.
    toolchain = _check_package_versions(ctx, [package])

    # Regenerated packages' files go into this package's output directory (using this package's
    # generator settings), with module paths relative to their own source roots.
    for regen_info in config.regenerate_packages:
        for src in regen_info.direct_srcs.to_list():
            _add_outputs(ctx, headers, sources, mock_headers, mock_sources, config, path_builder, src, regen_info.package_file.dirname, regen_info.source_roots)

    for src in srcs.to_list():
        _add_outputs(ctx, headers, sources, mock_headers, mock_sources, config, path_builder, src, package_dir, info.source_roots)

    for src in test_srcs.to_list():
        _add_outputs(ctx, test_headers, test_sources, mock_headers, mock_sources, config, path_builder, src, package_dir, info.test_source_roots)
    test_headers += mock_headers
    test_sources += mock_sources

    # Test code and mocks land beside the regular code. --test-output is passed explicitly rather than
    # relying on popili defaulting it to --output.
    generated_dir = _join_path([bin_package, output_dir])
    arguments = [
        "generate-%s" % ctx.attr.language,
        "--output",
        generated_dir,
        "--test-output",
        generated_dir,
        "--output-empty-files",
        "--output-runtime=false",
    ]
    all_outputs = headers + sources
    all_test_outputs = test_headers + test_sources

    _run_coco(
        ctx = ctx,
        package = package,
        verb = "Generating %s" % ctx.attr.language,
        mnemonic = "CocoGenerate",
        arguments = arguments,
        outputs = all_outputs + all_test_outputs,
    )

    if ctx.attr.language in ("cpp", "c"):
        lang_provider = CocoCcGeneratedInfo(
            headers = depset(headers),
            include_root = include_root,
            popili_version = toolchain.popili_version,
            sources = depset(sources),
            test_headers = depset(test_headers),
            test_sources = depset(test_sources),
        )
    elif ctx.attr.language == "csharp":
        lang_provider = CocoCSharpGeneratedInfo(
            sources = depset(sources),
            test_sources = depset(test_sources),
        )
    else:
        fail("Unsupported language: %s" % ctx.attr.language)

    return [
        DefaultInfo(
            files = depset(all_outputs),
        ),
        lang_provider,
    ]

_coco_generate = rule(
    implementation = _coco_package_generate_impl,
    attrs = dict(LICENSE_ATTRIBUTES.items() + TOOLCHAIN_ATTRIBUTES.items() + POPILI_VERSION_ATTRIBUTES.items() + {
        "language": attr.string(
            mandatory = True,
            values = ["cpp", "c", "csharp"],
            doc = "Target language for code generation: \"cpp\", \"c\", or \"csharp\".",
        ),
        "package": attr.label(
            providers = [CocoPackageInfo],
            mandatory = True,
            doc = "The coco_package target containing the source files to generate from.",
        ),
    }.items()),
    cfg = popili_version_pin,
    toolchains = [
        COCO_TOOLCHAIN_TYPE,
    ],
)

def _coco_test_outputs_impl(ctx):
    if CocoCcGeneratedInfo in ctx.attr.package:
        info = ctx.attr.package[CocoCcGeneratedInfo]
        files = depset(transitive = [info.test_headers, info.test_sources])
    elif CocoCSharpGeneratedInfo in ctx.attr.package:
        info = ctx.attr.package[CocoCSharpGeneratedInfo]
        files = info.test_sources
    else:
        fail("Target %s does not provide CocoCcGeneratedInfo or CocoCSharpGeneratedInfo. " % ctx.attr.package.label +
             "It must be a coco_generate target.")
    return [DefaultInfo(files = files)]

_coco_test_outputs = rule(
    implementation = _coco_test_outputs_impl,
    attrs = {
        "package": attr.label(
            mandatory = True,
        ),
    },
)

def coco_test_outputs_name(name):
    """Returns the name of the target that holds a `coco_generate` target's generated test code.

    `coco_generate(name = "x")` also creates `x.tst`, whose files are the generated test sources and
    headers, mocks included. `coco_cc_test_library` and `coco_c_test_library` compile them for you; use
    this target for other consumers.

    Args:
      name: The name of the `coco_generate` target.

    Returns:
      The name of its test code target, `name + ".tst"`.
    """
    return "%s.tst" % name

def _header_matches(include_path, pattern):
    """Whether a public_hdrs entry, a file name or whole trailing components of the include path, selects the header."""
    return include_path == pattern or include_path.endswith("/" + pattern)

def _library_version_mismatch_message(library, library_version, library_source, generator, generator_version):
    """Words the failure of a library whose runtime and generated code come from different popili versions.

    Args:
        library: The label of the coco_cc_library or coco_c_library.
        library_version: The popili version of the runtime the library links, as its toolchain declares it.
        library_source: Where the library's configured version came from, as `_version_source` phrases it.
        generator: The label of the coco_generate the library builds from.
        generator_version: The popili version that generated the code, as its toolchain declares it.

    Returns:
        The message to fail with.
    """
    return (
        "%s links the Coco runtime of popili %s (%s), but builds from %s, generated by popili %s. " %
        (library, library_version, library_source, generator, generator_version) +
        "A library and the code it builds from must come from the same popili version: give %s " % library +
        "popili_version = %r, or pin %s to %s, or leave %s unpinned so that it follows the library." %
        (generator_version, generator, library_version, generator)
    )

def _library_version_conflict(library, library_version, library_source, generated):
    """Checks that a library and all the code it builds from come from one popili version.

    Args:
        library: The label of the coco_cc_library or coco_c_library.
        library_version: The popili version of the runtime the library links, as its toolchain
            declares it.
        library_source: Where the library's configured version came from, as `_version_source`
            phrases it.
        generated: A (label, version) pair per coco_generate the library builds from, in order, with
            the popili version that generated its code.

    Returns:
        The message to fail with, or None when they agree.
    """
    for generator, version in generated:
        if version != library_version:
            return _library_version_mismatch_message(library, library_version, library_source, generator, version)
    return None

def _library_packages(ctx):
    """The coco_generate targets a library builds from, from generated_package or generated_packages.

    The macros forward both as given, so that either may be a select().
    """
    if ctx.attr.generated_package and ctx.attr.packages:
        fail("%s: cannot specify both generated_package and generated_packages" % ctx.label.same_package_label(ctx.attr.library))
    if ctx.attr.generated_package:
        # A list where the attr has a transition (_coco_cc_gen), a target where not (_coco_cc_pin).
        package = ctx.attr.generated_package
        return package if type(package) == "list" else [package]
    if not ctx.attr.packages:
        fail("%s: specify generated_package or generated_packages" % ctx.label.same_package_label(ctx.attr.library))
    return ctx.attr.packages

def _coco_cc_pin_impl(ctx):
    """Checks a library's generated code against the runtime of the library's popili version.

    Analysed at the library's `popili_version`, so the generators beneath it follow that pin
    unless they have one of their own, and the runtime it forwards is the pinned version's.
    """
    toolchain = _coco_toolchain(ctx)
    conflict = _library_version_conflict(
        ctx.label.same_package_label(ctx.attr.library),
        toolchain.popili_version,
        _version_source_of(ctx),
        [(package.label, package[CocoCcGeneratedInfo].popili_version) for package in _library_packages(ctx)],
    )
    if conflict:
        fail(conflict)
    return [
        ctx.attr.runtime[CcInfo],
        # With the runfiles of the runtime's extra deps, as when it was in the library's deps.
        DefaultInfo(runfiles = ctx.attr.runtime[DefaultInfo].default_runfiles),
    ]

# Runs no actions: only the runtime is built at the library's pin. The library compiles the
# generated code in its own configuration, through _coco_cc_gen. One per library, so that it sees
# every generator the library builds from.
_coco_cc_pin = rule(
    implementation = _coco_cc_pin_impl,
    attrs = dict(TOOLCHAIN_ATTRIBUTES.items() + POPILI_VERSION_ATTRIBUTES.items() + {
        "generated_package": attr.label(
            providers = [CocoCcGeneratedInfo],
            doc = "The coco_generate target the library builds from, when it is just one.",
        ),
        "library": attr.string(
            mandatory = True,
            doc = "The name of the library in this package, for messages.",
        ),
        "packages": attr.label_list(
            providers = [CocoCcGeneratedInfo],
            doc = "The coco_generate targets the library builds from, when it is several.",
        ),
        "runtime": attr.label(
            providers = [CcInfo],
            mandatory = True,
            doc = "The Coco runtime the library links: //coco:cc_runtime or //coco:c_runtime.",
        ),
    }.items()),
    cfg = popili_version_pin,
    toolchains = [COCO_TOOLCHAIN_TYPE],
)

def _coco_cc_gen_impl(ctx):
    """Extracts the generated C/C++ sources and headers of a library's packages, providing CcInfo for headers and the runtime.

    Returns DefaultInfo with sources (+ private headers) for cc_library srcs and the runtime's
    runfiles, and CcInfo with public headers and the runtime for cc_library deps.
    """
    all_headers = []
    sources = []
    include_roots = []
    include_paths = {}
    for package in _library_packages(ctx):
        gen_info = package[CocoCcGeneratedInfo]
        if ctx.attr.use_test_outputs:
            headers = gen_info.test_headers.to_list()
            sources += gen_info.test_sources.to_list()
        else:
            headers = gen_info.headers.to_list()
            sources += gen_info.sources.to_list()
        all_headers += headers
        include_roots.append(gen_info.include_root)
        for h in headers:
            include_paths[h] = relative_path(h.path, gen_info.include_root)

    if ctx.attr.public_hdrs == _ALL_HDRS_PUBLIC:
        public_hdrs = all_headers
        private_hdrs = []
    else:
        # Per entry, so that one matching nothing is an error.
        public = {}
        for pattern in ctx.attr.public_hdrs:
            selected = [h for h in all_headers if _header_matches(include_paths[h], pattern)]
            if not selected:
                fail(("public_hdrs of %s: \"%s\" matches none of the generated headers. An entry is a header's file " +
                      "name or a trailing part of its include path. The generated headers are:\n  %s") %
                     (ctx.label.same_package_label(ctx.attr.library), pattern, "\n  ".join(sorted(include_paths.values()))))
            for h in selected:
                public[h] = True
        public_hdrs = [h for h in all_headers if h in public]
        private_hdrs = [h for h in all_headers if h not in public]

    # The generated code includes its headers relative to the include roots.
    compilation_context = cc_common.create_compilation_context(
        headers = depset(public_hdrs),
        quote_includes = depset(include_roots),
    )

    # gmock comes in here rather than in the library's deps, so that it may be a select() that
    # can also select None.
    extra = [ctx.attr.gmock] if ctx.attr.gmock else []
    return [
        DefaultInfo(
            files = depset(sources + private_hdrs),
            runfiles = ctx.attr.pinned[DefaultInfo].default_runfiles.merge_all(
                [dep[DefaultInfo].default_runfiles for dep in extra],
            ),
        ),
        # Direct, as when the runtime and gmock were in the library's own deps, for layering_check.
        cc_common.merge_cc_infos(direct_cc_infos = [
            CcInfo(compilation_context = compilation_context),
            ctx.attr.pinned[CcInfo],
        ] + [dep[CcInfo] for dep in extra]),
    ]

# The default of _coco_cc_gen's public_hdrs, for a library whose public_hdrs is None or a select()
# that selects None: all generated headers are public.
_ALL_HDRS_PUBLIC = ["*"]

# One per library, so that public_hdrs is checked against all its packages at once.
_coco_cc_gen = rule(
    implementation = _coco_cc_gen_impl,
    attrs = {
        "generated_package": attr.label(
            providers = [CocoCcGeneratedInfo],
            # As for packages.
            cfg = popili_version_pin,
            doc = "The coco_generate target the library builds from, when it is just one.",
        ),
        "gmock": attr.label(
            providers = [CcInfo],
            doc = "The GoogleTest/GoogleMock library of a test library, in the library's configuration.",
        ),
        "library": attr.string(
            mandatory = True,
            doc = "The name of the library in this package, for messages.",
        ),
        "packages": attr.label_list(
            providers = [CocoCcGeneratedInfo],
            # The library's _coco_cc_pin applies the same transition with the same popili_version,
            # so these are the coco_generate targets it checked, analysed once.
            cfg = popili_version_pin,
            doc = "The coco_generate targets the library builds from, when it is several, analysed at the library's popili_version.",
        ),
        "pinned": attr.label(
            providers = [CcInfo],
            mandatory = True,
            doc = "The library's _coco_cc_pin, for the runtime, its runfiles and the version check.",
        ),
        "popili_version": attr.string(doc = "The library's popili_version, for the transition on `packages`."),
        "public_hdrs": attr.string_list(
            default = _ALL_HDRS_PUBLIC,
            doc = "Header names to make public; all of them by default. " +
                  "Use bare filenames (e.g., 'ISensor.h') to match by name, or " +
                  "trailing parts of the include path (e.g., 'sensors/ISensor.h') to disambiguate. " +
                  "An entry that matches no header is an error.",
        ),
        "use_test_outputs": attr.bool(default = False, doc = "If True, extract test/mock outputs instead of regular outputs"),
    },
)

def _coco_generate_macro_impl(name, visibility, **kwargs):
    _coco_generate(
        name = name,
        visibility = visibility,
        **kwargs
    )

    # Companion target for the generated test sources/headers. It gets the generator's
    # visibility and common attrs; the rest of kwargs are generator-only. See
    # test/visibility_propagation and test/companion_attrs.
    _coco_test_outputs(
        name = coco_test_outputs_name(name),
        package = name,
        visibility = visibility,
        **companion_attrs(kwargs)
    )

coco_generate = macro(
    doc = """Generate C, C++, or C# code from a Coco package.

The generated C/C++ files are compiled with coco_cc_library or coco_c_library,
which find them below an include root of this target's own; `library_rule`
lets those macros call a custom cc_library. The generated files are also
exposed through DefaultInfo for other consumers.

The generator settings (file extensions, prefixes, etc.) come from the
package: they are attributes of coco_package, mirroring its Coco.toml.

Alongside the main code-generation target, a companion `<name>.tst` target is
created that exposes the generated test sources and headers.""",
    inherit_attrs = _coco_generate,
    implementation = _coco_generate_macro_impl,
)

# What every rule made by popili_rule has before the author's own attributes.
_POPILI_RULE_ATTRIBUTES = dict(LICENSE_ATTRIBUTES.items() + TOOLCHAIN_ATTRIBUTES.items() + POPILI_VERSION_ATTRIBUTES.items())

def _popili_rule_reserved_attribute(attrs, package):
    """The first name in `attrs` that `popili_rule` defines itself, else None.

    Pure, for the unit tests. Only the names the factory adds are reserved; an author's own
    private attributes (leading underscore) are welcome.

    Args:
        attrs: The rule author's attribute dict.
        package: Whether the factory adds the `package` attribute.
    """
    for name in attrs:
        if name in _POPILI_RULE_ATTRIBUTES or (package and name == "package"):
            return name
    return None

def _popili_handle(ctx, toolchain, package, from_runfiles):
    """The `popili` argument of a popili_rule implementation: what the rule may use of the toolchain.

    Args:
        ctx: The rule context.
        toolchain: The resolved Coco toolchain.
        package: The coco_package target the factory's `package` attribute holds, or None.
        from_runfiles: Whether the rule is a test or executable, which runs popili from its
            runfiles rather than in an action.

    Returns:
        A struct with `version`, `executable`, `package` (with the attribute), and `run` for a
        rule or `script` and `runfiles` for a test or executable.
    """

    def run(arguments, outputs, inputs = [], mnemonic = "Popili", progress_message = None):
        ctx.actions.run(
            executable = toolchain.coco,
            tools = [toolchain.coco],
            env = _coco_env(ctx, for_action = True),
            mnemonic = mnemonic,
            progress_message = progress_message or "Running popili for %s" % ctx.label,
            inputs = depset(
                direct = inputs if type(inputs) == "list" else [],
                transitive = [_coco_runfiles(ctx, package, False)] + ([inputs] if type(inputs) == "depset" else []),
            ),
            outputs = outputs,
            arguments = _coco_startup_args(ctx, package, False) + arguments,
        )

    def script(arguments):
        return _create_coco_wrapper_script(ctx, package, arguments)

    members = {
        "executable": toolchain.coco,
        "version": toolchain.popili_version,
    }
    if package:
        members["package"] = package[CocoPackageInfo]
    if from_runfiles:
        members["runfiles"] = _coco_runfiles(ctx, package, True)
        members["script"] = script
    else:
        members["run"] = run
    return struct(**members)

def popili_rule(implementation, attrs = {}, package = False, test = False, executable = False, doc = "", provides = []):
    """Defines a rule that runs popili, with the plumbing rules_coco's own rules have.

    The rule takes `popili_version` and resolves the Coco toolchain like `coco_generate` does: a
    pin wins over `--@rules_coco//:version` unless `--@rules_coco//:force_version` is set, and a
    missing toolchain or a version mismatch fails with rules_coco's message. The implementation is
    called as `implementation(ctx, popili)`, where `popili` is a struct:

    - `version`: the resolved toolchain's popili version, such as `"1.5.1"`, or `"local"`.
    - `executable`: the popili binary, a `File`. Running it takes the licence and preferences
      arguments, so use `run` or `script` rather than the file itself.
    - `package`: with `package = True`, the `CocoPackageInfo` of the `package` attribute.
    - `run(arguments, outputs, inputs = [], mnemonic = "Popili", progress_message = None)`
      (rules only): registers an action running popili with `arguments` after the startup
      arguments, the licence and preferences files, the package's files when there is one, and
      `inputs` (a list or depset) as inputs.
    - `script(arguments)` and `runfiles` (tests and executables only): the wrapper script running
      popili with `arguments` from the runfiles, and the depset of files it needs there.
      Return `DefaultInfo(executable = popili.script(...), runfiles = ctx.runfiles(transitive_files = popili.runfiles))`.

    ```starlark
    def _typecheck_test_impl(ctx, popili):
        return DefaultInfo(
            executable = popili.script(["typecheck"]),
            runfiles = ctx.runfiles(transitive_files = popili.runfiles),
        )

    typecheck_test = popili_rule(
        implementation = _typecheck_test_impl,
        package = True,
        test = True,
    )
    ```

    Args:
        implementation: The function called as `implementation(ctx, popili)`, returning the rule's providers.
        attrs: The rule's own attributes, as for `rule()`, private ones included. `popili_version`,
            `package` with `package = True`, and the private attributes the factory adds are its
            own; using one of their names is an error.
        package: Whether to add `package`, a mandatory label of the `coco_package` popili runs
            on. The rule then fails when the package's `popili_versions` do not list the version it
            runs, like `coco_generate` does, and `run` and `script` pass the package to popili.
        test: Whether the rule is a test (`rule(test = True)`), which runs popili from its runfiles.
        executable: Whether the rule is an executable (`rule(executable = True)`), such as a
            formatter to `bazel run`, which runs popili from its runfiles like a test. It gets the
            popili of the platform `bazel run` executes it on: on Bazel 9+ an execution platform
            matching the target platform is preferred, on Bazel 8 the rule is constrained to the host.
        doc: The rule's documentation, as for `rule()`.
        provides: The providers the rule promises, as for `rule()`.

    Returns:
        The rule.
    """
    reserved = _popili_rule_reserved_attribute(attrs, package)
    if reserved:
        fail("popili_rule defines the attribute %r itself; choose another name" % reserved)
    if test and executable:
        fail("popili_rule: a test is executable already; set test or executable, not both")
    own = dict(_POPILI_RULE_ATTRIBUTES)
    if package:
        own["package"] = attr.label(
            doc = "The coco_package target this rule runs popili on.",
            mandatory = True,
            providers = [CocoPackageInfo],
        )

    def _impl(ctx):
        if package:
            toolchain = _check_package_versions(ctx, [ctx.attr.package])
        else:
            toolchain = _coco_toolchain(ctx)
        return implementation(ctx, _popili_handle(ctx, toolchain, ctx.attr.package if package else None, test or executable))

    return rule(
        implementation = _impl,
        attrs = dict(own.items() + attrs.items()),
        cfg = popili_version_pin,
        doc = doc,
        provides = provides,
        test = test,
        executable = executable,
        **(COCO_TEST_RULE_ARGS if test else COCO_RUN_RULE_ARGS if executable else {"toolchains": [COCO_TOOLCHAIN_TYPE]})
    )

def _coco_package_verify(ctx, popili):
    # Build the verify command arguments
    arguments = [
        "verify",
        "--results-junit",
        "%%XML_OUTPUT_FILE%%" if _is_windows(ctx) else "$XML_OUTPUT_FILE",
    ]

    backend = ctx.attr._verification_backend[BuildSettingInfo].value
    if backend != "":
        arguments.append("--backend")
        arguments.append(backend)

    return DefaultInfo(
        executable = popili.script(arguments),
        runfiles = ctx.runfiles(transitive_files = popili.runfiles),
    )

_coco_verify_test = popili_rule(
    implementation = _coco_package_verify,
    attrs = {
        "_verification_backend": attr.label(default = Label("//:verification_backend")),
    },
    package = True,
    test = True,
)

def _coco_verify_test_macro_impl(name, visibility, **kwargs):
    _coco_verify_test(
        name = name,
        visibility = visibility,
        **kwargs
    )

coco_verify_test = macro(
    doc = """Creates a test that runs Coco verification on a package.

Executes `popili verify` on the specified coco_package, failing the test if
verification does not pass.""",
    inherit_attrs = _coco_verify_test,
    implementation = _coco_verify_test_macro_impl,
)

# Exported for use by cc.bzl and c.bzl
coco_cc_gen = _coco_cc_gen
coco_cc_pin = _coco_cc_pin

# Exported for testing
bat_set = _bat_set
mangle_name = _mangle_name
popili_rule_reserved_attribute = _popili_rule_reserved_attribute
missing_popili_message = _missing_popili_message
pin_transition_settings = _pin_transition_settings
version_source = _version_source
unpin_transition_settings = _unpin_transition_settings
effective_version = _effective_version
library_version_mismatch_message = _library_version_mismatch_message
library_version_conflict = _library_version_conflict
inherited_versions_conflict = _inherited_versions_conflict
package_versions_conflict = _package_versions_conflict
common_version = _common_version
package_transition_settings = _package_transition_settings
own_package_versions_message = _own_package_versions_message
toolchain_version_mismatch_message = _toolchain_version_mismatch_message
compute_output_paths = _compute_output_paths
module_path_for = _module_path_for
