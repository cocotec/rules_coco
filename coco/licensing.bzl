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

load(":coco.bzl", "COCO_TOOLCHAIN_TYPE")

def _run_cocotec_license_server_impl(ctx):
    # Create the wrapper script to invoke Coco. We try and avoid using bash on Windows.
    arguments = [
        ctx.toolchains[COCO_TOOLCHAIN_TYPE].cocotec_licensing_server.path,
    ]
    runfiles = depset(
        direct = [
            ctx.toolchains[COCO_TOOLCHAIN_TYPE].cocotec_licensing_server,
        ],
    )

    if ctx.attr.is_windows:
        wrapper_script = ctx.actions.declare_file(ctx.label.name + "-cmd.bat")
        ctx.actions.write(
            output = wrapper_script,
            content = "%s \\%*\r\n" % " ".join(arguments),
            is_executable = True,
        )
    else:
        wrapper_script = ctx.actions.declare_file(ctx.label.name + "-cmd.sh")
        ctx.actions.write(
            output = wrapper_script,
            content = "%s $@\n" % " ".join(arguments),
            is_executable = True,
        )
    return DefaultInfo(
        executable = wrapper_script,
        runfiles = ctx.runfiles(transitive_files = runfiles),
    )

_run_cocotec_license_server = rule(
    attrs = {
        "is_windows": attr.bool(mandatory = True),
    },
    implementation = _run_cocotec_license_server_impl,
    toolchains = [
        COCO_TOOLCHAIN_TYPE,
    ],
    executable = True,
)

def run_cocotec_license_server(tags = [], **kwargs):
    _run_cocotec_license_server(
        is_windows = select({
            "@bazel_tools//src/conditions:host_windows": True,
            "//conditions:default": False,
        }),
        tags = ["no-remote-exec"] + tags,
        **kwargs
    )
