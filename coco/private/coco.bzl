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
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load(":common_attrs.bzl", "companion_attrs")
load(":platforms.bzl", "COCO_TOOLCHAIN_PLATFORMS")
load(":source_roots.bzl", "leaves_directory", "relative_path", "resolve_source_roots", "source_root_for")
load(":version_registry.bzl", "CocoVersionRegistryInfo")
load(":version_resolution.bzl", "LOCAL_VERSION", "PINNED_SOURCE", "VERSION_FLAG", "VERSION_SOURCE_SETTING", "license_protocol_version", "resolve_version_alias")

CocoPackageInfo = provider(
    doc = "Information about a Coco package",
    fields = {
        "dep_package_files": "All Coco.toml files for all transitive dependencies",
        "direct_srcs": "The .coco files that are direct sources of this package only",
        "direct_test_srcs": "The .coco files that are direct test_sources of this package only",
        "name": "The name of the package",
        "package_file": "The Coco.toml file for this package",
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
    },
)

CocoCcGeneratedInfo = provider(
    doc = "Generated C/C++ code from a Coco package",
    fields = {
        "headers": "Generated header files as a depset",
        "include_prefix": "The directory below include_root holding the files generated for package_dir, and the prefix of their includes",
        "include_root": "The directory the generated files' include paths are relative to, as an exec path",
        "package_dir": "The directory containing the package's Coco.toml, relative to the root of its repository",
        "popili_version": "The version of the popili that generated the code, as its toolchain declares it; \"\" when unknown",
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

COCO_TOOLCHAIN_TYPE_LABEL = "@rules_coco//coco:toolchain_type"

# Optional only so that `_coco_toolchain` can replace Bazel's generic "No matching toolchains
# found" with a message naming the version and the registered ones; every rule declaring it still
# needs a Coco toolchain.
COCO_TOOLCHAIN_TYPE = config_common.toolchain_type(COCO_TOOLCHAIN_TYPE_LABEL, mandatory = False)

# Test rules resolve popili on the `test` exec group, where Bazel runs the test action. Declaring
# the group replaces Bazel's default one, so where it exists (Bazel 9+) it also carries the default
# test toolchain type, which keeps tests on an execution platform matching the target platform, as
# Bazel does by default. WORKSPACE mode gets @bazel_features from Bazel 8's WORKSPACE suffix, which
# may predate the flag, hence getattr.
_DEFAULT_TEST_TOOLCHAIN_TYPE = "@bazel_tools//tools/test:default_test_toolchain_type"

# Whether Bazel keeps a test on an execution platform matching its target platform (Bazel 9+).
TESTS_FOLLOW_TARGET_PLATFORM = getattr(bazel_features.toolchains, "has_default_test_toolchain_type", False)

_DEFAULT_TEST_TOOLCHAINS = [
    config_common.toolchain_type(_DEFAULT_TEST_TOOLCHAIN_TYPE, mandatory = False),
] if TESTS_FOLLOW_TARGET_PLATFORM else []

# Passed to rule() by test rules, as `**COCO_TEST_RULE_ARGS`. The `platform` fragment comes with
# the exec group because `_coco_toolchain` reads it to name the test's target platform.
COCO_TEST_RULE_ARGS = {
    "exec_groups": {"test": exec_group(toolchains = [COCO_TOOLCHAIN_TYPE] + _DEFAULT_TEST_TOOLCHAINS)},
    "fragments": ["platform"],
}

# What a rule needs for `_coco_toolchain`'s full message: the configured version and the registry.
TOOLCHAIN_ATTRIBUTES = {
    "_version": attr.label(default = Label("//:version")),
    "_version_registry": attr.label(
        default = Label("@coco_toolchains//:registry"),
        providers = [CocoVersionRegistryInfo],
    ),
    "_version_source": attr.label(default = Label("//:_version_source")),
}

POPILI_VERSION_ATTRIBUTES = {
    "popili_version": attr.string(
        doc = "The registered popili version this target and everything beneath it, including the " +
              "coco_package it reads, run with: a version such as `\"1.5.1\"` or an alias such as " +
              "`\"stable\"`. It wins over `--@rules_coco//:version`. Empty (the default) uses the version " +
              "that flag selects, or the first registered version when the flag is unset too.",
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

def _pin_transition_settings(pin, version, registered_versions):
    """Decides what a popili-resolving rule's transition changes.

    Args:
        pin: The target's `popili_version`, "" when unpinned or the rule has none.
        version: The value of `--@rules_coco//:version` in the incoming configuration.
        registered_versions: The hub's registered versions in registration order.

    Returns:
        The dict the transition returns: `{}` without a pin or when the pin (aliases resolved)
        is the version the incoming configuration effectively asks for, so the configuration and
        its output paths are shared; else the version flag set to the resolved pin, with the
        source setting recording that a pin set it.
    """
    if not pin:
        return {}
    resolved = resolve_version_alias(pin)
    if resolved == _effective_version(version, registered_versions):
        return {}
    return {VERSION_FLAG: resolved, VERSION_SOURCE_SETTING: PINNED_SOURCE}

def _popili_version_pin_impl(settings, attr):
    return _pin_transition_settings(
        getattr(attr, "popili_version", ""),
        settings[VERSION_FLAG],
        settings[_REGISTERED_VERSIONS_SETTING],
    )

popili_version_pin = transition(
    implementation = _popili_version_pin_impl,
    inputs = [VERSION_FLAG, _REGISTERED_VERSIONS_SETTING],
    outputs = [VERSION_FLAG, VERSION_SOURCE_SETTING],
)

def _popili_version_transition_impl(_settings, attr):
    """Transition implementation for per-target popili version selection.

    If the target specifies a version attribute, transition to that version.
    Version aliases (like "stable") are resolved to actual version numbers.
    Otherwise, keep the current configuration's version setting.
    """
    if hasattr(attr, "version") and attr.version:
        resolved_version = resolve_version_alias(attr.version)
        return {VERSION_FLAG: resolved_version}
    return {}

_popili_version_transition = transition(
    implementation = _popili_version_transition_impl,
    inputs = [],
    outputs = [VERSION_FLAG],
)

# Export for use in cc.bzl
popili_version_transition = _popili_version_transition

def _with_popili_version_impl(ctx):
    """Wrapper rule that applies popili version transition to a target.

    This allows users to build a specific target with a different popili version
    than the default specified by --@rules_coco//:version.
    """

    # When using configuration transitions, ctx.attr.target becomes a list
    target = ctx.attr.target[0] if type(ctx.attr.target) == type([]) else ctx.attr.target

    # Forward all providers from the target
    # We need to explicitly check for each provider type and forward them
    providers = []

    # Forward DefaultInfo if present
    if hasattr(target, "files"):
        providers.append(target[DefaultInfo])

    # Forward CocoPackageInfo if present
    if CocoPackageInfo in target:
        providers.append(target[CocoPackageInfo])

    # Forward language-specific generated code providers if present
    if CocoCcGeneratedInfo in target:
        providers.append(target[CocoCcGeneratedInfo])
    if CocoCSharpGeneratedInfo in target:
        providers.append(target[CocoCSharpGeneratedInfo])

    # Forward CcInfo if present
    if CcInfo in target:
        providers.append(target[CcInfo])

    # Forward OutputGroupInfo if present
    if OutputGroupInfo in target:
        providers.append(target[OutputGroupInfo])

    return providers

with_popili_version = rule(
    implementation = _with_popili_version_impl,
    attrs = {
        "target": attr.label(
            mandatory = True,
            doc = "The target to build with a specific popili version",
        ),
        "version": attr.string(
            mandatory = True,
            doc = "The popili version to use (e.g., '1.5.0', '1.4.7')",
        ),
    },
    cfg = _popili_version_transition,
    doc = """Wrapper rule to build a target with a specific popili version.

    Use this when you need to build different targets with different popili versions
    in the same build. For most cases, just use --@rules_coco//:version=X.Y.Z.

    Example:
        coco_package(name = "pkg", ...)

        with_popili_version(
            name = "pkg_v147",
            target = ":pkg",
            version = "1.4.7",
        )
    """,
)

# License files are now obtained from the toolchain, not passed as attributes

def _resolves_on_test_exec_group(ctx):
    # Every test rule has a `test` exec group; only those with COCO_TEST_RULE_ARGS resolve popili on it.
    return "test" in ctx.exec_groups and COCO_TOOLCHAIN_TYPE_LABEL in ctx.exec_groups["test"].toolchains

def _coco_toolchain(ctx):
    """Returns the resolved Coco toolchain, failing with a specific message when there is none."""
    if _resolves_on_test_exec_group(ctx):
        toolchain = ctx.exec_groups["test"].toolchains[COCO_TOOLCHAIN_TYPE_LABEL]
    else:
        toolchain = ctx.toolchains[COCO_TOOLCHAIN_TYPE_LABEL]
    if toolchain == None:
        fail(_missing_toolchain_message(ctx))
    return toolchain

def _version_source(version, pin, source):
    """Words where a target's configured popili version came from.

    Args:
        version: The value of `--@rules_coco//:version` in the target's configuration.
        pin: The target's `popili_version`, "" when it has none.
        source: The value of the `_version_source` setting: PINNED_SOURCE beneath a pin, else "".

    Returns:
        A phrase interpolated as "(%s)" in messages: "pinned by popili_version" (naming the pin as
        written when it is an alias, or the fact that the pin sits on a target above this one),
        "set by --@rules_coco//:version", or "the default".
    """
    if pin:
        if pin == version:
            return "pinned by popili_version"
        return "pinned by popili_version = %r" % pin
    if source == PINNED_SOURCE:
        return "pinned by popili_version on a target above it"
    if version:
        return "set by --%s" % VERSION_FLAG
    return "the default"

def _configured_version(ctx):
    """Returns the popili version this target's configuration asks for and where it came from.

    Returns:
        A (version, source) pair: the value of `--@rules_coco//:version`, or "" for the default,
        and the phrase `_version_source` words for it.
    """
    version = ctx.attr._version[BuildSettingInfo].value
    source = getattr(ctx.attr, "_version_source", None)
    return version, _version_source(
        version,
        getattr(ctx.attr, "popili_version", ""),
        source[BuildSettingInfo].value if source else "",
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

def _register_versions_hint(what):
    return (
        "Register %s with coco.toolchain(versions = [...]) in MODULE.bazel or " % what +
        "coco_repositories(versions = [...]) in WORKSPACE."
    )

_REGISTER_LOCAL_HINT = (
    "Register a popili distribution from the local filesystem with coco.local_toolchain(popili = ...) " +
    "in MODULE.bazel or coco_local_repositories(path = ...) / coco_repositories(local_popili = ...) in WORKSPACE."
)

def _missing_popili_message(label, version, source, registry, test_target_platform = None):
    """Words the failure of a rule whose Coco toolchain did not resolve.

    Decided after toolchain resolution, so it never second-guesses resolution: the registry is
    consulted only to say what is registered and what to do about it.

    Args:
        label: The failing target's label.
        version: The configured version ("" for the default), as `_configured_version` returns it.
        source: Where the version came from, as `_configured_version` phrases it.
        registry: The hub's `CocoVersionRegistryInfo` (or any struct with its fields).
        test_target_platform: For a test that lost popili to the execution platform Bazel runs
            tests on, its target platform, as `_test_target_platform` returns it; else None.

    Returns:
        The message to fail with.
    """
    registered = "Registered popili versions: %s." % _describe_registered_versions(registry)
    published = ", ".join(["%s/%s" % platform for platform in COCO_TOOLCHAIN_PLATFORMS])

    if version == LOCAL_VERSION:
        if LOCAL_VERSION not in registry.versions:
            return (
                "%s needs the local popili (%s), but no local Coco toolchain is registered. %s %s" %
                (label, source, registered, _REGISTER_LOCAL_HINT)
            )
        if test_target_platform:
            return (
                "%s needs the local popili (%s), which only runs on the host platform (%s), but Bazel " %
                (label, source, ", ".join([str(constraint) for constraint in registry.host_constraints])) +
                "runs a test on an execution platform matching the test's target platform (%s), and " % test_target_platform +
                "no registered execution platform both matches it and is the host. Build the test for the " +
                "host platform (--platforms=@platforms//host), with the host registered as an execution " +
                "platform (--extra_execution_platforms=@platforms//host), or select a published release, which runs " +
                "on %s. %s" % (published, registered)
            )
        return (
            "%s needs the local popili (%s), but it only runs on the host platform (%s) and no " %
            (label, source, ", ".join([str(constraint) for constraint in registry.host_constraints])) +
            "registered execution platform is the host. Register the host as an execution platform " +
            "(--extra_execution_platforms=@platforms//host), or select a published release, which runs " +
            "on %s. %s" % (published, registered)
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
            "%s needs popili %s (%s), but no registered Coco toolchain provides it. %s %s " %
            (label, version, source, registered, _register_versions_hint("it")) +
            "A bring-your-own coco_toolchain is selected by a version only when its toolchain() has " +
            "target_settings for that version."
        )

    if test_target_platform:
        return (
            "%s needs popili %s (%s), which is registered, but Bazel runs a test on an execution platform " %
            (label, version, source) +
            "matching the test's target platform (%s), and no registered execution platform both " % test_target_platform +
            "matches it and can run popili, which is published for %s. Build the test for one of these, " % published +
            "register an execution platform that matches the target platform and is one of these " +
            "(--extra_execution_platforms), or bring your own coco_toolchain for such a platform. %s" % registered
        )

    return (
        "%s needs popili %s (%s), which is registered, but none of the registered execution platforms " %
        (label, version, source) +
        "can run it: popili is published for %s. Register an execution platform of one of these " % published +
        "(--extra_execution_platforms), or bring your own coco_toolchain for the execution platform you " +
        "have. %s" % registered
    )

def _test_target_platform(ctx):
    """The target platform of a test that lost popili to Bazel's choice of test platform, else None.

    The `test` exec group takes the execution platform resolving the most of its toolchains, so a
    resolved default test toolchain without a Coco toolchain means that no execution platform the
    test may run on (by default, those matching its target platform) can run popili.
    """
    if not _resolves_on_test_exec_group(ctx) or not _DEFAULT_TEST_TOOLCHAINS:
        return None
    if ctx.exec_groups["test"].toolchains[_DEFAULT_TEST_TOOLCHAIN_TYPE] == None:
        return None
    return str(ctx.fragments.platform.platform)

def _missing_toolchain_message(ctx):
    # A custom rule may declare COCO_TOOLCHAIN_TYPE without TOOLCHAIN_ATTRIBUTES, which the full message needs.
    if not hasattr(ctx.attr, "_version_registry"):
        return (
            "%s needs a Coco toolchain, but no toolchain of type %s resolved." %
            (ctx.label, COCO_TOOLCHAIN_TYPE_LABEL)
        )
    version, source = _configured_version(ctx)
    registry = ctx.attr._version_registry[CocoVersionRegistryInfo]
    return _missing_popili_message(ctx.label, version, source, registry, _test_target_platform(ctx))

def _runtime_path(file, is_test):
    return file.short_path if is_test else file.path

def _runtime_dirname(file, is_test):
    # File.dirname, but via the runtime path (short_path for tests) so
    # external-repo deps resolve in the runfiles tree; "." avoids an empty arg.
    return paths.dirname(_runtime_path(file, is_test)) or "."

def _coco_startup_args(ctx, package, is_test):
    """Build startup arguments for popili.

    Args:
        ctx: Rule context
        package: The coco_package target with CocoPackageInfo, a struct with package_file
                 and dep_package_files fields, or None for base args only
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
        # Support both CocoPackageInfo providers (targets) and structs with the same fields
        if hasattr(package, "package_file"):
            # It's a struct
            package_file = package.package_file
            dep_package_files = package.dep_package_files
        else:
            # It's a target with CocoPackageInfo provider
            package_file = package[CocoPackageInfo].package_file
            dep_package_files = package[CocoPackageInfo].dep_package_files
        arguments += [
            "--package",
            _runtime_dirname(package_file, is_test),
        ]
        for dep_file in dep_package_files.to_list():
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
    reads. A toolchain whose version is unknown (the local toolchain, a bring-your-own
    toolchain without `popili_version`) gets the file of the newest protocol version.
    """
    toolchain = _coco_toolchain(ctx)
    name = "licenses_%d.lic" % (toolchain.license_protocol_version or license_protocol_version(toolchain.popili_version))
    files = [
        file
        for file in ctx.attr._license_files_local[DefaultInfo].files.to_list()
        if file.basename == name
    ]
    return files[0] if files else None

def _coco_env(ctx):
    env = {}

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
        direct.append(package[CocoPackageInfo].package_file)
        transitive.append(package[CocoPackageInfo].srcs)
        transitive.append(package[CocoPackageInfo].test_srcs)
        transitive.append(package[CocoPackageInfo].dep_package_files)
        transitive.append(package[CocoPackageInfo].workspace_files)

        # Include typecheck marker if present to ensure codegen waits for typecheck
        if package[CocoPackageInfo].typecheck_marker:
            direct.append(package[CocoPackageInfo].typecheck_marker)
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
        env = _coco_env(ctx),
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

def _create_coco_wrapper_script(ctx, package, arguments):
    """Creates a platform-specific wrapper script for running Coco commands.

    Args:
        ctx: The rule context
        package: The coco_package target (or None)
        arguments: List of command arguments (after startup args)

    Returns:
        The wrapper script file
    """
    coco_path = _coco_toolchain(ctx).coco.short_path
    is_windows = _is_windows(ctx)
    if is_windows:
        coco_path = coco_path.replace("/", "\\")

    # Build the full command
    full_arguments = [coco_path] + _coco_startup_args(ctx, package, True) + arguments
    command = " ".join(full_arguments)
    env = _coco_env(ctx)

    # Create platform-specific wrapper script
    if is_windows:
        wrapper_script = ctx.actions.declare_file(ctx.label.name + "-cmd.bat")
        wrapper_lines = []
        for k, v in env.items():
            wrapper_lines.append("SET %s=\"%s\"" % (k, v))
        wrapper_lines.append("")
        wrapper_lines.append(command)
    else:
        wrapper_script = ctx.actions.declare_file(ctx.label.name + "-cmd.sh")
        wrapper_lines = [
            "#!/usr/bin/env bash",
            "exec env \\",
        ]
        for k, v in env.items():
            wrapper_lines.append("  %s=\"%s\" \\" % (k, v))
        wrapper_lines.append(command)

    ctx.actions.write(
        output = wrapper_script,
        content = "\n".join(wrapper_lines),
        is_executable = True,
    )

    return wrapper_script

# Export helper functions for use by other private modules (e.g., format.bzl, diagram.bzl)
# These are implementation details and should not be used by end users
create_coco_wrapper_script = _create_coco_wrapper_script
coco_runfiles = _coco_runfiles
coco_toolchain_or_fail = _coco_toolchain
run_coco = _run_coco
coco_startup_args = _coco_startup_args
coco_env = _coco_env
get_license_file_from_toolchain = _get_license_file_from_toolchain

def _run_typecheck(ctx, package, srcs, test_srcs):
    """Run typecheck and produce a marker file on success.

    Args:
        ctx: Rule context
        package: Struct with package_file and dep_package_files fields
        srcs: Source files depset
        test_srcs: Test source files depset

    Returns:
        The typecheck marker file
    """

    # Create a marker file to track typecheck completion
    marker = ctx.actions.declare_file(ctx.label.name + ".typecheck")

    # Build startup arguments using the shared function
    startup_arguments = _coco_startup_args(ctx, package = package, is_test = False)

    # Build typecheck command arguments
    typecheck_arguments = ["typecheck"]

    # Collect inputs
    license_file = _get_license_file_from_toolchain(ctx)
    inputs_direct = [
        package.package_file,
        _coco_toolchain(ctx).preferences_file,
    ]
    if license_file:
        inputs_direct.append(license_file)

    # Create wrapper script that runs typecheck and creates marker on success
    coco_path = _coco_toolchain(ctx).coco.path
    is_windows = _is_windows(ctx)
    if is_windows:
        coco_path = coco_path.replace("/", "\\")

    command = " ".join([coco_path] + startup_arguments + typecheck_arguments)
    env = _coco_env(ctx)

    if is_windows:
        script = ctx.actions.declare_file(ctx.label.name + "_typecheck.bat")
        script_lines = ["@echo off"]
        for k, v in env.items():
            script_lines.append("SET %s=\"%s\"" % (k, v))
        script_lines.append("%s || exit /b 1" % command)
        script_lines.append("type nul > \"%s\"" % marker.path.replace("/", "\\"))
    else:
        script = ctx.actions.declare_file(ctx.label.name + "_typecheck.sh")
        script_lines = ["#!/bin/bash", "set -e"]
        for k, v in env.items():
            script_lines.append("export %s=\"%s\"" % (k, v))
        script_lines.append(command)
        script_lines.append("touch \"%s\"" % marker.path)

    ctx.actions.write(output = script, content = "\n".join(script_lines), is_executable = True)

    ctx.actions.run(
        executable = script,
        tools = [_coco_toolchain(ctx).coco, script],
        mnemonic = "CocoTypecheck",
        progress_message = "Typechecking %s" % ctx.label.name,
        inputs = depset(direct = inputs_direct, transitive = [srcs, test_srcs, package.dep_package_files, package.workspace_files]),
        outputs = [marker],
        arguments = [],
    )

    return marker

def _require_coco_toml(file, attr):
    if file.basename != "Coco.toml":
        fail("%s must point to a file called exactly 'Coco.toml'" % attr.capitalize(), attr = attr)

def _coco_package_impl(ctx):
    _require_coco_toml(ctx.file.package, "package")

    # Without typecheck nothing below reads the toolchain.
    _coco_toolchain(ctx)
    package_file = ctx.file.package
    dep_package_files = depset(
        direct = [dep[CocoPackageInfo].package_file for dep in ctx.attr.deps],
        transitive = [dep[CocoPackageInfo].dep_package_files for dep in ctx.attr.deps],
    )
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
        package_struct = struct(
            package_file = package_file,
            dep_package_files = dep_package_files,
            workspace_files = workspace_files,
        )
        typecheck_marker = _run_typecheck(ctx, package_struct, srcs, test_srcs)

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
            source_roots = source_roots,
            srcs = srcs,
            test_source_roots = test_source_roots,
            test_srcs = test_srcs,
            typecheck_marker = typecheck_marker,
            workspace_files = workspace_files,
        ),
        DefaultInfo(files = depset(direct = default_files_direct, transitive = [srcs, test_srcs, dep_package_files, workspace_files])),
    ]

_coco_package = rule(
    implementation = _coco_package_impl,
    attrs = dict(LICENSE_ATTRIBUTES.items() + TOOLCHAIN_ATTRIBUTES.items() + {
        "deps": attr.label_list(
            providers = [CocoPackageInfo],
            doc = "Other coco_package targets this package depends on.",
        ),
        "package": attr.label(
            mandatory = True,
            allow_single_file = [".toml"],
            doc = "Label pointing to the Coco.toml file for this package.",
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
`deps`, and may inherit shared settings from a coco_workspace via `workspace`.""",
    inherit_attrs = _coco_package,
    implementation = _coco_package_macro_impl,
)

def _coco_workspace_impl(ctx):
    _require_coco_toml(ctx.file.workspace, "workspace")

    parent_transitive = []
    if ctx.attr.parent:
        parent_transitive.append(ctx.attr.parent[CocoWorkspaceInfo].files)
    files = depset(direct = [ctx.file.workspace], transitive = parent_transitive)

    return [
        CocoWorkspaceInfo(
            files = files,
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

def _coco_package_verify(ctx):
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

    wrapper_script = _create_coco_wrapper_script(ctx, ctx.attr.package, arguments)

    return DefaultInfo(
        executable = wrapper_script,
        runfiles = ctx.runfiles(transitive_files = _coco_runfiles(ctx, ctx.attr.package, True)),
    )

_coco_verify_test = rule(
    implementation = _coco_package_verify,
    attrs = dict(LICENSE_ATTRIBUTES.items() + TOOLCHAIN_ATTRIBUTES.items() + POPILI_VERSION_ATTRIBUTES.items() + {
        "package": attr.label(
            providers = [CocoPackageInfo],
            mandatory = True,
            doc = "The coco_package target to verify.",
        ),
        "_verification_backend": attr.label(default = Label("//:verification_backend")),
    }.items()),
    cfg = popili_version_pin,
    test = True,
    **COCO_TEST_RULE_ARGS
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

def _workspace_dirname(short_path):
    """The directory of a file's short path, relative to the root of its own repository.

    Unlike File.dirname, this drops the bin dir of a generated file and the prefix of a file in
    another repository: external/<repo>/, or ../<repo>/ with --experimental_sibling_repository_layout.

    Args:
        short_path: A File.short_path, e.g. "pkg/Coco.toml" or "../dep+/pkg/Coco.toml"

    Returns:
        The directory, e.g. "pkg", or "" for the repository root
    """
    segments = short_path.split("/")
    if segments[0] == "..":
        segments = segments[2:]
    return "/".join(segments[:-1])

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

def _generated_include_dir(include_dir, package_dir, include_prefix):
    """Where a directory lies below a coco_generate's include root, if generated files can lie below it.

    The files generated for the package in package_dir lie below <root>/<include_prefix>. Where
    include_prefix and package_dir end in the same directories, the root also stands for the
    directories above them: with the default prefix, package_dir itself, the root stands for the
    workspace, so every directory maps.

    Args:
        include_dir: A directory, e.g. a cc_library's include, relative to the same root as package_dir
        package_dir: Directory containing the package's Coco.toml
        include_prefix: The generate's include prefix

    Returns:
        The directory relative to the include root, "" for the root itself, or None when it is
        not at or below the directory the root stands for
    """
    prefix = [s for s in include_prefix.split("/") if s]
    anchor = [s for s in package_dir.split("/") if s]
    for _ in range(min(len(prefix), len(anchor))):
        if prefix[-1] != anchor[-1]:
            break
        prefix = prefix[:-1]
        anchor = anchor[:-1]
    relative = relative_path(include_dir, "/".join(anchor))
    if leaves_directory(relative):
        return None
    return _join_path(prefix + [relative])

def _build_language_config(ctx, language):
    """Build configuration struct for code generation.

    Args:
        ctx: Rule context
        language: Language string ("cpp", "c", or "csharp")

    Returns:
        Struct containing language-specific configuration, or None for C#
    """
    if language == "cpp":
        return struct(
            file_name_mangler = ctx.attr.cpp_file_name_mangler,
            header_prefix = ctx.attr.cpp_header_file_prefix,
            header_extension = ctx.attr.cpp_header_file_extension,
            impl_prefix = ctx.attr.cpp_implementation_file_prefix,
            impl_extension = ctx.attr.cpp_implementation_file_extension,
            mocks = ctx.attr.mocks,
            flat_hierarchy = ctx.attr.cpp_flat_file_hierarchy,
        )
    elif language == "c":
        return struct(
            file_name_mangler = ctx.attr.c_file_name_mangler,
            header_prefix = ctx.attr.c_header_file_prefix,
            header_extension = ctx.attr.c_header_file_extension,
            impl_prefix = ctx.attr.c_implementation_file_prefix,
            impl_extension = ctx.attr.c_implementation_file_extension,
            mocks = ctx.attr.mocks,
            flat_hierarchy = ctx.attr.c_flat_file_hierarchy,
        )
    elif language == "csharp":
        return None  # C# doesn't use config struct
    else:
        fail("unrecognised language: " + language)

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
        config: Configuration struct (or None for C#)
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

        if ctx.attr.mocks:
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
        config: Language configuration struct (or None for C#)
        path_builder: Declares outputs below the output directory
        src: Source file
        package_dir: Directory containing the Coco.toml of the package src belongs to
        source_roots: Source roots of that package, which coco_package has checked cover src
    """
    source_root = source_root_for(relative_path(src.path, package_dir), source_roots)
    module_path = _module_path_for(src, package_dir, source_root)
    _declare_language_outputs(ctx, headers, sources, mock_headers, mock_sources, config, path_builder, module_path)

def _coco_package_generate_impl(ctx):
    toolchain = _coco_toolchain(ctx)
    if ctx.attr.language == "c" and ctx.attr.mocks:
        fail("mocks = True is not supported for language = \"c\": popili does not generate C mocks", attr = "mocks")

    # When using configuration transitions, ctx.attr.package becomes a list
    package = ctx.attr.package[0] if type(ctx.attr.package) == type([]) else ctx.attr.package
    info = package[CocoPackageInfo]
    srcs = info.direct_srcs
    test_srcs = info.direct_test_srcs
    package_dir = info.package_file.dirname
    workspace_dir = _workspace_dirname(info.package_file.short_path)
    include_prefix = _include_prefix(ctx, workspace_dir)

    headers = []
    sources = []
    mock_headers = []
    mock_sources = []
    test_headers = []
    test_sources = []

    # Generated files go below an include root of this target's own, at the include prefix (by
    # default the package directory's path in its repository), so "<include prefix>/Foo.h" can't resolve to
    # the same files built in another configuration or by another coco_generate, as it would below
    # a bin dir root.
    output_prefix = _join_path(["_coco", ctx.label.name])
    include_root = _join_path([ctx.bin_dir.path, ctx.label.workspace_root, ctx.label.package, output_prefix])
    config = _build_language_config(ctx, ctx.attr.language)
    path_builder = _make_path_builder(ctx, _join_path([output_prefix, include_prefix]))

    # Get the list of packages to regenerate based on language
    regenerate_pkgs = {
        "c": ctx.attr.c_regenerate_packages,
        "cpp": ctx.attr.cpp_regenerate_packages,
        "csharp": ctx.attr.csharp_regenerate_packages,
    }.get(ctx.attr.language, [])

    # Regenerated packages' files go into this package's output directory (using this package's
    # generator settings), with module paths relative to their own source roots.
    for regen_pkg in regenerate_pkgs:
        regen_info = regen_pkg[CocoPackageInfo]
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
    generated_dir = _join_path([include_root, include_prefix])
    arguments = [
        "generate-%s" % ctx.attr.language,
        "--output",
        generated_dir,
        "--test-output",
        generated_dir,
        "--output-empty-files",
        "--output-runtime=false",
    ]
    if ctx.attr.language == "cpp" or ctx.attr.language == "c":
        # Always passed, even when empty, so that one in Coco.toml cannot apply instead.
        arguments += [
            "--include-prefix",
            include_prefix,
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
        lang_providers = [
            CocoCcGeneratedInfo(
                headers = depset(headers),
                include_prefix = include_prefix,
                include_root = include_root,
                package_dir = workspace_dir,
                popili_version = getattr(toolchain, "popili_version", ""),
                sources = depset(sources),
                test_headers = depset(test_headers),
                test_sources = depset(test_sources),
            ),
            # For a cc_library listing this target in both srcs and deps.
            _generated_headers_cc_info(headers, include_root),
        ]
    elif ctx.attr.language == "csharp":
        lang_providers = [CocoCSharpGeneratedInfo(
            sources = depset(sources),
            test_sources = depset(test_sources),
        )]
    else:
        fail("Unsupported language: %s" % ctx.attr.language)

    return [
        DefaultInfo(
            files = depset(all_outputs),
        ),
    ] + lang_providers

def _include_prefix(ctx, workspace_dir):
    """The include_prefix attribute, or by default the Coco.toml directory's path in its repository."""
    if not ctx.attr.include_prefix_set:
        return workspace_dir
    prefix = ctx.attr.include_prefix
    if prefix and (paths.normalize(prefix) != prefix or paths.is_absolute(prefix) or leaves_directory(prefix)):
        fail("include_prefix must be a normalised relative path within the include root, such as \"my/pkg\", " +
             "not \"%s\"" % prefix, attr = "include_prefix")
    return prefix

def _generated_headers_cc_info(headers, include_root):
    """A CcInfo declaring generated headers, includable through their include root. Compiles nothing."""
    return CcInfo(compilation_context = cc_common.create_compilation_context(
        headers = depset(headers),
        quote_includes = depset([include_root]),
    ))

_coco_generate = rule(
    implementation = _coco_package_generate_impl,
    attrs = dict(LICENSE_ATTRIBUTES.items() + TOOLCHAIN_ATTRIBUTES.items() + POPILI_VERSION_ATTRIBUTES.items() + {
        # C output path options
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
        "c_regenerate_packages": attr.label_list(
            providers = [CocoPackageInfo],
            default = [],
            doc = "Other coco_package targets to regenerate with this target's C generator settings.",
        ),
        # C++ output path options
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
        "cpp_regenerate_packages": attr.label_list(
            providers = [CocoPackageInfo],
            default = [],
            doc = "Other coco_package targets to regenerate with this target's C++ generator settings.",
        ),
        "csharp_regenerate_packages": attr.label_list(
            providers = [CocoPackageInfo],
            default = [],
            doc = "Other coco_package targets to regenerate with this target's C# generator settings.",
        ),
        "include_prefix": attr.string(
            doc = "The path generated files are included by, such as `\"motor\"` for `#include \"motor/Foo.h\"`. " +
                  "Defaults to the path of the directory containing Coco.toml in its repository. Set a short " +
                  "prefix to shorten generated paths, or `\"\"` to include generated files by bare name. " +
                  "It overrides `generator.cpp.includePrefix` and `generator.c.includePrefix` in Coco.toml for " +
                  "this package's own generated code. Packages depending on this one still include its headers " +
                  "with the `includePrefix` in its Coco.toml, so set both to the same value; those packages then " +
                  "need no `includes`.",
        ),
        "include_prefix_set": attr.bool(
            doc = "Whether include_prefix was given; set by the coco_generate macro, as an unset string reads as \"\".",
        ),
        "language": attr.string(
            mandatory = True,
            values = ["cpp", "c", "csharp"],
            doc = "Target language for code generation: \"cpp\", \"c\", or \"csharp\".",
        ),
        "mocks": attr.bool(
            doc = "Generate mock implementations for testing. Disabled by default. Not supported for C.",
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
        return [
            DefaultInfo(files = depset(transitive = [info.test_headers, info.test_sources])),
            _generated_headers_cc_info(info.test_headers.to_list(), info.include_root),
        ]
    elif CocoCSharpGeneratedInfo in ctx.attr.package:
        info = ctx.attr.package[CocoCSharpGeneratedInfo]
        return [DefaultInfo(files = info.test_sources)]
    else:
        fail("Target %s does not provide CocoCcGeneratedInfo or CocoCSharpGeneratedInfo. " % ctx.attr.package.label +
             "It must be a coco_generate target.")

_coco_test_outputs = rule(
    implementation = _coco_test_outputs_impl,
    attrs = {
        "package": attr.label(
            mandatory = True,
        ),
    },
)

def coco_test_outputs_name(name):
    return "%s.tst" % name

def _library_version_mismatch_message(library, library_version, library_source, generator, generator_version):
    """Words the failure of a library whose runtime and generated code come from different popili versions.

    Args:
        library: The label of the coco_cc_library or coco_c_library.
        library_version: The popili version of the runtime the library links, as its toolchain declares it.
        library_source: Where the library's configured version came from, as `_configured_version` phrases it.
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

def _library_generators_mismatch_message(library, generated):
    """Words the failure of a library whose generated code comes from more than one popili version.

    Args:
        library: The label of the coco_cc_library or coco_c_library.
        generated: A (label, version) pair per coco_generate the library builds from, with the
            popili version that generated its code.

    Returns:
        The message to fail with.
    """
    return (
        "%s builds from code generated by more than one popili version: %s. " %
        (library, ", ".join(["%s (popili %s)" % (generator, version) for generator, version in generated])) +
        "A library and the code it builds from must come from the same popili version: pin these " +
        "coco_generate targets to the same version, or build each version into a library of its own."
    )

def _library_version_conflict(library, library_version, library_source, generated):
    """Checks that a library and all the code it builds from come from one popili version.

    A version that is "" (a bring-your-own toolchain declaring none) matches anything, but
    generators that do declare one must still agree among themselves.

    Args:
        library: The label of the coco_cc_library or coco_c_library.
        library_version: The popili version of the runtime the library links, as its toolchain
            declares it.
        library_source: Where the library's configured version came from, as `_configured_version`
            phrases it.
        generated: A (label, version) pair per coco_generate the library builds from, in order, with
            the popili version that generated its code.

    Returns:
        The message to fail with, or None when they agree.
    """
    versioned = [(generator, version) for generator, version in generated if version]
    if library_version:
        for generator, version in versioned:
            if version != library_version:
                return _library_version_mismatch_message(library, library_version, library_source, generator, version)
    elif len({version: None for _, version in versioned}) > 1:
        return _library_generators_mismatch_message(library, versioned)
    return None

def _coco_cc_pin_impl(ctx):
    """Checks a library's generated code against the runtime of the library's popili version.

    Analysed at the library's `popili_version`, so the generators beneath it follow that pin
    unless they have one of their own, and the runtime it forwards is the pinned version's.
    """
    toolchain = _coco_toolchain(ctx)
    _, source = _configured_version(ctx)
    conflict = _library_version_conflict(
        ctx.label.same_package_label(ctx.attr.library),
        getattr(toolchain, "popili_version", ""),
        source,
        [(package.label, package[CocoCcGeneratedInfo].popili_version) for package in ctx.attr.packages],
    )
    if conflict:
        fail(conflict)
    return [ctx.attr.runtime[CcInfo]]

# Runs no actions: only the runtime is built at the library's pin. The library compiles the
# generated code in its own configuration, through _coco_cc_gen. One per library, so that it sees
# every generator the library builds from.
_coco_cc_pin = rule(
    implementation = _coco_cc_pin_impl,
    attrs = dict(TOOLCHAIN_ATTRIBUTES.items() + POPILI_VERSION_ATTRIBUTES.items() + {
        "library": attr.string(
            mandatory = True,
            doc = "The name of the library in this package, for messages.",
        ),
        "packages": attr.label_list(
            providers = [CocoCcGeneratedInfo],
            mandatory = True,
            doc = "The coco_generate targets the library builds from.",
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
    """Extracts generated C/C++ sources and headers, providing CcInfo for headers and the runtime.

    Returns DefaultInfo with sources (+ private headers) for cc_library srcs,
    and CcInfo with public headers and the runtime for cc_library deps.
    """

    # A list, as for any attribute with a transition.
    gen_info = ctx.attr.package[0][CocoCcGeneratedInfo]

    if ctx.attr.use_test_outputs:
        all_headers = gen_info.test_headers.to_list()
        sources = gen_info.test_sources.to_list()
    else:
        all_headers = gen_info.headers.to_list()
        sources = gen_info.sources.to_list()

    if ctx.attr.all_hdrs_public:
        public_hdrs = all_headers
        private_hdrs = []
    else:
        patterns = ctx.attr.public_hdrs
        public_hdrs = []
        private_hdrs = []
        for h in all_headers:
            matched = False
            for p in patterns:
                if "/" in p:
                    if h.short_path.endswith(p):
                        matched = True
                        break
                elif h.basename == p:
                    matched = True
                    break
            if matched:
                public_hdrs.append(h)
            else:
                private_hdrs.append(h)

    # Export the generate's include root, and the library's `includes` below it, which cc_library
    # only applies below its own bin dir. Below the root, paths are relative to the repository root,
    # as for the generated files. Includes no generated file can lie below are dropped.
    root = gen_info.include_root
    includes = []
    for include in ctx.attr.includes:
        include_dir = _generated_include_dir(
            _join_path([ctx.label.package, include]),
            gen_info.package_dir,
            gen_info.include_prefix,
        )
        if include_dir != None:
            includes.append(_join_path([root, include_dir]))
    compilation_context = cc_common.create_compilation_context(
        headers = depset(public_hdrs),
        quote_includes = depset([root]),
        includes = depset(includes),
    )

    return [
        DefaultInfo(files = depset(sources + private_hdrs)),
        # Direct, as when the runtime was in the library's own deps, for layering_check.
        cc_common.merge_cc_infos(direct_cc_infos = [
            CcInfo(compilation_context = compilation_context),
            ctx.attr.pinned[CcInfo],
        ]),
    ]

_coco_cc_gen = rule(
    implementation = _coco_cc_gen_impl,
    attrs = {
        "all_hdrs_public": attr.bool(default = True),
        "includes": attr.string_list(
            doc = "The consuming cc_library's `includes`, applied below the generated files' include root too.",
        ),
        "package": attr.label(
            providers = [CocoCcGeneratedInfo],
            mandatory = True,
            # The library's _coco_cc_pin applies the same transition with the same popili_version,
            # so this is the coco_generate it checked, analysed once.
            cfg = popili_version_pin,
            doc = "The coco_generate, analysed at the library's popili_version.",
        ),
        "pinned": attr.label(
            providers = [CcInfo],
            mandatory = True,
            doc = "The library's _coco_cc_pin, for the runtime and the version check.",
        ),
        "popili_version": attr.string(doc = "The library's popili_version, for the transition on `package`."),
        "public_hdrs": attr.string_list(
            default = [],
            doc = "Header names to make public (when all_hdrs_public is False). " +
                  "Use bare filenames (e.g., 'ISensor.h') to match by name, or " +
                  "path suffixes (e.g., 'sensors/ISensor.h') to disambiguate.",
        ),
        "use_test_outputs": attr.bool(default = False, doc = "If True, extract test/mock outputs instead of regular outputs"),
    },
)

def _coco_generate_macro_impl(name, visibility, **kwargs):
    # Generator attrs are inherited from _coco_generate and forwarded via kwargs. Inherited attrs
    # are None when not set, which tells an unset include_prefix from "".
    _coco_generate(
        name = name,
        visibility = visibility,
        include_prefix_set = kwargs.get("include_prefix") != None,
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

The generated files can then be compiled into libraries or executables using
standard build rules (e.g., cc_library for C/C++).

The generator configuration options (file extensions, prefixes, etc.) must
match the settings in your Coco.toml file under the corresponding generator
section (e.g., [generator.cpp] for C++, [generator.c] for C).

Alongside the main code-generation target, a companion `<name>.tst` target is
created that exposes the generated test sources and headers.""",
    attrs = {"include_prefix_set": None},
    inherit_attrs = _coco_generate,
    implementation = _coco_generate_macro_impl,
)

def _popili_version_alias_impl(ctx):
    toolchain = _coco_toolchain(ctx)
    return [
        toolchain,
        platform_common.TemplateVariableInfo({
            "POPILI": toolchain.coco.short_path,
            "POPILI_STARTUP_ARGS": " ".join(_coco_startup_args(ctx, None, True)),
        }),
        DefaultInfo(
            runfiles = ctx.runfiles(transitive_files = _coco_runfiles(ctx, None, True)),
        ),
    ]

_popili_version_alias = rule(
    attrs = dict(LICENSE_ATTRIBUTES.items() + TOOLCHAIN_ATTRIBUTES.items()),
    implementation = _popili_version_alias_impl,
    cfg = popili_version_pin,
    toolchains = [COCO_TOOLCHAIN_TYPE],
)

def popili_version_alias(name, **kwargs):
    """Creates a target that provides access to the Coco toolchain via template variables.

    This rule creates template variables that can be used in genrules or other rules
    to access popili and its startup arguments:
    - $(POPILI): Path to the popili executable
    - $(POPILI_STARTUP_ARGS): Standard startup arguments for popili

    This is typically used for custom build rules that need direct access to the
    Coco toolchain.

    Args:
        name: Name of the alias target
        **kwargs: Additional Bazel arguments (e.g., visibility, tags)
    """
    _popili_version_alias(
        name = name,
        **kwargs
    )

# Exported for use by cc.bzl and c.bzl
coco_cc_gen = _coco_cc_gen
coco_cc_pin = _coco_cc_pin

# Exported for testing
mangle_name = _mangle_name
missing_popili_message = _missing_popili_message
pin_transition_settings = _pin_transition_settings
effective_version = _effective_version
library_version_mismatch_message = _library_version_mismatch_message
library_version_conflict = _library_version_conflict
version_source = _version_source
compute_output_paths = _compute_output_paths
module_path_for = _module_path_for
workspace_dirname = _workspace_dirname
generated_include_dir = _generated_include_dir
