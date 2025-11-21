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

"""Licensing rules and helpers for Coco."""

load(":coco.bzl", "COCO_TOOLCHAIN_TYPE")

def _fetch_license_impl(ctx):
    # Create the wrapper script to invoke Coco. We try and avoid using bash on Windows.
    output = ctx.actions.declare_file("licenses.lic")
    arguments = [
        "--no-crash-reporter",
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
        mnemonic = "CocoFetchLicense",
        progress_message = "Acquiring Coco license",
        inputs = [ctx.file.auth_token],
        outputs = [output],
    )

    return DefaultInfo(
        files = depset([output]),
    )

_fetch_license = rule(
    attrs = {
        "auth_token": attr.label(allow_single_file = True),
        "product": attr.string(),
    },
    implementation = _fetch_license_impl,
    toolchains = [
        COCO_TOOLCHAIN_TYPE,
    ],
)

def fetch_license(tags = [], **kwargs):
    _fetch_license(
        tags = ["no-remote-exec", "no-remote-cache", "requires-network"] + tags,
        **kwargs
    )

LICENSE_SOURCES = [
    # Suitable credentials will be provided in the execution environment of each action. What is supported will depend
    # on the version of Coco, but could include COCOTEC_AUTH_TOKEN being injected into the environment via some
    # non-bazel mechanism.
    "action_environment",

    # An auth token file path will be provided that is available in the execution environment of each action.
    # The file path should be specified via --@rules_coco//:auth_token_path or in the toolchain configuration.
    # Popili will be invoked with --machine-auth-token pointing to this file.
    # Requires popili 1.5.2 or later.
    "action_file",

    # A license will be acquired on the local machine as part of the build using COCOTEC_AUTH_TOKEN.
    #
    # This is not compatible with remote execution.
    "local_acquire",

    # The user's existing license on this machine will be reused.
    #
    # This is not compatible with remote execution.
    "local_user",

    # The explicitly provided token should be used as COCOTEC_AUTH_TOKEN. In this case,
    # --@rules_coco//:license_token must be set as well
    "token",
]
