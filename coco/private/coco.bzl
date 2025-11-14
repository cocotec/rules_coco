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
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load(":version_aliases.bzl", "VERSION_ALIASES")

CocoPackageInfo = provider(
    doc = "Information about a Coco package",
    fields = {
        "dep_package_files": "All Coco.toml files for all transitive dependencies",
        "direct_srcs": "The .coco files that are direct sources of this package only",
        "direct_test_srcs": "The .coco files that are direct test_sources of this package only",
        "name": "The name of the package",
        "package_file": "The Coco.toml file for this package",
        "srcs": "All .coco files that are sources of this package or any of its transitive dependencies",
        "test_srcs": "All .coco files that are test_sources of this package or any of its transitive dependencies",
        "typecheck_marker": "Marker file indicating typecheck passed (or None if typecheck disabled)",
    },
)

CocoGeneratedCodeInfo = provider(
    doc = "Information about a Coco package",
    fields = {
        "outputs": "Code ",
        "test_outputs": "The Coco.toml file for this package",
    },
)

LICENSE_ATTRIBUTES = {
    "_license_file_fetch": attr.label(default = Label("@io_cocotec_licensing_fetch//:licenses")),
    "_license_file_local": attr.label(default = Label("@io_cocotec_licensing_local//:licenses")),
    "_license_source": attr.label(default = Label("//:license_source")),
    "_license_token": attr.label(default = Label("//:license_token")),
}

COCO_TOOLCHAIN_TYPE = "@rules_coco//coco:toolchain_type"

def _resolve_version_alias(version):
    """Resolve a version alias (like 'stable') to an actual version number.

    Args:
        version: A version string, which may be an alias like 'stable' or an actual version like '1.5.0'

    Returns:
        The resolved version string
    """
    if version in VERSION_ALIASES:
        return VERSION_ALIASES[version]
    return version

def _popili_version_transition_impl(_settings, attr):
    """Transition implementation for per-target popili version selection.

    If the target specifies a version attribute, transition to that version.
    Version aliases (like "stable") are resolved to actual version numbers.
    Otherwise, keep the current configuration's version setting.
    """
    if hasattr(attr, "version") and attr.version:
        resolved_version = _resolve_version_alias(attr.version)
        return {"@rules_coco//:version": resolved_version}
    return {}

_popili_version_transition = transition(
    implementation = _popili_version_transition_impl,
    inputs = [],
    outputs = ["@rules_coco//:version"],
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

    # Forward CocoGeneratedCodeInfo if present
    if CocoGeneratedCodeInfo in target:
        providers.append(target[CocoGeneratedCodeInfo])

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
        _runtime_path(ctx.toolchains[COCO_TOOLCHAIN_TYPE].preferences_file, is_test),
        "--terminal=plain",
    ]
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
            package_file.dirname,
        ]
        for dep_file in dep_package_files.to_list():
            arguments += ["--import-path", dep_file.dirname]
    return arguments

def _get_license_file_from_toolchain(ctx):
    """Get the appropriate license file based on license_source.

    Note: Despite the name, this doesn't actually use the toolchain - it
    accesses well-known license repositories to avoid circular dependencies.
    """
    license_source = ctx.attr._license_source[BuildSettingInfo].value
    if license_source == "local_acquire":
        files = ctx.attr._license_file_fetch[DefaultInfo].files.to_list()
        return files[0] if files else None
    elif license_source == "local_user":
        files = ctx.attr._license_file_local[DefaultInfo].files.to_list()
        return files[0] if files else None
    return None

def _coco_env(ctx):
    env = {}
    if ctx.attr._license_source[BuildSettingInfo].value == "token":
        env["COCOTEC_AUTH_TOKEN"] = ctx.attr._license_token[BuildSettingInfo].value
    return env

def _coco_runfiles(ctx, package, is_test):
    direct = [
        ctx.toolchains[COCO_TOOLCHAIN_TYPE].preferences_file,
    ]
    transitive = []
    if is_test:
        direct.append(ctx.toolchains[COCO_TOOLCHAIN_TYPE].coco)
    license_file = _get_license_file_from_toolchain(ctx)
    if license_file:
        direct.append(license_file)
    if package:
        direct.append(package[CocoPackageInfo].package_file)
        transitive.append(package[CocoPackageInfo].srcs)
        transitive.append(package[CocoPackageInfo].dep_package_files)

        # Include typecheck marker if present to ensure codegen waits for typecheck
        if package[CocoPackageInfo].typecheck_marker:
            direct.append(package[CocoPackageInfo].typecheck_marker)
    return depset(
        direct = direct,
        transitive = transitive,
    )

def _run_coco(ctx, package, verb, arguments, outputs):
    ctx.actions.run(
        executable = ctx.toolchains[COCO_TOOLCHAIN_TYPE].coco,
        tools = [
            ctx.toolchains[COCO_TOOLCHAIN_TYPE].coco,
        ],
        env = _coco_env(ctx),
        mnemonic = "CocoGenerate",
        progress_message = "%s %s" % (verb, package[CocoPackageInfo].name),
        inputs = _coco_runfiles(ctx, package, False),
        outputs = outputs,
        arguments = _coco_startup_args(ctx, package, False) + arguments,
    )

def _create_coco_wrapper_script(ctx, package, arguments):
    """Creates a platform-specific wrapper script for running Coco commands.

    Args:
        ctx: The rule context
        package: The coco_package target (or None)
        arguments: List of command arguments (after startup args)

    Returns:
        The wrapper script file
    """
    coco_path = ctx.toolchains[COCO_TOOLCHAIN_TYPE].coco.short_path
    if ctx.attr.is_windows:
        coco_path = coco_path.replace("/", "\\")

    # Build the full command
    full_arguments = [coco_path] + _coco_startup_args(ctx, package, True) + arguments
    command = " ".join(full_arguments)
    env = _coco_env(ctx)

    # Create platform-specific wrapper script
    if ctx.attr.is_windows:
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

# Export helper functions for use by other private modules (e.g., format.bzl)
# These are implementation details and should not be used by end users
create_coco_wrapper_script = _create_coco_wrapper_script
coco_runfiles = _coco_runfiles

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
        ctx.toolchains[COCO_TOOLCHAIN_TYPE].preferences_file,
    ]
    if license_file:
        inputs_direct.append(license_file)

    # Create wrapper script that runs typecheck and creates marker on success
    coco_path = ctx.toolchains[COCO_TOOLCHAIN_TYPE].coco.path
    if ctx.attr.is_windows:
        coco_path = coco_path.replace("/", "\\")

    command = " ".join([coco_path] + startup_arguments + typecheck_arguments)
    env = _coco_env(ctx)

    if ctx.attr.is_windows:
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
        tools = [ctx.toolchains[COCO_TOOLCHAIN_TYPE].coco, script],
        mnemonic = "CocoTypecheck",
        progress_message = "Typechecking %s" % ctx.label.name,
        inputs = depset(direct = inputs_direct, transitive = [srcs, test_srcs, package.dep_package_files]),
        outputs = [marker],
        arguments = [],
    )

    return marker

def _coco_package_impl(ctx):
    if ctx.file.package.basename != "Coco.toml":
        fail("Package must point to a file called exactly 'Coco.toml'", attr = "package")
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

    # Conditionally run typecheck
    typecheck_marker = None
    if ctx.attr.typecheck:
        package_struct = struct(
            package_file = package_file,
            dep_package_files = dep_package_files,
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
            srcs = srcs,
            test_srcs = test_srcs,
            typecheck_marker = typecheck_marker,
        ),
        DefaultInfo(files = depset(direct = default_files_direct, transitive = [srcs, test_srcs, dep_package_files])),
    ]

_coco_package = rule(
    implementation = _coco_package_impl,
    attrs = dict(LICENSE_ATTRIBUTES.items() + {
        "deps": attr.label_list(
            providers = [CocoPackageInfo],
        ),
        "is_windows": attr.bool(
            mandatory = True,
            doc = "True if building for Windows platform",
        ),
        "package": attr.label(
            mandatory = True,
            allow_single_file = [".toml"],
        ),
        "srcs": attr.label_list(
            allow_files = [".coco"],
            mandatory = True,
        ),
        "test_srcs": attr.label_list(
            allow_files = [".coco"],
            allow_empty = True,
        ),
        "typecheck": attr.bool(
            default = False,
            doc = "Run typecheck validation during package creation. When enabled, package build will fail if typecheck errors are found.",
        ),
    }.items()),
    toolchains = [
        COCO_TOOLCHAIN_TYPE,
    ],
)

def coco_package(name, **kwargs):
    """Define a Coco package from Coco.toml and .coco source files.

    Args:
        name: Name of the package target
        **kwargs: Additional arguments passed to the underlying rule
    """
    _coco_package(
        name = name,
        is_windows = select({
            "@platforms//os:windows": True,
            "//conditions:default": False,
        }),
        **kwargs
    )

def _coco_package_verify(ctx):
    # Build the verify command arguments
    arguments = [
        "verify",
        "--results-junit",
        "%%XML_OUTPUT_FILE%%" if ctx.attr.is_windows else "$XML_OUTPUT_FILE",
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
    attrs = dict(LICENSE_ATTRIBUTES.items() + {
        "is_windows": attr.bool(mandatory = True),
        "package": attr.label(
            providers = [CocoPackageInfo],
            mandatory = True,
        ),
        "_verification_backend": attr.label(default = Label("//:verification_backend")),
    }.items()),
    test = True,
    toolchains = [
        COCO_TOOLCHAIN_TYPE,
    ],
)

def coco_verify_test(**kwargs):
    _coco_verify_test(
        is_windows = select({
            "@platforms//os:windows": True,
            "//conditions:default": False,
        }),
        **kwargs
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

def _add_outputs(ctx, outputs, mock_outputs, src, root_output_dir):
    if ctx.attr.language == "cpp":
        # Create config struct from context attributes
        config = struct(
            file_name_mangler = ctx.attr.cpp_file_name_mangler,
            header_prefix = ctx.attr.cpp_header_file_prefix,
            header_extension = ctx.attr.cpp_header_file_extension,
            impl_prefix = ctx.attr.cpp_implementation_file_prefix,
            impl_extension = ctx.attr.cpp_implementation_file_extension,
            mocks = ctx.attr.mocks,
            flat_hierarchy = ctx.attr.cpp_flat_file_hierarchy,
            root_output_dir = root_output_dir,
        )

        # Compute output filenames using pure function
        filenames = _compute_output_filenames(src.basename, config)

        # Declare files
        if config.flat_hierarchy:
            outputs.append(ctx.actions.declare_file(filenames.header))
            outputs.append(ctx.actions.declare_file(filenames.impl))
            if filenames.mock_header:
                mock_outputs.append(ctx.actions.declare_file(filenames.mock_header))
                mock_outputs.append(ctx.actions.declare_file(filenames.mock_impl))
        else:
            outputs.append(ctx.actions.declare_file(filenames.header, sibling = src))
            outputs.append(ctx.actions.declare_file(filenames.impl, sibling = src))
            if filenames.mock_header:
                mock_outputs.append(ctx.actions.declare_file(filenames.mock_header, sibling = src))
                mock_outputs.append(ctx.actions.declare_file(filenames.mock_impl, sibling = src))
    elif ctx.attr.language == "c":
        # Create config struct from context attributes
        config = struct(
            file_name_mangler = ctx.attr.c_file_name_mangler,
            header_prefix = ctx.attr.c_header_file_prefix,
            header_extension = ctx.attr.c_header_file_extension,
            impl_prefix = ctx.attr.c_implementation_file_prefix,
            impl_extension = ctx.attr.c_implementation_file_extension,
            mocks = ctx.attr.mocks,
            flat_hierarchy = ctx.attr.c_flat_file_hierarchy,
            root_output_dir = root_output_dir,
        )

        # Compute output filenames using pure function
        filenames = _compute_output_filenames(src.basename, config)

        # Declare files
        if config.flat_hierarchy:
            outputs.append(ctx.actions.declare_file(filenames.header))
            outputs.append(ctx.actions.declare_file(filenames.impl))
            if filenames.mock_header:
                mock_outputs.append(ctx.actions.declare_file(filenames.mock_header))
                mock_outputs.append(ctx.actions.declare_file(filenames.mock_impl))
        else:
            outputs.append(ctx.actions.declare_file(filenames.header, sibling = src))
            outputs.append(ctx.actions.declare_file(filenames.impl, sibling = src))
            if filenames.mock_header:
                mock_outputs.append(ctx.actions.declare_file(filenames.mock_header, sibling = src))
                mock_outputs.append(ctx.actions.declare_file(filenames.mock_impl, sibling = src))
    elif ctx.attr.language == "csharp":
        # C# generation - very simple, just .cs files
        # No header/implementation split, always hierarchical
        base_name = src.basename.removesuffix(".coco")
        cs_file = base_name + ".cs"
        outputs.append(ctx.actions.declare_file(cs_file, sibling = src))

        if ctx.attr.mocks:
            mock_file = base_name + "Mock.cs"
            mock_outputs.append(ctx.actions.declare_file(mock_file, sibling = src))
    else:
        fail("unrecognised language")

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

    outputs = []
    mock_outputs = []
    test_outputs = []

    root_output_dir = _output_directory(package_dir, srcs)
    test_root_output_dir = _output_directory(package_dir, test_srcs) if test_srcs else root_output_dir

    for src in srcs.to_list():
        _add_outputs(ctx, outputs, mock_outputs, src, root_output_dir)
    for src in test_srcs.to_list():
        _add_outputs(ctx, test_outputs, mock_outputs, src, test_root_output_dir)
    test_outputs += mock_outputs
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
    if ctx.attr.language == "cpp":
        # Make all include paths absolute within the workspace to avoid the need for includes
        arguments += [
            "--include-prefix",
            paths.join(package_dir, root_output_dir),
        ]

    _run_coco(
        ctx = ctx,
        package = package,
        verb = "Generating %s" % ctx.attr.language,
        arguments = arguments,
        outputs = outputs + test_outputs,
    )

    outputs = depset(outputs)
    test_outputs = depset(test_outputs)
    return [
        DefaultInfo(
            files = outputs,
        ),
        CocoGeneratedCodeInfo(
            outputs = outputs,
            test_outputs = test_outputs,
        ),
    ]

_coco_generate = rule(
    implementation = _coco_package_generate_impl,
    attrs = dict(LICENSE_ATTRIBUTES.items() + {
        # C output path options
        "c_file_name_mangler": attr.string(
            default = "Unaltered",
            doc = """Must match Coco.toml generator.c.fileNameMangler setting.""",
        ),
        "c_flat_file_hierarchy": attr.bool(
            default = False,
            doc = """Must match Coco.toml generator.c.flatFileHierarchy setting.""",
        ),
        "c_header_file_extension": attr.string(
            default = ".h",
            doc = """Must match Coco.toml generator.c.headerFileExtension setting.""",
        ),
        "c_header_file_prefix": attr.string(
            default = "",
            doc = """Must match Coco.toml generator.c.headerFilePrefix setting.""",
        ),
        "c_implementation_file_extension": attr.string(
            default = ".c",
            doc = """Must match Coco.toml generator.c.implementationFileExtension setting.""",
        ),
        "c_implementation_file_prefix": attr.string(
            default = "",
            doc = """Must match Coco.toml generator.c.implementationFilePrefix setting.""",
        ),
        # C++ output path options
        "cpp_file_name_mangler": attr.string(
            default = "Unaltered",
            doc = """Must match Coco.toml generator.cpp.fileNameMangler setting.""",
        ),
        "cpp_flat_file_hierarchy": attr.bool(
            default = False,
            doc = """Must match Coco.toml generator.cpp.flatFileHierarchy setting.""",
        ),
        "cpp_header_file_extension": attr.string(
            default = ".h",
            doc = """Must match Coco.toml generator.cpp.headerFileExtension setting.""",
        ),
        "cpp_header_file_prefix": attr.string(
            default = "",
            doc = """Must match Coco.toml generator.cpp.headerFilePrefix setting.""",
        ),
        "cpp_implementation_file_extension": attr.string(
            default = ".cc",
            doc = """Must match Coco.toml generator.cpp.implementationFileExtension setting.""",
        ),
        "cpp_implementation_file_prefix": attr.string(
            default = "",
            doc = """Must match Coco.toml generator.cpp.implementationFilePrefix setting.""",
        ),
        "language": attr.string(mandatory = True, values = ["cpp", "c", "csharp"]),
        "mocks": attr.bool(),
        "package": attr.label(
            providers = [CocoPackageInfo],
            mandatory = True,
        ),
    }.items()),
    toolchains = [
        COCO_TOOLCHAIN_TYPE,
    ],
)

def _coco_test_outputs_impl(ctx):
    return [
        DefaultInfo(
            files = ctx.attr.package[CocoGeneratedCodeInfo].test_outputs,
        ),
    ]

_coco_test_outputs = rule(
    implementation = _coco_test_outputs_impl,
    attrs = {
        "package": attr.label(
            providers = [CocoGeneratedCodeInfo],
            mandatory = True,
        ),
    },
)

def coco_test_outputs_name(name):
    return "%s.tst" % name

def coco_generate(name, **kwargs):
    _coco_generate(
        name = name,
        **kwargs
    )
    _coco_test_outputs(
        name = coco_test_outputs_name(name),
        package = name,
    )

def _popili_version_alias_impl(ctx):
    toolchain = ctx.toolchains["@rules_coco//coco:toolchain_type"]
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
    attrs = LICENSE_ATTRIBUTES,
    implementation = _popili_version_alias_impl,
    toolchains = ["@rules_coco//coco:toolchain_type"],
)

def popili_version_alias(name, **kwargs):
    _popili_version_alias(
        name = name,
        **kwargs
    )

# Exported for testing
mangle_name = _mangle_name
compute_output_filenames = _compute_output_filenames
