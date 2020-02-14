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

def _fetch_license_impl(ctx):
    # Create the wrapper script to invoke Coco. We try and avoid using bash on Windows.
    output = ctx.actions.declare_file("licenses.lic")
    arguments = [
        "--machine-auth-token",
        ctx.file.auth_token.path,
        "--license-file",
        output.path,
        "--acquire",
        ctx.attr.product,
    ]

    ctx.actions.run(
        executable = ctx.toolchains[COCO_TOOLCHAIN_TYPE].cocotec_licensing_server,
        arguments = arguments,
        tools = [ctx.toolchains[COCO_TOOLCHAIN_TYPE].cocotec_licensing_server],
        inputs = [ctx.file.auth_token],
        outputs = [output],
    )

    return DefaultInfo(
        files = depset([output]),
    )

_fetch_license = rule(
    attrs = {
        "auth_token": attr.label(allow_single_file = True),
        "is_windows": attr.bool(mandatory = True),
        "product": attr.string(),
    },
    implementation = _fetch_license_impl,
    toolchains = [
        COCO_TOOLCHAIN_TYPE,
    ],
)

def fetch_license(tags = [], **kwargs):
    _fetch_license(
        is_windows = select({
            "@bazel_tools//src/conditions:host_windows": True,
            "//conditions:default": False,
        }),
        tags = ["no-remote-exec", "no-remote-cache", "requires-network"] + tags,
        **kwargs
    )
