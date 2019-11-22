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

CocoInfo = provider(fields = {
    "name": "",
    "package_file": "All Coco.toml files",
    "dep_package_files": "All Coco.toml files",
    "srcs": "",
    "dep_srcs": "",
})

COCO_TOOLCHAIN_TYPE = "@io_cocotec_rules_coco//coco:toolchain_type"

def _coco_startup_args(ctx, package):
    arguments = [
        "--no-license-server",
        "--package",
        package[CocoInfo].package_file.path,
    ]
    for package_file in package[CocoInfo].dep_package_files.to_list():
        arguments += ["--import-path", package_file.dirname]
    return arguments

def _run_coco(ctx, package, verb, arguments, outputs):
    ctx.actions.run(
        executable = ctx.toolchains[COCO_TOOLCHAIN_TYPE].coco,
        tools = [
            ctx.toolchains[COCO_TOOLCHAIN_TYPE].coco,
            ctx.toolchains[COCO_TOOLCHAIN_TYPE].crashpad_handler,
        ],
        progress_message = "%s %s" % (verb, package[CocoInfo].name),
        inputs = depset(
            direct = [
                package[CocoInfo].package_file,
            ],
            transitive = [
                package[CocoInfo].srcs,
                package[CocoInfo].dep_package_files,
            ],
        ),
        outputs = outputs,
        arguments = _coco_startup_args(ctx, package) + arguments,
    )

def _coco_package_impl(ctx):
    if ctx.file.package.basename != "Coco.toml":
        fail("Package must point to a file called exactly 'Coco.toml'", attr = "package")
    dep_package_files = depset(
        direct = [dep[CocoInfo].package_file for dep in ctx.attr.deps],
        transitive = [dep[CocoInfo].dep_package_files for dep in ctx.attr.deps],
    )
    srcs = depset(
        direct = ctx.files.srcs,
        transitive = [dep[CocoInfo].srcs for dep in ctx.attr.deps],
    )
    return CocoInfo(
        name = ctx.attr.name,
        package_file = ctx.file.package,
        dep_package_files = dep_package_files,
        srcs = srcs,
    )

_coco_package = rule(
    implementation = _coco_package_impl,
    attrs = {
        "srcs": attr.label_list(
            #     doc = _tidy("""
            #     List of Coco `.coco` source files used to build the library.
            #     If `srcs` contains more than one file, then there must be a file either
            #     named `lib.rs`. Otherwise, `crate_root` must be set to the source file that
            #     is the root of the crate to be passed to rustc to build this crate.
            # """),
            allow_files = [".coco"],
            mandatory = True,
        ),
        "package": attr.label(
            mandatory = True,
            allow_single_file = [".toml"],
        ),
        "deps": attr.label_list(providers = [CocoInfo]),
    },
    toolchains = [
        COCO_TOOLCHAIN_TYPE,
    ],
)

def _coco_package_verify(ctx):
    # Create the wrapper script to invoke Coco. We try and avoid using bash on Windows.
    arguments = [
        ctx.toolchains[COCO_TOOLCHAIN_TYPE].coco.path,
    ] + _coco_startup_args(ctx, ctx.attr.package) + [
        "verify",
        "--format=junit",
    ]

    runfiles = depset(
        direct = [
            ctx.attr.package[CocoInfo].package_file,
            ctx.toolchains[COCO_TOOLCHAIN_TYPE].coco,
            ctx.toolchains[COCO_TOOLCHAIN_TYPE].crashpad_handler,
        ],
        transitive = [
            ctx.attr.package[CocoInfo].srcs,
            ctx.attr.package[CocoInfo].dep_package_files,
        ],
    )

    if ctx.attr.is_windows:
        wrapper_script = ctx.actions.declare_file(ctx.label.name + "-cmd.bat")
        ctx.actions.write(
            output = wrapper_script,
            content = "%s > $XML_OUTPUT_FILE" % " ".join(arguments),
            is_executable = True,
        )
    else:
        wrapper_script = ctx.actions.declare_file(ctx.label.name + "-cmd.sh")
        ctx.actions.write(
            output = wrapper_script,
            content = "%s > $XML_OUTPUT_FILE" % (" ".join(arguments)),
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
            providers = [CocoInfo],
            mandatory = True,
        ),
        "is_windows": attr.bool(mandatory = True),
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
        tags = ["no-remote-exec"],
    )

def _coco_package_generate_impl(ctx):
    srcs = ctx.attr.package[CocoInfo].srcs
    package_dir = ctx.attr.package[CocoInfo].package_file.dirname

    # Calculate output directory
    outputs = []
    root_output_dir = None
    for src in srcs.to_list():
        relative_to_package = paths.relativize(src.dirname, package_dir)
        if not root_output_dir or len(relative_to_package) < len(root_output_dir):
            root_output_dir = relative_to_package

        files = []
        if ctx.attr.language == "cpp":
            if ctx.attr.mocks:
                files = [paths.replace_extension(src.basename, "Mock.h"), paths.replace_extension(src.basename, "Mock.cc")]
            else:
                files = [paths.replace_extension(src.basename, ".h"), paths.replace_extension(src.basename, ".cc")]

        outputs += [ctx.actions.declare_file(file, sibling = src) for file in files]

    arguments = [
        "generate-%s" % ctx.attr.language,
        "--output",
        paths.join(ctx.genfiles_dir.path, package_dir, root_output_dir),
        "--output-empty-files",
    ]
    if ctx.attr.mocks:
        arguments += ["--mocks=" + ctx.attr.mocks]
    if ctx.attr.language == "cpp":
        # Make all include paths absolute within the workspace to avoid the need for includes
        arguments += [
            "--include-prefix",
            paths.join(package_dir, root_output_dir),
        ]

    _run_coco(
        ctx = ctx,
        package = ctx.attr.package,
        verb = "Generating %s" % ctx.attr.language,
        arguments = arguments,
        outputs = outputs,
    )

    return DefaultInfo(
        files = depset(outputs),
    )

_coco_package_generate = rule(
    implementation = _coco_package_generate_impl,
    attrs = {
        "package": attr.label(
            providers = [CocoInfo],
            mandatory = True,
        ),
        "language": attr.string(mandatory = True, values = ["cpp"]),
        "mocks": attr.string(),
    },
    toolchains = [
        COCO_TOOLCHAIN_TYPE,
    ],
)

def coco_cc_library(name, package, srcs = [], deps = [], **kwargs):
    _coco_package_generate(
        name = name + "_srcs",
        package = package,
        language = "cpp",
        tags = ["no-remote-exec"],
    )
    cc_library(
        name = name,
        srcs = srcs + [":%s_srcs" % name],
        deps = deps + ["@io_cocotec_coco_cc_runtime"],
        **kwargs
    )

def coco_cc_gmock_library(
        name,
        package,
        srcs = [],
        deps = [],
        gmock = "@com_github_google_googletest//:gtest",
        **kwargs):
    _coco_package_generate(
        name = name + "_srcs",
        package = package,
        language = "cpp",
        mocks = "gmock",
        tags = ["no-remote-exec"],
    )
    cc_library(
        name = name,
        srcs = srcs + [":%s_srcs" % name],
        deps = deps + [gmock],
        **kwargs
    )
