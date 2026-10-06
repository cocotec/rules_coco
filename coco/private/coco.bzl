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

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load(":common_attrs.bzl", "companion_attrs")
load(":platforms.bzl", "EXEC_PLATFORM_KEYS")
load(":version_registry.bzl", "CocoVersionRegistryInfo", "format_registered_versions")
load(":version_resolution.bzl", "FORCE_VERSION_FLAG", "VERSION_FLAG", "resolve_version_alias")

CocoPackageInfo = provider(
    doc = "Information about a Coco package",
    fields = {
        "dep_package_files": "All Coco.toml files for all transitive dependencies",
        "direct_srcs": "The .coco files that are direct sources of this package only",
        "direct_test_srcs": "The .coco files that are direct test_sources of this package only",
        "name": "The name of the package",
        "package_file": "The Coco.toml file for this package",
        "popili_error": "Why this package's consumers cannot run popili, or None: there is no popili of its " +
                        "version for their execution platform, or its licence mode reads a licence on the host " +
                        "and that is not where they run. A consumer fails with it when it does run popili",
        "popili_pinned": "Whether this package's popili version comes from a popili_version pin on the package or its workspace",
        "popili_pinned_by": "Label of the coco_package or coco_workspace whose pin decided the version, or None when unpinned",
        "popili_pins": "Depset of struct(label, pinned_by, version) for every pinned package among this package and its transitive dependencies",
        "popili_toolchain": "The Coco ToolchainInfo the rules consuming this package run popili with: the " +
                            "package's version, built for the target platform of the configuration the package " +
                            "was analysed in. Consumers depend on the package through an exec transition, so for " +
                            "them that is their own execution platform. None when no popili of the version is " +
                            "registered for that platform",
        "popili_version": "The popili version of this package, e.g. '1.5.1' or 'local'. Under --@rules_coco//:force_version this is the forced version, not the pin",
        "popili_warnings": "List of warnings about pinned dependencies being used with a different popili version",
        "srcs": "All .coco files that are sources of this package or any of its transitive dependencies",
        "test_srcs": "All .coco files that are test_sources of this package or any of its transitive dependencies",
        "typecheck_marker": "Marker file indicating typecheck passed (or None if typecheck disabled)",
        "workspace_files": "Coco.toml files for any enclosing workspaces of this package or its transitive dependencies",
    },
)

CocoWorkspaceInfo = provider(
    doc = "Information about a Coco workspace root whose shared settings flow down to member packages",
    fields = {
        "files": "Coco.toml files a member must ship: this workspace's root manifest plus any parent workspaces",
        "popili_pinned_by": "Label of the coco_workspace whose pin decided popili_version, or None when unpinned",
        "popili_toolchain": "The Coco ToolchainInfo of popili_version for the target platform of the configuration this workspace was analysed in, or None when unpinned or not published for it",
        "popili_version": "The popili_version pinned by this workspace or a parent workspace, aliases resolved, or '' when unpinned. This is the pin as declared; under --@rules_coco//:force_version, popili_toolchain is the forced version instead",
    },
)

CocoCcGeneratedInfo = provider(
    doc = "Generated C/C++ code from a Coco package",
    fields = {
        "headers": "Generated header files as a depset",
        "popili_version": "The popili version the code was generated with, or '' if unknown",
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
    "_license_file_local": attr.label(default = Label("@io_cocotec_licensing_local//:licenses")),
    "_license_source": attr.label(default = Label("//:license_source")),
    "_license_token": attr.label(default = Label("//:license_token")),
}

# The toolchain type every popili is registered for (see toolchain_hub.bzl). It constrains the
# target platform. A rule never runs the popili it resolves itself: it reaches the target that
# resolves it through an exec transition, so that target's platform is the rule's execution
# platform, and the binary runs where the rule's actions run. A coco_package resolves it and
# forwards it to its consumers in CocoPackageInfo.popili_toolchain; coco_resolved_popili does the
# same for rules running popili in their own configuration (a package's typecheck, the version
# alias, licence acquisition).
COCO_TOOLCHAIN_TYPE = "@rules_coco//coco:toolchain_type"

# Optional: a package built for a platform popili is not published for (cross-compiling) forwards
# None, and only a consumer that actually runs popili fails, with a message saying why.
POPILI_TOOLCHAINS = [
    config_common.toolchain_type(COCO_TOOLCHAIN_TYPE, mandatory = False),
]

def _pinned_version(pin, force, current):
    """Returns the value of --@rules_coco//:version to resolve a pinned toolchain in.

    Args:
        pin: The popili_version attribute as written by the user, possibly an alias, or "".
        force: The value of --@rules_coco//:force_version.
        current: The current value of --@rules_coco//:version.

    Returns:
        The resolved pin, or `current` when forced or unpinned.
    """
    if force or not pin:
        return current
    return resolve_version_alias(pin)

def _pin_transition_impl(settings, attr):
    return {VERSION_FLAG: _pinned_version(
        attr.popili_version,
        settings[FORCE_VERSION_FLAG],
        settings[VERSION_FLAG],
    )}

# The rule transition of coco_package and coco_workspace: a pinned target is analysed in the
# configuration of its pin, so the toolchains it resolves, and its typecheck, are the pinned
# version's. Nothing above it is affected: its consumers stay in their own configuration and
# take the toolchain it forwards.
_pin_transition = transition(
    implementation = _pin_transition_impl,
    inputs = [VERSION_FLAG, FORCE_VERSION_FLAG],
    outputs = [VERSION_FLAG],
)

def _force_version_transition_impl(_settings, attr):
    return {
        FORCE_VERSION_FLAG: True,
        VERSION_FLAG: resolve_version_alias(attr.version),
    }

_force_version_transition = transition(
    implementation = _force_version_transition_impl,
    inputs = [],
    outputs = [VERSION_FLAG, FORCE_VERSION_FLAG],
)

_POPILI_PIN_ATTRS = {
    "popili_version": attr.string(
        doc = "The popili version to use for this target, e.g. '1.5.1' or 'stable'. The version " +
              "must be registered in coco.toolchain (bzlmod) or coco_repositories (WORKSPACE). " +
              "Overridden by --@rules_coco//:force_version and with_popili_version.",
    ),
    "_force_version_flag": attr.label(default = Label("//:force_version")),
    "_popili_registry": attr.label(
        default = Label("@coco_toolchains//versions"),
        providers = [CocoVersionRegistryInfo],
    ),
    "_version_flag": attr.label(default = Label("//:version")),
}

def _single(attr_value):
    # An attribute with a transition is a list, even for a 1:1 transition.
    return attr_value[0] if type(attr_value) == type([]) else attr_value

def _toolchain_version(toolchain):
    return getattr(toolchain, "version", "") or ""

def _configured_version(ctx, registry):
    """Returns the popili version this configuration selects: the version flag, else the default."""
    return ctx.attr._version_flag[BuildSettingInfo].value or registry.default

def _check_resolved_popili(ctx, toolchain, pin):
    """Fails with a clear message when the version `ctx` asks for is not registered.

    A registered version may still resolve no toolchain: the configuration's target platform
    is one popili is not published for, as when cross-compiling, or when a consumer on such an
    execution platform reaches the package. That is not an error here; the consumer that
    actually runs popili reports it (see _popili_error).

    Args:
        ctx: The rule context of a coco_package or coco_workspace, in the configuration its
            pin transition produced.
        toolchain: The Coco ToolchainInfo it resolved, or None.
        pin: The resolved popili_version pin, or "" when unpinned.
    """
    registry = ctx.attr._popili_registry[CocoVersionRegistryInfo]
    how_to_register = (
        "Registered versions: %s. Register more with coco.toolchain(versions = [...]) in " % format_registered_versions(registry) +
        "MODULE.bazel, or coco_repositories(versions = [...]) in WORKSPACE."
    )

    # A toolchain declaring the pinned version is fine even if the hub doesn't know it,
    # e.g. a bring-your-own toolchain with `version` set.
    if pin and pin not in registry.versions and _toolchain_version(toolchain) != pin:
        fail("%s pins popili_version %r, which is not registered. %s" % (ctx.label, pin, how_to_register))

    if toolchain != None:
        return

    forced = ctx.attr._force_version_flag[BuildSettingInfo].value
    if pin and not forced:
        # Registered, but not published for this configuration's platform.
        return
    requested = ctx.attr._version_flag[BuildSettingInfo].value
    if requested and requested not in registry.versions:
        source = "forced by --@rules_coco//:force_version or with_popili_version" if forced else "set by --@rules_coco//:version"
        fail("%s needs popili %r (%s), but no Coco toolchain for it is registered. %s" % (ctx.label, requested, source, how_to_register))
    if not requested and not registry.default:
        fail("%s needs a Coco toolchain, but none is registered. %s" % (ctx.label, how_to_register))

def _popili_error(ctx, toolchain, version, registry):
    """Returns why this package's consumers cannot run popili, or None.

    The package is analysed, through its consumers' exec transition, with their execution
    platform as its target platform, so this is where that platform is known. The consumers
    fail with the message when they do run popili; a package merely built, e.g. for a target
    platform popili is not published for, is fine.

    Args:
        ctx: The coco_package's rule context.
        toolchain: The Coco ToolchainInfo it forwards, or None.
        version: The package's popili version.
        registry: The hub's CocoVersionRegistryInfo.

    Returns:
        A message, or None.
    """
    if toolchain == None:
        return (
            "runs popili %s for %s on its execution platform, but no Coco toolchain of that version is " +
            "registered for it. rules_coco publishes popili for %s; see the README sections \"Popili " +
            "Version\", \"Remote execution\" and \"Bring your own toolchain\"."
        ) % (version, ctx.label, ", ".join(EXEC_PLATFORM_KEYS))

    # local_acquire and local_user read a licence acquired or installed on the machine running
    # Bazel. Sending it to another execution platform would be wrong whether or not popili
    # accepted it there, so with heterogeneous remote execution those modes are refused.
    license_source = _get_license_source(ctx, toolchain)
    platform = getattr(toolchain, "platform", "")
    if license_source in ("local_acquire", "local_user") and platform and registry.host and platform != registry.host:
        return (
            "runs popili for %s with license_source %r, which reads a licence on the host (%s), but its " +
            "execution platform is %s. Use license_source action_environment, action_file or token with " +
            "remote execution."
        ) % (ctx.label, license_source, registry.host, platform)
    return None

def _with_popili_version_impl(ctx):
    """Wrapper rule that builds a target, and everything below it, with a forced popili version."""
    registry = ctx.attr._popili_registry[CocoVersionRegistryInfo]
    version = resolve_version_alias(ctx.attr.version)
    if version not in registry.versions:
        fail("%s asks for popili version %r, which is not registered. Registered versions: %s." % (
            ctx.label,
            ctx.attr.version,
            format_registered_versions(registry),
        ))

    target = _single(ctx.attr.target)

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
            doc = "The target to build, together with everything below it, with the forced popili version.",
        ),
        "version": attr.string(
            mandatory = True,
            doc = "The popili version to use (e.g., '1.5.0', '1.5.1' or 'stable'). Must be registered.",
        ),
        "_popili_registry": attr.label(
            default = Label("@coco_toolchains//versions"),
            providers = [CocoVersionRegistryInfo],
        ),
    },
    cfg = _force_version_transition,
    doc = """Wrapper rule to build a target, and everything below it, with a specific popili version.

The version is forced: it overrides the `popili_version` pinned by any coco_package or
coco_workspace in the wrapped subgraph, exactly like building with
`--@rules_coco//:version=<version> --@rules_coco//:force_version`. Use it to check whether
an existing target also builds with another version without editing any pins.

Wrap the outermost target you want to rebuild: wrapping a `coco_cc_library` retargets the
code generation, the package, its dependencies and the runtime beneath it.

The wrapper forwards the wrapped target's `DefaultInfo`, `CocoPackageInfo`,
`CocoCcGeneratedInfo`, `CocoCSharpGeneratedInfo`, `CcInfo` and `OutputGroupInfo`, and
nothing else. So a target depending on the wrapper stays in its own configuration, but
uses what the wrapper forwards, at the forced version:

- a `coco_verify_test`, `coco_generate`, `coco_fmt_test` or diagram rule whose `package`
  is a wrapped coco_package runs the forced popili version;
- a `cc_library` or `cc_binary` depending on a wrapped `coco_cc_library` compiles against
  its code and links the runtime of the forced version.

The wrapper is neither a test nor executable, so wrapping a test or binary gives a target
that can only be built, not tested or run. To verify a package on another version, wrap
the package and point a `coco_verify_test` at the wrapper, as below, or run the test with
`--@rules_coco//:version=<version> --@rules_coco//:force_version`.

To generate code on another version, wrap the existing `coco_generate` (or the
`coco_cc_library` using it) rather than adding a second `coco_generate` for the wrapped
package: two `coco_generate` targets for the same package in the same BUILD package declare
the same output files. A wrapped one builds in a configuration of its own, so it doesn't clash.

Example:

```python
coco_package(name = "pkg", package = "Coco.toml", srcs = glob(["src/**/*.coco"]), popili_version = "1.5.0")

coco_generate(name = "pkg_cpp", package = ":pkg", language = "cpp")

# Generate and verify the same package on 1.5.1 as well, without touching its pin.
with_popili_version(
    name = "pkg_cpp_on_151",
    target = ":pkg_cpp",
    version = "1.5.1",
)

with_popili_version(
    name = "pkg_on_151",
    target = ":pkg",
    version = "1.5.1",
)

coco_verify_test(name = "pkg_verify_on_151", package = ":pkg_on_151")
```
""",
)

def _runtime_path(file, is_test):
    return file.short_path if is_test else file.path

def _runtime_dirname(file, is_test):
    # File.dirname, but via the runtime path (short_path for tests) so
    # external-repo deps resolve in the runfiles tree; "." avoids an empty arg.
    return paths.dirname(_runtime_path(file, is_test)) or "."

def _package_info(package):
    # Support both CocoPackageInfo providers (targets) and structs with the same fields
    return package if hasattr(package, "package_file") else package[CocoPackageInfo]

def _popili_toolchain(ctx, package):
    """Returns the popili a rule runs for `package`.

    That is the toolchain the package resolved (see coco_package), so every rule consuming a
    package runs the same popili version. The rule reaches the package through an exec
    transition, so the package was analysed with the rule's execution platform as its target
    platform, and the toolchain it forwards holds the binary built for that platform.

    Args:
        ctx: Rule context.
        package: A target with CocoPackageInfo, reached through an attribute with `cfg = "exec"`
            or `cfg = config.exec("test")`.

    Returns:
        The Coco ToolchainInfo.
    """
    info = _package_info(package)
    error = getattr(info, "popili_error", None)
    if error:
        fail("%s %s" % (ctx.label, error))
    toolchain = getattr(info, "popili_toolchain", None)
    if toolchain == None:
        fail("%s runs popili for %s, which carries no Coco toolchain." % (ctx.label, package.label))
    return toolchain

CocoResolvedPopiliInfo = provider(
    doc = "The popili coco_resolved_popili resolved. Internal to rules_coco.",
    fields = {
        "toolchain": "The Coco ToolchainInfo of the configured version for this configuration's target " +
                     "platform, or None when none is registered for it",
    },
)

def _coco_resolved_popili_impl(ctx):
    return [CocoResolvedPopiliInfo(toolchain = ctx.toolchains[COCO_TOOLCHAIN_TYPE])]

# Resolves popili for rules that run it in their own configuration: a coco_package's typecheck,
# the version alias, licence acquisition. Such a rule depends on it through an exec transition
# (see RESOLVED_POPILI_ATTR), so the binary is the one for its execution platform.
# Deliberately without LICENSE_ATTRIBUTES: the licence repositories depend on it.
coco_resolved_popili = rule(
    implementation = _coco_resolved_popili_impl,
    toolchains = POPILI_TOOLCHAINS,
)

# The attribute through which a rule gets the popili for its own execution platform.
RESOLVED_POPILI_ATTR = {
    "_popili": attr.label(
        cfg = "exec",
        default = Label("//coco/private:resolved_popili"),
        providers = [CocoResolvedPopiliInfo],
    ),
}

def _resolved_popili(ctx):
    """Returns the popili for the execution platform of a rule with RESOLVED_POPILI_ATTR, or None."""
    return ctx.attr._popili[CocoResolvedPopiliInfo].toolchain

def _script_is_windows(popili):
    """Whether the scripts running `popili` are for cmd.exe rather than bash.

    The scripts run where the binary runs, so the flavour follows the binary's platform rather
    than the target platform: `--platforms=//:windows` from a Linux host still emits a .sh for
    the Linux executor. rules_coco's toolchains record their platform; for one that does not,
    the binary is the signal, as a Windows popili is `popili.exe`.
    """
    platform = getattr(popili, "platform", "")
    if platform:
        return platform.startswith("windows")
    return popili.coco.extension == "exe"

def _coco_startup_args(ctx, popili, package, is_test):
    """Build startup arguments for popili.

    Args:
        ctx: Rule context
        popili: The Coco ToolchainInfo to run popili with
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
        _runtime_path(popili.preferences_file, is_test),
        "--terminal=plain",
    ]

    # Handle auth token file for action_file mode
    license_source = _get_license_source(ctx, popili)
    if license_source == "action_file":
        auth_token_path = _get_auth_token_path(ctx, popili)
        if auth_token_path:
            arguments.append("--machine-auth-token")
            arguments.append(auth_token_path)
    else:
        # Handle license file for other modes
        license_file = _get_license_file_from_toolchain(ctx, popili)
        if license_file:
            arguments.append("--override-licenses")
            arguments.append(_runtime_path(license_file, is_test))
    if package:
        info = _package_info(package)
        package_file = info.package_file
        dep_package_files = info.dep_package_files
        arguments += [
            "--package",
            _runtime_dirname(package_file, is_test),
        ]
        for dep_file in dep_package_files.to_list():
            arguments += ["--import-path", _runtime_dirname(dep_file, is_test)]
    return arguments

def _get_license_source(ctx, toolchain):
    cli_license_source = ctx.attr._license_source[BuildSettingInfo].value
    if cli_license_source:
        return cli_license_source
    toolchain_license_source = toolchain.license_source
    if toolchain_license_source:
        return toolchain_license_source
    return "local_user"

def _get_auth_token_path(ctx, toolchain):
    """Get the auth token file path from CLI flag or toolchain.

    Returns the path string (not a File object) for use with action_file licensing mode.
    """
    cli_auth_token_path = ctx.attr._auth_token_path[BuildSettingInfo].value
    if cli_auth_token_path:
        return cli_auth_token_path
    toolchain_auth_token_path = toolchain.auth_token_path
    if toolchain_auth_token_path:
        return toolchain_auth_token_path
    return ""

def _get_license_file_from_toolchain(ctx, popili):
    """Get the appropriate license file based on license_source.

    Reads license_source from the toolchain (repository default) with optional
    CLI override via --@rules_coco//:license_source flag.
    """

    license_source = _get_license_source(ctx, popili)
    if license_source == "local_acquire":
        files = ctx.attr._license_file_fetch[DefaultInfo].files.to_list()
        return files[0] if files else None
    if license_source == "local_user":
        files = ctx.attr._license_file_local[DefaultInfo].files.to_list()
        return files[0] if files else None
    return None

def _coco_env(ctx, toolchain):
    env = {}

    license_source = _get_license_source(ctx, toolchain)
    if license_source == "token":
        cli_license_token = ctx.attr._license_token[BuildSettingInfo].value
        toolchain_license_token = toolchain.license_token
        env["COCOTEC_AUTH_TOKEN"] = cli_license_token if cli_license_token else (toolchain_license_token if toolchain_license_token else "")

    return env

def _coco_runfiles(ctx, popili, package, is_test):
    direct = [
        popili.preferences_file,
    ]
    transitive = []
    if is_test:
        direct.append(popili.coco)
    license_file = _get_license_file_from_toolchain(ctx, popili)
    if license_file:
        direct.append(license_file)
    if package:
        direct.append(package[CocoPackageInfo].package_file)
        transitive.append(package[CocoPackageInfo].srcs)
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
    popili = _popili_toolchain(ctx, package)
    ctx.actions.run(
        executable = popili.coco,
        tools = [
            popili.coco,
        ],
        env = _coco_env(ctx, popili),
        mnemonic = mnemonic,
        progress_message = "%s %s" % (verb, package[CocoPackageInfo].name),
        inputs = _coco_runfiles(ctx, popili, package, False),
        outputs = outputs,
        arguments = _coco_startup_args(ctx, popili, package, False) + arguments,
    )

def _create_coco_wrapper_script(ctx, popili, package, arguments):
    """Creates a platform-specific wrapper script for running Coco commands.

    The script's flavour (.bat or .sh) follows the platform the popili binary runs on; see
    `_script_is_windows`.

    Args:
        ctx: The rule context
        popili: The Coco ToolchainInfo to run popili with
        package: The coco_package target (or None)
        arguments: List of command arguments (after startup args)

    Returns:
        The wrapper script file
    """
    coco_path = popili.coco.short_path
    is_windows = _script_is_windows(popili)
    if is_windows:
        coco_path = coco_path.replace("/", "\\")

    # Build the full command
    full_arguments = [coco_path] + _coco_startup_args(ctx, popili, package, True) + arguments
    command = " ".join(full_arguments)
    env = _coco_env(ctx, popili)

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

# Export helper functions for use by other private modules (e.g., format.bzl, diagram.bzl,
# licensing.bzl). These are implementation details and should not be used by end users.
popili_toolchain = _popili_toolchain
resolved_popili = _resolved_popili
create_coco_wrapper_script = _create_coco_wrapper_script
coco_runfiles = _coco_runfiles
run_coco = _run_coco

def _run_typecheck(ctx, popili, package, srcs, test_srcs):
    """Run typecheck and produce a marker file on success.

    Args:
        ctx: Rule context
        popili: The Coco ToolchainInfo to typecheck with, built for this target's execution platform
        package: Struct with package_file and dep_package_files fields
        srcs: Source files depset
        test_srcs: Test source files depset

    Returns:
        The typecheck marker file
    """

    # Create a marker file to track typecheck completion
    marker = ctx.actions.declare_file(ctx.label.name + ".typecheck")

    # Build startup arguments using the shared function
    startup_arguments = _coco_startup_args(ctx, popili, package = package, is_test = False)

    # Build typecheck command arguments
    typecheck_arguments = ["typecheck"]

    # Collect inputs
    license_file = _get_license_file_from_toolchain(ctx, popili)
    inputs_direct = [
        package.package_file,
        popili.preferences_file,
    ]
    if license_file:
        inputs_direct.append(license_file)

    # Create wrapper script that runs typecheck and creates marker on success
    coco_path = popili.coco.path
    is_windows = _script_is_windows(popili)
    if is_windows:
        coco_path = coco_path.replace("/", "\\")

    command = " ".join([coco_path] + startup_arguments + typecheck_arguments)
    env = _coco_env(ctx, popili)

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
        tools = [popili.coco, script],
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

def _resolved_pin(ctx):
    return resolve_version_alias(ctx.attr.popili_version) if ctx.attr.popili_version else ""

def _workspace_pin(workspace):
    """Returns struct(version, toolchain, pinned_by) for a CocoWorkspaceInfo, or None.

    CocoWorkspaceInfo is public, so it may come from a rule outside rules_coco that sets only
    `files`, the provider's original field. Such a workspace, or one without both a version
    and a toolchain, counts as unpinned.

    Args:
        workspace: A CocoWorkspaceInfo, or None.

    Returns:
        The workspace's pin, or None when there is none.
    """
    if workspace == None:
        return None
    version = getattr(workspace, "popili_version", "") or ""
    if not version:
        return None
    return struct(
        version = version,
        toolchain = getattr(workspace, "popili_toolchain", None),
        pinned_by = getattr(workspace, "popili_pinned_by", None),
    )

def _pin_warnings(label, version, pins, relation = "depends on it"):
    """Returns a warning for each pinned package in `pins` whose pin differs from `version`.

    Args:
        label: The package that uses the pinned packages.
        version: The popili version `label` resolved to.
        pins: A list of struct(label, pinned_by, version) for pinned packages among `label`'s
          dependencies.
        relation: How `label` uses the pinned packages, for the message.

    Returns:
        A list of warning strings, sorted by the pinned package's label.
    """
    warnings = []
    for pin in sorted(pins, key = lambda p: str(p.label)):
        if pin.version == version:
            continue
        via = "" if pin.pinned_by == pin.label else " (through %s)" % pin.pinned_by
        warnings.append(
            ("%s pins popili_version %r%s, but %s %s and uses popili %r. That pin is " +
             "ignored there: %s's sources are processed with popili %r.") % (
                pin.label,
                pin.version,
                via,
                label,
                relation,
                version,
                pin.label,
                version,
            ),
        )
    return warnings

def _coco_package_impl(ctx):
    _require_coco_toml(ctx.file.package, "package")
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
    workspace = ctx.attr.workspace[CocoWorkspaceInfo] if ctx.attr.workspace else None
    workspace_transitive = [dep[CocoPackageInfo].workspace_files for dep in ctx.attr.deps]
    if workspace:
        workspace_transitive.append(workspace.files)
    workspace_files = depset(transitive = workspace_transitive)

    # Resolve the popili version: the package's own pin, else its workspace's, else the
    # configuration's. Dependencies never decide it, as in popili itself. A pin is applied by
    # this rule's transition, so the toolchains of this configuration are the pinned version's.
    registry = ctx.attr._popili_registry[CocoVersionRegistryInfo]
    pin = _resolved_pin(ctx)
    workspace_pin = _workspace_pin(workspace)
    if pin and workspace_pin and pin != workspace_pin.version:
        fail(
            ("%s pins popili_version %r, but its workspace %s pins %r. A package and its " +
             "workspace must agree: remove one of the pins, or make them equal.") % (
                ctx.label,
                pin,
                workspace_pin.pinned_by,
                workspace_pin.version,
            ),
        )
    if workspace_pin and not pin:
        # Already checked by the workspace, which resolved its toolchains in this configuration
        # with its pin applied.
        toolchain = workspace_pin.toolchain
        version = workspace_pin.version
        pinned_by = workspace_pin.pinned_by
    else:
        # The popili this package's consumers run: the version of this configuration, built for
        # its target platform, which through the consumers' exec transition is their execution
        # platform (see _popili_toolchain). None when there is no popili for that platform.
        toolchain = ctx.toolchains[COCO_TOOLCHAIN_TYPE]
        _check_resolved_popili(ctx, toolchain, pin)
        version = _toolchain_version(toolchain) or _configured_version(ctx, registry)
        pinned_by = ctx.label if pin else None
    popili_error = _popili_error(ctx, toolchain, version, registry)

    dep_pins = depset(transitive = [
        getattr(dep[CocoPackageInfo], "popili_pins", depset())
        for dep in ctx.attr.deps
    ])
    warnings = _pin_warnings(ctx.label, version, dep_pins.to_list())
    for warning in warnings:
        # buildifier: disable=print
        print("WARNING: " + warning)
    popili_pins = depset(
        direct = [struct(label = ctx.label, pinned_by = pinned_by, version = version)] if pinned_by else [],
        transitive = [dep_pins],
    )

    # Conditionally run typecheck
    typecheck_marker = None
    if ctx.attr.typecheck:
        package_struct = struct(
            package_file = package_file,
            dep_package_files = dep_package_files,
            workspace_files = workspace_files,
        )

        # The typecheck is this package's own action, so it needs the popili of the package's
        # own execution platform rather than the one it forwards to its consumers: the same
        # version, from a target reached through an exec transition. A version inherited from the
        # workspace is not in this configuration, so it comes from the workspace analysed there.
        if workspace_pin and not pin:
            popili = _workspace_pin(ctx.attr.exec_workspace[CocoWorkspaceInfo]).toolchain
        else:
            popili = _resolved_popili(ctx)
        if popili == None:
            fail("%s has typecheck = True, but no Coco toolchain of popili %s is registered for its execution platform." % (ctx.label, version))
        typecheck_marker = _run_typecheck(ctx, popili, package_struct, srcs, test_srcs)

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
            popili_error = popili_error,
            popili_pinned = pinned_by != None,
            popili_pinned_by = pinned_by,
            popili_pins = popili_pins,
            popili_toolchain = toolchain,
            popili_version = version,
            popili_warnings = warnings,
            srcs = srcs,
            test_srcs = test_srcs,
            typecheck_marker = typecheck_marker,
            workspace_files = workspace_files,
        ),
        DefaultInfo(files = depset(direct = default_files_direct, transitive = [srcs, test_srcs, dep_package_files, workspace_files])),
    ]

_coco_package = rule(
    implementation = _coco_package_impl,
    attrs = dict(LICENSE_ATTRIBUTES.items() + RESOLVED_POPILI_ATTR.items() + _POPILI_PIN_ATTRS.items() + {
        "deps": attr.label_list(
            providers = [CocoPackageInfo],
            doc = "Other coco_package targets this package depends on.",
        ),
        "exec_workspace": attr.label(
            providers = [CocoWorkspaceInfo],
            cfg = "exec",
            doc = "The `workspace`, analysed for this package's execution platform: the popili of " +
                  "a version inherited from it, for the typecheck. Set by the coco_package macro.",
        ),
        "package": attr.label(
            mandatory = True,
            allow_single_file = [".toml"],
            doc = "Label pointing to the Coco.toml file for this package.",
        ),
        "srcs": attr.label_list(
            allow_files = [".coco"],
            mandatory = True,
            doc = "The .coco source files for this package.",
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
    cfg = _pin_transition,
    toolchains = POPILI_TOOLCHAINS,
)

def _coco_package_macro_impl(name, visibility, **kwargs):
    _coco_package(
        name = name,
        visibility = visibility,
        exec_workspace = kwargs.get("workspace"),
        **kwargs
    )

coco_package = macro(
    doc = """Define a Coco package from a Coco.toml and its .coco source files.

A coco_package is the unit the other Coco rules operate on: pass it to
coco_generate to produce code, to coco_verify_test to verify it, or to
coco_fmt_test to check formatting. Packages may depend on other packages via
`deps`, and may inherit shared settings from a coco_workspace via `workspace`.

The popili version is a property of the package: every rule consuming it (typecheck,
verify, generate, format, diagrams, and the C/C++ runtime of `coco_cc_library` /
`coco_c_library`) uses the same one. It is, in order of precedence:

1. `--@rules_coco//:version` when `--@rules_coco//:force_version` is set, e.g. by
   `with_popili_version`;
2. this package's `popili_version`;
3. its workspace's `popili_version`, which must not differ from the package's;
4. `--@rules_coco//:version`;
5. the first version registered.

Dependencies never decide a package's version. When a dependency pins a different version, a
warning is printed and its sources are processed with this package's version.""",
    inherit_attrs = _coco_package,
    attrs = {
        # Derived from `workspace` by the macro.
        "exec_workspace": None,
    },
    implementation = _coco_package_macro_impl,
)

def _coco_workspace_impl(ctx):
    _require_coco_toml(ctx.file.workspace, "workspace")

    parent = ctx.attr.parent[CocoWorkspaceInfo] if ctx.attr.parent else None
    parent_transitive = []
    if parent:
        parent_transitive.append(parent.files)
    files = depset(direct = [ctx.file.workspace], transitive = parent_transitive)

    pin = _resolved_pin(ctx)
    parent_pin = _workspace_pin(parent)
    if pin and parent_pin and pin != parent_pin.version:
        fail(
            ("%s pins popili_version %r, but its parent workspace %s pins %r. A workspace and " +
             "its parent must agree: remove one of the pins, or make them equal.") % (
                ctx.label,
                pin,
                parent_pin.pinned_by,
                parent_pin.version,
            ),
        )
    if pin:
        # This rule's transition applied the pin, so these are the pinned version's toolchains,
        # resolved for the configuration of the member package that depends on this workspace.
        toolchain = ctx.toolchains[COCO_TOOLCHAIN_TYPE]
        _check_resolved_popili(ctx, toolchain, pin)
        version = pin
        pinned_by = ctx.label
    elif parent_pin:
        toolchain = parent_pin.toolchain
        version = parent_pin.version
        pinned_by = parent_pin.pinned_by
    else:
        toolchain = None
        version = ""
        pinned_by = None

    return [
        CocoWorkspaceInfo(
            files = files,
            popili_pinned_by = pinned_by,
            popili_toolchain = toolchain,
            popili_version = version,
        ),
        DefaultInfo(files = files),
    ]

_coco_workspace = rule(
    implementation = _coco_workspace_impl,
    attrs = dict(_POPILI_PIN_ATTRS.items() + {
        "parent": attr.label(
            providers = [CocoWorkspaceInfo],
            doc = "An enclosing coco_workspace, when this workspace is nested inside another",
        ),
        "workspace": attr.label(
            mandatory = True,
            allow_single_file = [".toml"],
            doc = "Label pointing to the workspace's root Coco.toml (must contain a [workspace] section)",
        ),
    }.items()),
    cfg = _pin_transition,
    doc = "Declares a Coco workspace root whose shared settings flow down to member coco_package targets.",
    toolchains = POPILI_TOOLCHAINS,
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
packages. Reference this target from a coco_package's `workspace` attribute.

A workspace's `popili_version` is inherited by every member package that doesn't pin one,
and by nested workspaces (via `parent`). A member or nested workspace pinning a different
version is an error. Workspaces only pass settings down: they are not themselves consumed
by coco_generate, coco_verify_test and friends, which always take a coco_package.""",
    inherit_attrs = _coco_workspace,
    implementation = _coco_workspace_macro_impl,
)

def _coco_package_verify(ctx):
    popili = _popili_toolchain(ctx, ctx.attr.package)

    # Build the verify command arguments
    arguments = [
        "verify",
        "--results-junit",
        "%%XML_OUTPUT_FILE%%" if _script_is_windows(popili) else "$XML_OUTPUT_FILE",
    ]

    backend = ctx.attr._verification_backend[BuildSettingInfo].value
    if backend != "":
        arguments.append("--backend")
        arguments.append(backend)

    wrapper_script = _create_coco_wrapper_script(ctx, popili, ctx.attr.package, arguments)

    return DefaultInfo(
        executable = wrapper_script,
        runfiles = ctx.runfiles(transitive_files = _coco_runfiles(ctx, popili, ctx.attr.package, True)),
    )

_coco_verify_test = rule(
    implementation = _coco_package_verify,
    attrs = dict(LICENSE_ATTRIBUTES.items() + {
        "package": attr.label(
            providers = [CocoPackageInfo],
            mandatory = True,
            # The test runs in the `test` exec group: the package is analysed for its platform.
            cfg = config.exec("test"),
            doc = "The coco_package target to verify.",
        ),
        "_verification_backend": attr.label(default = Label("//:verification_backend")),
    }.items()),
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

def _mangle_name(name, style):
    """Apply name mangling based on the specified style.

    Args:
        name: The name to mangle
        style: One of: Unaltered, LowerCamelCase, UpperCamelCase, LowerUnderscore, UpperUnderscore, CapsUpperUnderscore

    Returns:
        The mangled name
    """
    if style == "Unaltered":
        return name

    # Split on uppercase letters to get word boundaries
    words = []
    current_word = ""
    for i, char in enumerate(name.elems()):
        if char.isupper() and i > 0 and current_word:
            words.append(current_word)
            current_word = char
        else:
            current_word += char
    if current_word:
        words.append(current_word)

    if style == "LowerCamelCase":
        if not words:
            return name
        return words[0].lower() + "".join([w.capitalize() for w in words[1:]])
    elif style == "UpperCamelCase":
        return "".join([w.capitalize() for w in words])
    elif style == "LowerUnderscore":
        return "_".join([w.lower() for w in words])
    elif style == "UpperUnderscore":
        return "_".join([w.upper() for w in words])
    elif style == "CapsUpperUnderscore":
        return "_".join([w.upper() for w in words])
    else:
        fail("Unsupported file name mangler style: %s" % style)

def _compute_output_filenames(src_basename, config):
    """Compute output filenames for a source file.

    This is a pure function that computes the output filenames without declaring
    any files. It can be unit tested.

    Args:
        src_basename: The source file basename (e.g., "ExampleName.coco")
        config: A struct with the following fields:
            - file_name_mangler: The name mangling style
            - header_prefix: Prefix for header files
            - header_extension: Extension for header files
            - impl_prefix: Prefix for implementation files
            - impl_extension: Extension for implementation files
            - mocks: Whether to generate mock files
            - flat_hierarchy: Whether to use flat file hierarchy
            - root_output_dir: Root output directory (for flat hierarchy)

    Returns:
        A struct with the following fields:
            - header: Regular header filename
            - impl: Regular implementation filename
            - mock_header: Mock header filename (or None)
            - mock_impl: Mock implementation filename (or None)
    """

    # Get the base name without extension
    base_name = paths.split_extension(src_basename)[0]

    # Apply name mangling
    base_name = _mangle_name(base_name, config.file_name_mangler)

    # Compute regular filenames
    header_name = config.header_prefix + base_name + config.header_extension
    impl_name = config.impl_prefix + base_name + config.impl_extension

    # Handle flat hierarchy
    if config.flat_hierarchy:
        if config.root_output_dir:
            header_name = paths.join(config.root_output_dir, header_name)
            impl_name = paths.join(config.root_output_dir, impl_name)

    # Compute mock filenames if needed
    mock_header_name = None
    mock_impl_name = None
    if config.mocks:
        mock_header_name = config.header_prefix + base_name + "Mock" + config.header_extension
        mock_impl_name = config.impl_prefix + base_name + "Mock" + config.impl_extension

        if config.flat_hierarchy:
            if config.root_output_dir:
                mock_header_name = paths.join(config.root_output_dir, mock_header_name)
                mock_impl_name = paths.join(config.root_output_dir, mock_impl_name)

    return struct(
        header = header_name,
        impl = impl_name,
        mock_header = mock_header_name,
        mock_impl = mock_impl_name,
    )

def _build_language_config(ctx, language, root_output_dir):
    """Build configuration struct for code generation.

    Args:
        ctx: Rule context
        language: Language string ("cpp", "c", or "csharp")
        root_output_dir: Root output directory

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
            root_output_dir = root_output_dir,
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
            root_output_dir = root_output_dir,
        )
    elif language == "csharp":
        return None  # C# doesn't use config struct
    else:
        fail("unrecognised language: " + language)

def _make_sibling_path_builder(ctx, src, flat_hierarchy):
    """Create a path builder function for sibling-based file declaration.

    Args:
        ctx: Rule context
        src: Source file (used as sibling)
        flat_hierarchy: Whether to use flat hierarchy

    Returns:
        Function(filename) -> declared file
    """
    if flat_hierarchy:
        return lambda filename: ctx.actions.declare_file(filename)
    else:
        return lambda filename: ctx.actions.declare_file(filename, sibling = src)

def _make_explicit_path_builder(ctx, package_relative_dir, root_output_dir, src_subdir):
    """Create a path builder function for explicit path-based file declaration.

    Args:
        ctx: Rule context
        package_relative_dir: Path from BUILD file to package directory
        root_output_dir: Root output directory
        src_subdir: Subdirectory within source tree (may be empty string)

    Returns:
        Function(filename) -> declared file
    """
    if src_subdir:
        return lambda filename: ctx.actions.declare_file(
            paths.join(package_relative_dir, root_output_dir, src_subdir, filename),
        )
    else:
        return lambda filename: ctx.actions.declare_file(
            paths.join(package_relative_dir, root_output_dir, filename),
        )

def _declare_language_outputs(ctx, headers, sources, mock_headers, mock_sources, src, config, path_builder):
    """Core logic for declaring output files.

    Args:
        ctx: Rule context
        headers: List to append regular header outputs to
        sources: List to append regular source outputs to
        mock_headers: List to append mock header outputs to
        mock_sources: List to append mock source outputs to
        src: Source file
        config: Configuration struct (or None for C#)
        path_builder: Function(filename) -> declared file
    """
    if ctx.attr.language == "cpp" or ctx.attr.language == "c":
        # C and C++ use header/implementation file split
        filenames = _compute_output_filenames(src.basename, config)

        headers.append(path_builder(filenames.header))
        sources.append(path_builder(filenames.impl))

        if filenames.mock_header:
            mock_headers.append(path_builder(filenames.mock_header))
            mock_sources.append(path_builder(filenames.mock_impl))
    elif ctx.attr.language == "csharp":
        # C# generation - simple .cs files, always hierarchical
        base_name = src.basename.removesuffix(".coco")
        cs_file = base_name + ".cs"
        sources.append(path_builder(cs_file))

        if ctx.attr.mocks:
            mock_file = base_name + "Mock.cs"
            mock_sources.append(path_builder(mock_file))
    else:
        fail("unrecognised language")

def _add_outputs(ctx, headers, sources, mock_headers, mock_sources, src, root_output_dir):
    """Add outputs for source files from the current package.

    Uses sibling-based file declaration for hierarchical layouts.

    Args:
        ctx: Rule context
        headers: List to append regular header outputs to
        sources: List to append regular source outputs to
        mock_headers: List to append mock header outputs to
        mock_sources: List to append mock source outputs to
        src: Source file from the current package
        root_output_dir: Root output directory
    """
    config = _build_language_config(ctx, ctx.attr.language, root_output_dir)
    flat_hierarchy = config.flat_hierarchy if config else False
    path_builder = _make_sibling_path_builder(ctx, src, flat_hierarchy)
    _declare_language_outputs(ctx, headers, sources, mock_headers, mock_sources, src, config, path_builder)

def _add_regenerated_outputs(ctx, headers, sources, mock_headers, mock_sources, src, package_relative_dir, root_output_dir, regen_pkg_dir, regen_root_output_dir):
    """Add outputs for regenerated package files.

    Regenerated files are placed in the current package's output directory,
    not in the original package's directory. This function computes the correct
    output paths without using the sibling relationship, preserving subdirectory structure.

    Args:
        ctx: Rule context
        headers: List to append regular header outputs to
        sources: List to append regular source outputs to
        mock_headers: List to append mock header outputs to
        mock_sources: List to append mock source outputs to
        src: Source file from the regenerated package
        package_relative_dir: Path from BUILD file to package directory (e.g., "app")
        root_output_dir: Root output directory for the current package (e.g., "sources")
        regen_pkg_dir: Regenerated package directory (e.g., "test/regenerate_packages/base")
        regen_root_output_dir: Regenerated package's root output dir (e.g., "source")
    """

    # Compute subdirectory within regenerated package's source directory
    # E.g., for "test/regenerate_packages/base/source/types/Dimension.coco"
    # relative to "test/regenerate_packages/base" is "source/types/Dimension.coco"
    # relative to "source" is "types/Dimension.coco", dirname is "types"
    src_relative_to_pkg = paths.relativize(src.path, regen_pkg_dir)
    src_relative_to_root = paths.relativize(src_relative_to_pkg, regen_root_output_dir)
    src_subdir = paths.dirname(src_relative_to_root)  # e.g., "types" or ""

    config = _build_language_config(ctx, ctx.attr.language, root_output_dir)
    path_builder = _make_explicit_path_builder(ctx, package_relative_dir, root_output_dir, src_subdir)
    _declare_language_outputs(ctx, headers, sources, mock_headers, mock_sources, src, config, path_builder)

def _output_directory(package_dir, srcs):
    root_output_dir = None
    for src in srcs.to_list():
        relative_to_package = paths.relativize(src.path, package_dir)
        if not root_output_dir or len(relative_to_package) < len(root_output_dir):
            root_output_dir = paths.dirname(relative_to_package)
    return root_output_dir

def _coco_package_generate_impl(ctx):
    package = ctx.attr.package
    srcs = package[CocoPackageInfo].direct_srcs
    test_srcs = package[CocoPackageInfo].direct_test_srcs
    package_dir = package[CocoPackageInfo].package_file.dirname

    headers = []
    sources = []
    mock_headers = []
    mock_sources = []
    test_headers = []
    test_sources = []

    root_output_dir = _output_directory(package_dir, srcs)
    test_root_output_dir = _output_directory(package_dir, test_srcs) if test_srcs else root_output_dir

    # Get the list of packages to regenerate based on language
    regenerate_pkgs = {
        "c": ctx.attr.c_regenerate_packages,
        "cpp": ctx.attr.cpp_regenerate_packages,
        "csharp": ctx.attr.csharp_regenerate_packages,
    }.get(ctx.attr.language, [])

    # Add outputs for regenerated packages (using current package's settings)
    # Regenerated files go into the current package's output directory
    # Compute path relative to BUILD file: from ctx.label.package to package_dir
    package_relative_dir = paths.relativize(package_dir, ctx.label.package) if ctx.label.package else package_dir
    toolchain = _popili_toolchain(ctx, package)
    popili_version = _toolchain_version(toolchain)
    for warning in _pin_warnings(
        ctx.label,
        popili_version,
        depset(transitive = [
            getattr(regen_pkg[CocoPackageInfo], "popili_pins", depset())
            for regen_pkg in regenerate_pkgs
        ]).to_list(),
        relation = "regenerates it",
    ):
        # buildifier: disable=print
        print("WARNING: " + warning)

    for regen_pkg in regenerate_pkgs:
        regen_pkg_dir = regen_pkg[CocoPackageInfo].package_file.dirname
        regen_root_output_dir = _output_directory(regen_pkg_dir, regen_pkg[CocoPackageInfo].direct_srcs)
        for src in regen_pkg[CocoPackageInfo].direct_srcs.to_list():
            _add_regenerated_outputs(ctx, headers, sources, mock_headers, mock_sources, src, package_relative_dir, root_output_dir, regen_pkg_dir, regen_root_output_dir)

    for src in srcs.to_list():
        _add_outputs(ctx, headers, sources, mock_headers, mock_sources, src, root_output_dir)
    for src in test_srcs.to_list():
        _add_outputs(ctx, test_headers, test_sources, mock_headers, mock_sources, src, test_root_output_dir)
    test_headers += mock_headers
    test_sources += mock_sources
    output_dir = paths.join(ctx.genfiles_dir.path, package_dir, root_output_dir)
    arguments = [
        "generate-%s" % ctx.attr.language,
        "--output",
        output_dir,
        "--output-empty-files",
        "--output-runtime=false",
    ]
    if test_srcs:
        arguments += [
            "--test-output",
            paths.join(ctx.genfiles_dir.path, package_dir, _output_directory(package_dir, test_srcs)),
        ]
    elif ctx.attr.mocks:
        arguments += [
            "--test-output",
            output_dir,
        ]
    if ctx.attr.language == "cpp" or ctx.attr.language == "c":
        # Make all include paths absolute within the workspace to avoid the need for includes
        arguments += [
            "--include-prefix",
            paths.join(package_dir, root_output_dir),
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
            popili_version = popili_version,
            headers = depset(headers),
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
    attrs = dict(LICENSE_ATTRIBUTES.items() + {
        # C output path options
        "c_file_name_mangler": attr.string(
            default = "Unaltered",
            doc = "C file naming style. Must match Coco.toml generator.c.fileNameMangler. " +
                  "Options: \"Unaltered\" (default), \"LowerCamelCase\", \"UpperCamelCase\", " +
                  "\"LowerUnderscore\", \"UpperUnderscore\", \"CapsUpperUnderscore\".",
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
            cfg = "exec",
            doc = "Other coco_package targets to regenerate with this target's C generator settings.",
        ),
        # C++ output path options
        "cpp_file_name_mangler": attr.string(
            default = "Unaltered",
            doc = "C++ file naming style. Must match Coco.toml generator.cpp.fileNameMangler. " +
                  "Options: \"Unaltered\" (default), \"LowerCamelCase\", \"UpperCamelCase\", " +
                  "\"LowerUnderscore\", \"UpperUnderscore\", \"CapsUpperUnderscore\".",
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
            cfg = "exec",
            doc = "Other coco_package targets to regenerate with this target's C++ generator settings.",
        ),
        "csharp_regenerate_packages": attr.label_list(
            providers = [CocoPackageInfo],
            default = [],
            cfg = "exec",
            doc = "Other coco_package targets to regenerate with this target's C# generator settings.",
        ),
        "language": attr.string(
            mandatory = True,
            values = ["cpp", "c", "csharp"],
            doc = "Target language for code generation: \"cpp\", \"c\", or \"csharp\".",
        ),
        "mocks": attr.bool(
            doc = "Generate mock implementations for testing. Disabled by default.",
        ),
        "package": attr.label(
            providers = [CocoPackageInfo],
            mandatory = True,
            # The package is analysed for this rule's execution platform; see _popili_toolchain.
            cfg = "exec",
            doc = "The coco_package target containing the source files to generate from.",
        ),
    }.items()),
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
    return "%s.tst" % name

def _generated_code_runtime(ctx, gen_info):
    """Returns the runtime target matching the popili version the code was generated with.

    Taken from the hub's version registry, so the runtime is built in this target's own
    configuration rather than in the one the package's pinned toolchain was resolved in.

    Args:
        ctx: The _coco_cc_gen rule context.
        gen_info: The CocoCcGeneratedInfo of the generated package.

    Returns:
        The runtime Target, or None when `ctx.attr.runtime` is empty.
    """
    kind = ctx.attr.runtime
    if not kind:
        return None
    if ctx.attr.runtime_registry == None:
        fail("%s sets runtime = %r but no runtime_registry; use coco_cc_library or coco_c_library, which set both." % (ctx.label, kind))
    registry = ctx.attr.runtime_registry[CocoVersionRegistryInfo]
    registered = registry.cc_runtimes if kind == "cc" else registry.c_runtimes
    version = getattr(gen_info, "popili_version", "")
    if version in registered:
        return registered[version]

    # Not registered in the hub, e.g. a bring-your-own toolchain: use the runtime the toolchain
    # of this target's own configuration names, if any.
    toolchain = ctx.toolchains[COCO_TOOLCHAIN_TYPE]
    runtime = getattr(toolchain, "cc_runtime" if kind == "cc" else "c_runtime", None) if toolchain != None else None
    if not runtime:
        if kind == "cc":
            fail("C++ runtime not available. Did you enable cc=True in coco.toolchain()?")
        fail("C runtime not available. Did you enable c=True in coco.toolchain()?")
    return runtime

def _coco_cc_gen_impl(ctx):
    """Extracts generated C/C++ sources and headers, providing CcInfo for headers.

    Returns DefaultInfo with sources (+ private headers) for cc_library srcs,
    and CcInfo with public headers for cc_library deps.
    """
    gen_info = ctx.attr.package[CocoCcGeneratedInfo]

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

    compilation_context = cc_common.create_compilation_context(
        headers = depset(public_hdrs),
    )
    cc_info = CcInfo(compilation_context = compilation_context)

    runtime = _generated_code_runtime(ctx, gen_info)
    if runtime:
        cc_info = cc_common.merge_cc_infos(direct_cc_infos = [cc_info], cc_infos = [runtime[CcInfo]])

    return [
        DefaultInfo(files = depset(sources + private_hdrs)),
        cc_info,
    ]

_coco_cc_gen = rule(
    implementation = _coco_cc_gen_impl,
    attrs = {
        "all_hdrs_public": attr.bool(default = True),
        "package": attr.label(
            providers = [CocoCcGeneratedInfo],
            mandatory = True,
        ),
        "public_hdrs": attr.string_list(
            default = [],
            doc = "Header names to make public (when all_hdrs_public is False). " +
                  "Use bare filenames (e.g., 'ISensor.h') to match by name, or " +
                  "path suffixes (e.g., 'src/ISensor.h') to disambiguate.",
        ),
        "runtime": attr.string(
            default = "",
            values = ["", "c", "cc"],
            doc = "Which Coco runtime to link, matching the popili version the code was generated " +
                  "with: 'cc' for C++, 'c' for C, or '' for none.",
        ),
        "runtime_registry": attr.label(
            providers = [CocoVersionRegistryInfo],
            doc = "The hub's registry of `runtime` runtimes by version. Set by coco_library: a " +
                  "private attribute would make every library fetch both kinds.",
        ),
        "use_test_outputs": attr.bool(default = False, doc = "If True, extract test/mock outputs instead of regular outputs"),
    },
    toolchains = POPILI_TOOLCHAINS,
)

def _coco_generate_macro_impl(name, visibility, **kwargs):
    # Generator attrs are inherited from _coco_generate and forwarded via kwargs.
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

The generated files can then be compiled into libraries or executables using
standard build rules (e.g., cc_library for C/C++).

The generator configuration options (file extensions, prefixes, etc.) must
match the settings in your Coco.toml file under the corresponding generator
section (e.g., [generator.cpp] for C++, [generator.c] for C).

Alongside the main code-generation target, a companion `<name>.tst` target is
created that exposes the generated test sources and headers.""",
    inherit_attrs = _coco_generate,
    implementation = _coco_generate_macro_impl,
)

def _popili_version_alias_impl(ctx):
    # The popili of this configuration's version, for this target's own execution platform. A
    # genrule using the make variables picks its execution platform without any Coco toolchain
    # requirement, so it should constrain itself to the same platform.
    popili = _resolved_popili(ctx)
    if popili == None:
        fail("%s: no Coco toolchain is registered for this configuration and execution platform." % ctx.label)
    return [
        popili,
        platform_common.TemplateVariableInfo({
            "POPILI": popili.coco.short_path,
            "POPILI_STARTUP_ARGS": " ".join(_coco_startup_args(ctx, popili, None, True)),
        }),
        DefaultInfo(
            runfiles = ctx.runfiles(transitive_files = _coco_runfiles(ctx, popili, None, True)),
        ),
    ]

_popili_version_alias = rule(
    attrs = dict(LICENSE_ATTRIBUTES.items() + RESOLVED_POPILI_ATTR.items()),
    implementation = _popili_version_alias_impl,
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

# Exported for testing
pinned_version = _pinned_version
pin_warnings = _pin_warnings

# Exported for testing
mangle_name = _mangle_name
compute_output_filenames = _compute_output_filenames
