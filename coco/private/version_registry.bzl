# Copyright 2026 Cocotec Limited
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

"""The registry of popili versions registered in the @coco_toolchains hub.

The hub instantiates `coco_version_registry` in its `//versions` package. Rules read it to
reject pins naming an unregistered version with a message listing the registered ones, and
to pick the C/C++ runtime matching a package's version in the consumer's own configuration.

This file deliberately loads nothing, so the hub stays loadable in WORKSPACE mode before
rules_cc or bazel_skylib have been fetched.
"""

CocoVersionRegistryInfo = provider(
    doc = "The popili versions registered in the @coco_toolchains hub.",
    fields = {
        "c_runtimes": "Dict of version to the C runtime target registered for it",
        "cc_runtimes": "Dict of version to the C++ runtime target registered for it",
        "default": "The version used when --@rules_coco//:version is unset, or '' if none",
        "versions": "List of registered versions, including 'local' when a local toolchain is registered",
    },
)

def _coco_version_registry_impl(ctx):
    return [CocoVersionRegistryInfo(
        versions = ctx.attr.versions,
        default = ctx.attr.default,
        cc_runtimes = {version: target for target, version in ctx.attr.cc_runtimes.items()},
        c_runtimes = {version: target for target, version in ctx.attr.c_runtimes.items()},
    )]

coco_version_registry = rule(
    doc = "Records the popili versions registered in the @coco_toolchains hub. Internal to rules_coco.",
    implementation = _coco_version_registry_impl,
    attrs = {
        "c_runtimes": attr.label_keyed_string_dict(
            doc = "Map of C runtime target to the version it belongs to.",
        ),
        "cc_runtimes": attr.label_keyed_string_dict(
            doc = "Map of C++ runtime target to the version it belongs to.",
        ),
        "default": attr.string(
            doc = "The version used when --@rules_coco//:version is unset.",
        ),
        "versions": attr.string_list(
            doc = "The registered versions.",
        ),
    },
)

def format_registered_versions(registry):
    """Returns a human-readable list of the registered versions, for error messages.

    Args:
      registry: A CocoVersionRegistryInfo.

    Returns:
      A string such as '"1.5.0" (default), "1.5.1"'.
    """
    if not registry.versions:
        return "(none)"
    return ", ".join([
        "%r%s" % (version, " (default)" if version == registry.default else "")
        for version in registry.versions
    ])
