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

load("@rules_cc//cc:defs.bzl", "cc_library")
load("@bazel_skylib//lib:paths.bzl", "paths")

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

COCO_TOOLCHAIN_TYPE = "@io_cocotec_rules_coco//coco:toolchain_type"

def _runtime_path(file, is_test):
    return file.short_path if is_test else file.path

def _coco_startup_args(ctx, package, is_test):
    arguments = [
        "--no-license-server",
        "--no-crash-reporter",
        "--override-licenses",
        _runtime_path(ctx.file._license_file, is_test),
        "--override-preferences",
        _runtime_path(ctx.toolchains[COCO_TOOLCHAIN_TYPE].preferences_file, is_test),
        "--package",
        package[CocoPackageInfo].package_file.dirname,
    ]
    for package_file in package[CocoPackageInfo].dep_package_files.to_list():
        arguments += ["--import-path", package_file.dirname]
    return arguments

def _run_coco(ctx, package, verb, arguments, outputs):
    ctx.actions.run(
        executable = ctx.toolchains[COCO_TOOLCHAIN_TYPE].coco,
        tools = [
            ctx.toolchains[COCO_TOOLCHAIN_TYPE].coco,
        ],
        progress_message = "%s %s" % (verb, package[CocoPackageInfo].name),
        inputs = depset(
            direct = [
                package[CocoPackageInfo].package_file,
                ctx.toolchains[COCO_TOOLCHAIN_TYPE].preferences_file,
                ctx.file._license_file,
            ],
            transitive = [
                package[CocoPackageInfo].srcs,
                package[CocoPackageInfo].dep_package_files,
            ],
        ),
        outputs = outputs,
        arguments = _coco_startup_args(ctx, package, False) + arguments,
    )

def _coco_package_impl(ctx):
    if ctx.file.package.basename != "Coco.toml":
        fail("Package must point to a file called exactly 'Coco.toml'", attr = "package")
    return CocoPackageInfo(
        name = ctx.attr.name,
        package_file = ctx.file.package,
        dep_package_files = depset(
            direct = [dep[CocoPackageInfo].package_file for dep in ctx.attr.deps],
            transitive = [dep[CocoPackageInfo].dep_package_files for dep in ctx.attr.deps],
        ),
        srcs = depset(
            direct = ctx.files.srcs,
            transitive = [dep[CocoPackageInfo].srcs for dep in ctx.attr.deps],
        ),
        test_srcs = depset(
            direct = ctx.files.test_srcs,
            transitive = [dep[CocoPackageInfo].test_srcs for dep in ctx.attr.deps],
        ),
    )

_coco_package = rule(
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
        "_license_file": attr.label(default = "@io_cocotec_licensing//:licenses", allow_single_file = True),
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
        "--format=junit",
        ctx.attr.verification_backend,
    ]

    runfiles = depset(
        direct = [
            ctx.attr.package[CocoPackageInfo].package_file,
            ctx.toolchains[COCO_TOOLCHAIN_TYPE].coco,
            ctx.toolchains[COCO_TOOLCHAIN_TYPE].preferences_file,
            ctx.file._license_file,
        ],
        transitive = [
            ctx.attr.package[CocoPackageInfo].srcs,
            ctx.attr.package[CocoPackageInfo].dep_package_files,
        ],
    )

    if ctx.attr.is_windows:
        wrapper_script = ctx.actions.declare_file(ctx.label.name + "-cmd.bat")
    else:
        wrapper_script = ctx.actions.declare_file(ctx.label.name + "-cmd.sh")
    ctx.actions.write(
        output = wrapper_script,
        content = "%s > %%XML_OUTPUT_FILE%%" % " ".join(arguments),
        is_executable = True,
    )
    return DefaultInfo(
        executable = wrapper_script,
        runfiles = ctx.runfiles(transitive_files = runfiles),
    )

_coco_package_verify_test = rule(
    implementation = _coco_package_verify,
    attrs = {
        "package": attr.label(
            providers = [CocoPackageInfo],
            mandatory = True,
        ),
        "is_windows": attr.bool(mandatory = True),
        "verification_backend": attr.string(values = ["", "--backend=remote"]),
        "_license_file": attr.label(default = "@io_cocotec_licensing//:licenses", allow_single_file = True),
    },
    test = True,
    toolchains = [
        COCO_TOOLCHAIN_TYPE,
    ],
)

def coco_package(name, tags = [], **kwargs):
    _coco_package(
        name = name,
        tags = ["no-remote-exec"] + tags,
        **kwargs
    )
    _coco_package_verify_test(
        name = name + "_verify",
        package = ":" + name,
        is_windows = select({
            "@bazel_tools//src/conditions:host_windows": True,
            "//conditions:default": False,
        }),
        verification_backend = select({
            "@io_cocotec_rules_coco//coco:remote_verification": "--backend=remote",
            "//conditions:default": "",
        }),
        tags = ["no-remote-exec", "requires-network"],
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
    attrs = {
        "package": attr.label(
            providers = [CocoPackageInfo],
            mandatory = True,
        ),
        "language": attr.string(mandatory = True, values = ["cpp"]),
        "mocks": attr.bool(),
        "_license_file": attr.label(default = "@io_cocotec_licensing//:licenses", allow_single_file = True),
    },
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

def _test_outputs_name(name):
    return "%s.tst" % name

def coco_package_generate(name, tags = [], **kwargs):
    _coco_package_generate(
        name = name,
        tags = ["no-remote-exec", "block-network"] + tags,
        **kwargs
    )
    _coco_test_outputs(
        name = _test_outputs_name(name),
        package = name,
    )

def coco_cc_library(name, generated_package, srcs = [], deps = [], **kwargs):
    cc_library(
        name = name,
        srcs = srcs + [generated_package],
        deps = deps + ["@io_cocotec_coco_cc_runtime//:runtime"],
        **kwargs
    )

def coco_cc_test_library(
        name,
        generated_package,
        srcs = [],
        deps = [],
        gmock = "@com_google_googletest//:gtest",
        **kwargs):
    cc_library(
        name = name,
        srcs = srcs + [_test_outputs_name(generated_package)],
        deps = deps + [gmock, "@io_cocotec_coco_cc_runtime//:testing"],
        **kwargs
    )
