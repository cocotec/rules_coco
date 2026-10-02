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

load(":coco.bzl", "POPILI_TOOLCHAINS", "exec_popili")

def _acquire_license(ctx, licensing_server):
    # Named after the target: a repository defines several of them, one per licence version.
    output = ctx.actions.declare_file(ctx.label.name + ".lic")
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
        executable = licensing_server,
        arguments = arguments,
        tools = [licensing_server],
        mnemonic = "CocoFetchLicense",
        progress_message = "Acquiring Coco license",
        inputs = [ctx.file.auth_token],
        outputs = [output],
    )

    return DefaultInfo(
        files = depset([output]),
    )

def _fetch_license_with_toolchain_impl(ctx):
    # For toolchains registered outside rules_coco only (see @io_cocotec_licensing_fetch). It
    # is analysed in each consuming rule's configuration, which may have no Coco toolchain,
    # e.g. one forcing an unregistered popili version. Failing here would pre-empt
    # rules_coco's own "not registered" error, and the rules that need a toolchain fail
    # clearly on their own.
    toolchain = exec_popili(ctx)
    if toolchain == None:
        return DefaultInfo(files = depset())

    # The licensing server of this target's own execution platform. Tagged no-remote-exec (see
    # fetch_license), so the generated target is also constrained to the host, where it runs.
    return _acquire_license(ctx, toolchain.cocotec_licensing_server)

def _fetch_license_with_server_impl(ctx):
    return _acquire_license(ctx, ctx.file.licensing_server)

_FETCH_LICENSE_ATTRS = {
    "auth_token": attr.label(allow_single_file = True),
    "product": attr.string(default = "popili"),
}

_fetch_license_with_toolchain = rule(
    attrs = _FETCH_LICENSE_ATTRS,
    implementation = _fetch_license_with_toolchain_impl,
    toolchains = POPILI_TOOLCHAINS,
)

# Deliberately no toolchain: resolving one would analyse, and so download, a Coco toolchain
# just to acquire a licence.
_fetch_license_with_server = rule(
    attrs = dict(_FETCH_LICENSE_ATTRS.items() + {
        "licensing_server": attr.label(
            allow_single_file = True,
            cfg = "exec",
            mandatory = True,
        ),
    }.items()),
    implementation = _fetch_license_with_server_impl,
)

def fetch_license(tags = [], licensing_server = None, **kwargs):
    """Acquires a licence with COCOTEC_AUTH_TOKEN.

    Args:
      tags: Extra tags. Acquisition needs the network and the host, so it is never run
        remotely or cached remotely.
      licensing_server: The cocotec-licensing-server to acquire with. Without it, the Coco
        toolchain resolved for this target's configuration provides one.
      **kwargs: Passed to the rule.
    """
    tags = ["no-remote-exec", "no-remote-cache", "requires-network"] + tags
    if licensing_server:
        _fetch_license_with_server(tags = tags, licensing_server = licensing_server, **kwargs)
    else:
        _fetch_license_with_toolchain(tags = tags, **kwargs)

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
