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
load(":platforms.bzl", "EXEC_PLATFORM_KEYS")
load(":version_registry.bzl", "CocoVersionRegistryInfo")
load(":version_resolution.bzl", "VERSION_FLAG", "resolve_version_alias")

CocoPackageInfo = provider(
    doc = "Information about a Coco package",
    fields = {
        "dep_package_files": "All Coco.toml files for all transitive dependencies",
        "direct_srcs": "The .coco files that are direct sources of this package only",
        "direct_test_srcs": "The .coco files that are direct test_sources of this package only",
        "name": "The name of the package",
        "package_file": "The Coco.toml file for this package",
        "popili_toolchain": "The Coco ToolchainInfo the rules consuming this package run popili with: the " +
                            "package's version, built for the target platform of the configuration the package " +
                            "was analysed in. Consumers depend on the package through an exec transition, so for " +
                            "them that is their own execution platform. None when no popili is registered for " +
                            "that platform",
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

# The two toolchain types every popili is registered for (see toolchain_hub.bzl). A coco_package
# resolves the first, which constrains the target platform, and forwards it to its consumers in
# CocoPackageInfo.popili_toolchain: they depend on the package through an exec transition, so the
# package's target platform is the consumer's execution platform, and the binary it hands out runs
# where the consumer's actions run. A rule running popili in its own configuration (a package's
# typecheck, the version alias, licence acquisition) resolves the second, which constrains the
# execution platform.
COCO_TOOLCHAIN_TYPE = "@rules_coco//coco:toolchain_type"
EXEC_COCO_TOOLCHAIN_TYPE = "@rules_coco//coco:exec_toolchain_type"

# Both optional: a package built for a platform popili is not published for (cross-compiling)
# forwards None, and only a consumer that actually runs popili fails, with a message saying why.
POPILI_TOOLCHAINS = [
    config_common.toolchain_type(COCO_TOOLCHAIN_TYPE, mandatory = False),
    config_common.toolchain_type(EXEC_COCO_TOOLCHAIN_TYPE, mandatory = False),
]

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

def _toolchain_version(toolchain):
    return getattr(toolchain, "version", "") or ""

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
    toolchain = getattr(_package_info(package), "popili_toolchain", None)
    if toolchain == None:
        fail(
            ("%s runs popili for %s on its execution platform, but no Coco toolchain of the configured " +
             "Popili version is registered for it. rules_coco publishes popili for %s; see the README " +
             "sections \"Popili Version\", \"Remote execution\" and \"Bring your own toolchain\".") % (
                ctx.label,
                package.label,
                ", ".join(EXEC_PLATFORM_KEYS),
            ),
        )
    return toolchain

def _exec_popili(ctx):
    """Returns the popili a rule runs in its own configuration, or None.

    That is the toolchain for the rule's own execution platform. Falls back to the
    target-keyed toolchain type for setups registering only that one, such as a
    bring-your-own toolchain without platform constraints.

    Args:
        ctx: Rule context, of a rule declaring POPILI_TOOLCHAINS.

    Returns:
        The Coco ToolchainInfo, or None when neither type resolved.
    """
    toolchain = ctx.toolchains[EXEC_COCO_TOOLCHAIN_TYPE]
    if toolchain == None:
        toolchain = ctx.toolchains[COCO_TOOLCHAIN_TYPE]
    return toolchain

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
exec_popili = _exec_popili
create_coco_wrapper_script = _create_coco_wrapper_script
coco_runfiles = _coco_runfiles
run_coco = _run_coco

def _run_typecheck(ctx, popili, package, srcs, test_srcs):
    """Run typecheck and produce a marker file on success.

    Args:
        ctx: Rule context
        popili: The Coco ToolchainInfo to typecheck with
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
    workspace_transitive = [dep[CocoPackageInfo].workspace_files for dep in ctx.attr.deps]
    if ctx.attr.workspace:
        workspace_transitive.append(ctx.attr.workspace[CocoWorkspaceInfo].files)
    workspace_files = depset(transitive = workspace_transitive)

    # The popili this package's consumers run: the version of this configuration, built for its
    # target platform, which through the consumers' exec transition is their execution platform
    # (see _popili_toolchain). None when there is no popili for that platform.
    toolchain = ctx.toolchains[COCO_TOOLCHAIN_TYPE]

    # Conditionally run typecheck
    typecheck_marker = None
    if ctx.attr.typecheck:
        package_struct = struct(
            package_file = package_file,
            dep_package_files = dep_package_files,
            workspace_files = workspace_files,
        )

        # Typecheck is this package's own action, so it runs the popili of its own execution
        # platform rather than the one it hands to its consumers.
        popili = _exec_popili(ctx)
        if popili == None:
            fail("%s has typecheck = True, but no Coco toolchain is registered for its execution platform." % ctx.label)
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
            popili_toolchain = toolchain,
            srcs = srcs,
            test_srcs = test_srcs,
            typecheck_marker = typecheck_marker,
            workspace_files = workspace_files,
        ),
        DefaultInfo(files = depset(direct = default_files_direct, transitive = [srcs, test_srcs, dep_package_files, workspace_files])),
    ]

_coco_package = rule(
    implementation = _coco_package_impl,
    attrs = dict(LICENSE_ATTRIBUTES.items() + {
        "deps": attr.label_list(
            providers = [CocoPackageInfo],
            doc = "Other coco_package targets this package depends on.",
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
    toolchains = POPILI_TOOLCHAINS,
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
    # When using configuration transitions, ctx.attr.package becomes a list
    package = ctx.attr.package[0] if type(ctx.attr.package) == type([]) else ctx.attr.package
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
    toolchain = _exec_popili(ctx)
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

    # Companion target for the generated test sources/headers. Only visibility is
    # forwarded (kwargs holds generator-only attrs); see test/visibility_propagation.
    _coco_test_outputs(
        name = coco_test_outputs_name(name),
        package = name,
        visibility = visibility,
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
    popili = _exec_popili(ctx)
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
    attrs = LICENSE_ATTRIBUTES,
    implementation = _popili_version_alias_impl,
    toolchains = POPILI_TOOLCHAINS,
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
mangle_name = _mangle_name
compute_output_filenames = _compute_output_filenames
