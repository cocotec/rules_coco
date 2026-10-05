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

"""The registry of the C and C++ runtimes registered in the @coco_toolchains hub.

The hub instantiates `coco_version_registry` in its `//versions` package. Rules read it to
pick the C/C++ runtime matching the popili version code was generated with, in the
consumer's own configuration.

This file deliberately loads nothing, so the hub stays loadable in WORKSPACE mode before
rules_cc or bazel_skylib have been fetched.
"""

CocoVersionRegistryInfo = provider(
    doc = "The runtimes of the popili versions registered in the @coco_toolchains hub.",
    fields = {
        "c_runtimes": "Dict of version to the C runtime target registered for it",
        "cc_runtimes": "Dict of version to the C++ runtime target registered for it",
    },
)

def _coco_version_registry_impl(ctx):
    return [CocoVersionRegistryInfo(
        cc_runtimes = {version: target for target, version in ctx.attr.cc_runtimes.items()},
        c_runtimes = {version: target for target, version in ctx.attr.c_runtimes.items()},
    )]

coco_version_registry = rule(
    doc = "Records the runtimes of the popili versions registered in the @coco_toolchains hub. Internal to rules_coco.",
    implementation = _coco_version_registry_impl,
    attrs = {
        "c_runtimes": attr.label_keyed_string_dict(
            doc = "Map of C runtime target to the version it belongs to.",
        ),
        "cc_runtimes": attr.label_keyed_string_dict(
            doc = "Map of C++ runtime target to the version it belongs to.",
        ),
    },
)
