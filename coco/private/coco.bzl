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

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

CocoPackageInfo = provider(
    doc = "Information about a Coco package",
    fields = {
        "name": "The name of the package",
        "package_file": "The Coco.toml file for this package",
        "dep_package_files": "All Coco.toml files for all transitive dependencies",
        "srcs": "All .coco files that are sources of this package or any of its transitive dependencies",
        "test_srcs": "All .coco files that are test_sources of this package or any of its transitive dependencies",
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
    "license_file": attr.label(mandatory = False, allow_single_file = True),
    "_license_source": attr.label(default = Label("//:license_source")),
    "_license_token": attr.label(default = Label("//:license_token")),
}

COCO_TOOLCHAIN_TYPE = "@io_cocotec_rules_coco//coco:toolchain_type"

def _maybe_license_file():
    return select({
        "@io_cocotec_rules_coco//config/license_source:action_environment": None,
        "@io_cocotec_rules_coco//config/license_source:local_acquire": "@io_cocotec_licensing_fetch//:licenses",
        "@io_cocotec_rules_coco//config/license_source:local_user": "@io_cocotec_licensing_local//:licenses",
        "@io_cocotec_rules_coco//config/license_source:token": None,
    })

def _runtime_path(file, is_test):
    return file.short_path if is_test else file.path

def _coco_startup_args(ctx, package, is_test):
    arguments = [
        "--no-license-server",
        "--no-crash-reporter",
        "--override-preferences",
        _runtime_path(ctx.toolchains[COCO_TOOLCHAIN_TYPE].preferences_file, is_test),
        "--terminal=plain",
    ]
    if ctx.file.license_file:
        arguments.append("--override-licenses")
        arguments.append(_runtime_path(ctx.file.license_file, is_test))
    if package:
        arguments += [
            "--package",
            package[CocoPackageInfo].package_file.dirname,
        ]
        for package_file in package[CocoPackageInfo].dep_package_files.to_list():
            arguments += ["--import-path", package_file.dirname]
    return arguments

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
    if ctx.file.license_file:
        direct.append(ctx.file.license_file)
    if package:
        direct.append(package[CocoPackageInfo].package_file)
        transitive.append(package[CocoPackageInfo].srcs)
        transitive.append(package[CocoPackageInfo].dep_package_files)
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
        progress_message = "%s %s" % (verb, package[CocoPackageInfo].name),
        inputs = _coco_runfiles(ctx, package, False),
        outputs = outputs,
        arguments = _coco_startup_args(ctx, package, False) + arguments,
    )

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
    return [
        CocoPackageInfo(
            name = ctx.attr.name,
            package_file = package_file,
            dep_package_files = dep_package_files,
            srcs = srcs,
            test_srcs = test_srcs,
        ),
        DefaultInfo(files = depset(direct = [package_file], transitive = [srcs, test_srcs, dep_package_files])),
    ]

coco_package = rule(
    implementation = _coco_package_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".coco"],
            mandatory = True,
        ),
        "test_srcs": attr.label_list(
            allow_files = [".coco"],
            allow_empty = True,
        ),
        "package": attr.label(
            mandatory = True,
            allow_single_file = [".toml"],
        ),
        "deps": attr.label_list(providers = [CocoPackageInfo]),
    },
    toolchains = [
        COCO_TOOLCHAIN_TYPE,
    ],
)

def _coco_package_verify(ctx):
    coco_path = ctx.toolchains[COCO_TOOLCHAIN_TYPE].coco.short_path
    if ctx.attr.is_windows:
        coco_path = coco_path.replace("/", "\\")

    # Create the wrapper script to invoke Coco. We try and avoid using bash on Windows.
    arguments = [
        coco_path,
    ] + _coco_startup_args(ctx, ctx.attr.package, True) + [
        "verify",
        "--results-junit",
        "%%XML_OUTPUT_FILE%%" if ctx.attr.is_windows else "$XML_OUTPUT_FILE",
    ]

    backend = ctx.attr._verification_backend[BuildSettingInfo].value
    if backend != "":
        arguments.append("--backend")
        arguments.append(backend)

    command = " ".join(arguments)
    env = _coco_env(ctx)
    wrapper_lines = []
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

    return DefaultInfo(
        executable = wrapper_script,
        runfiles = ctx.runfiles(transitive_files = _coco_runfiles(ctx, ctx.attr.package, True)),
    )

_coco_package_verify_test = rule(
    implementation = _coco_package_verify,
    attrs = dict(LICENSE_ATTRIBUTES.items() + {
        "package": attr.label(
            providers = [CocoPackageInfo],
            mandatory = True,
        ),
        "is_windows": attr.bool(mandatory = True),
        "_verification_backend": attr.label(default = Label("//:verification_backend")),
    }.items()),
    test = True,
    toolchains = [
        COCO_TOOLCHAIN_TYPE,
    ],
)

def coco_package_verify_test(**kwargs):
    _coco_package_verify_test(
        is_windows = select({
            "@bazel_tools//src/conditions:host_windows": True,
            "//conditions:default": False,
        }),
        license_file = _maybe_license_file(),
        **kwargs
    )

def _add_outputs(ctx, outputs, mock_outputs, src):
    if ctx.attr.language == "cpp":
        if ctx.attr.mocks:
            for ext in ["Mock.h", "Mock.cc"]:
                mock_outputs.append(ctx.actions.declare_file(paths.replace_extension(src.basename, ext), sibling = src))

        for ext in [".h", ".cc"]:
            outputs.append(ctx.actions.declare_file(paths.replace_extension(src.basename, ext), sibling = src))
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
    srcs = ctx.attr.package[CocoPackageInfo].srcs
    test_srcs = ctx.attr.package[CocoPackageInfo].test_srcs
    package_dir = ctx.attr.package[CocoPackageInfo].package_file.dirname

    outputs = []
    mock_outputs = []
    test_outputs = []
    for src in srcs.to_list():
        _add_outputs(ctx, outputs, mock_outputs, src)
    for src in test_srcs.to_list():
        _add_outputs(ctx, test_outputs, mock_outputs, src)
    test_outputs += mock_outputs

    root_output_dir = _output_directory(package_dir, srcs)
    output_dir = paths.join(ctx.genfiles_dir.path, package_dir, root_output_dir)
    arguments = [
        "generate-%s" % ctx.attr.language,
        "--output",
        output_dir,
        "--output-empty-files",
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
            "--output-runtime-header=false",
        ]
    else:
        fail("unrecognised language")

    _run_coco(
        ctx = ctx,
        package = ctx.attr.package,
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

_coco_package_generate = rule(
    implementation = _coco_package_generate_impl,
    attrs = dict(LICENSE_ATTRIBUTES.items() + {
        "package": attr.label(
            providers = [CocoPackageInfo],
            mandatory = True,
        ),
        "language": attr.string(mandatory = True, values = ["cpp"]),
        "mocks": attr.bool(),
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

def coco_package_generate(name, **kwargs):
    _coco_package_generate(
        name = name,
        license_file = _maybe_license_file(),
        **kwargs
    )
    _coco_test_outputs(
        name = coco_test_outputs_name(name),
        package = name,
    )

def _popili_version_alias_impl(ctx):
    toolchain = ctx.toolchains["@io_cocotec_rules_coco//coco:toolchain_type"]
    return [
        toolchain,
        platform_common.TemplateVariableInfo({
            "POPILI": toolchain.coco.path,
            "POPILI_STARTUP_ARGS": " ".join(_coco_startup_args(ctx, None, True)),
        }),
        DefaultInfo(
            runfiles = ctx.runfiles(transitive_files = _coco_runfiles(ctx, None, True)),
        ),
    ]

_popili_version_alias = rule(
    attrs = LICENSE_ATTRIBUTES,
    implementation = _popili_version_alias_impl,
    toolchains = ["@io_cocotec_rules_coco//coco:toolchain_type"],
)

def popili_version_alias(name, **kwargs):
    _popili_version_alias(
        name = name,
        license_file = _maybe_license_file(),
        **kwargs
    )
