# Copyright 2024 Cocotec Limited
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

"""Formatting support for Coco packages."""

load(
    "//coco/private:coco.bzl",
    "COCO_TOOLCHAIN_TYPE",
    "CocoPackageInfo",
    "LICENSE_ATTRIBUTES",
    "_coco_env",
    "_coco_runfiles",
    "_coco_startup_args",
)

def _coco_fmt_test_impl(ctx):
    """Implementation for coco_fmt_test rule.

    Creates a test that runs 'popili format --verify' to check if Coco code
    is properly formatted. The test passes if code is formatted correctly,
    and fails if formatting changes are needed.
    """
    coco_path = ctx.toolchains[COCO_TOOLCHAIN_TYPE].coco.short_path
    if ctx.attr.is_windows:
        coco_path = coco_path.replace("/", "\\")

    # Build the command to run popili format --verify
    arguments = [
        coco_path,
    ] + _coco_startup_args(ctx, ctx.attr.package, True) + [
        "format",
        "--verify",
    ]

    command = " ".join(arguments)
    env = _coco_env(ctx)
    wrapper_lines = []

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

    return DefaultInfo(
        executable = wrapper_script,
        runfiles = ctx.runfiles(transitive_files = _coco_runfiles(ctx, ctx.attr.package, True)),
    )

_coco_fmt_test = rule(
    implementation = _coco_fmt_test_impl,
    attrs = dict(LICENSE_ATTRIBUTES.items() + {
        "is_windows": attr.bool(mandatory = True),
        "package": attr.label(
            providers = [CocoPackageInfo],
            mandatory = True,
            doc = "The coco_package target to check formatting for",
        ),
    }.items()),
    doc = """Test rule that verifies Coco code formatting.

This rule creates a test target that runs `popili format --verify` on the
specified coco_package. The test passes if all Coco source files are properly
formatted according to the formatting settings in the package's Coco.toml file.

Example:
    ```python
    coco_package(
        name = "my_pkg",
        package = "Coco.toml",
        srcs = glob(["src/**/*.coco"]),
    )

    coco_fmt_test(
        name = "my_pkg_fmt_test",
        package = ":my_pkg",
    )
    ```

To skip this test for specific targets, use standard Bazel tags:
    ```python
    coco_fmt_test(
        name = "generated_fmt_test",
        package = ":generated_pkg",
        tags = ["manual"],  # Only run when explicitly requested
    )
    ```
""",
    test = True,
    toolchains = [
        COCO_TOOLCHAIN_TYPE,
    ],
)

def coco_fmt_test(**kwargs):
    """Creates a test that verifies Coco code formatting.

    This is a wrapper around _coco_fmt_test that automatically handles
    platform-specific configuration.

    Args:
        **kwargs: All arguments are forwarded to the underlying rule.
            package: Required. The coco_package target to check formatting for.
            name: Required. The name of the test target.
    """
    _coco_fmt_test(
        is_windows = select({
            "@platforms//os:windows": True,
            "//conditions:default": False,
        }),
        **kwargs
    )
