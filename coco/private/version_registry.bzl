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

"""The registry targets of the toolchain hub: what it registered, readable from rules.

The generated hub BUILD loads this file, so it must load nothing itself: in WORKSPACE mode the
hub is evaluated before bazel_skylib has necessarily been fetched.
"""

CocoVersionRegistryInfo = provider(
    doc = "What the Coco toolchain hub (`@coco_toolchains//:registry`) registered.",
    fields = {
        "versions": (
            "The registered versions in registration order, with `local` last when a local " +
            "distribution is registered. The first entry is the default, except that a " +
            "local-only registration has no default: `local` is only ever selected explicitly."
        ),
    },
)

_RegisteredVersionsInfo = provider(
    doc = "The value of a `coco_registered_versions` setting.",
    fields = ["versions"],
)

def _coco_registered_versions_impl(ctx):
    return [_RegisteredVersionsInfo(versions = ctx.build_setting_value)]

coco_registered_versions = rule(
    doc = (
        "A string-list build setting holding the hub's registered versions in registration " +
        "order (`@coco_toolchains//:registered_versions`). Transitions read it; nothing sets it."
    ),
    implementation = _coco_registered_versions_impl,
    build_setting = config.string_list(),
)

def _coco_version_registry_impl(ctx):
    return [CocoVersionRegistryInfo(
        versions = ctx.attr.registered_versions[_RegisteredVersionsInfo].versions,
    )]

coco_version_registry = rule(
    doc = "Provides `CocoVersionRegistryInfo` for the hub (`@coco_toolchains//:registry`).",
    implementation = _coco_version_registry_impl,
    attrs = {
        "registered_versions": attr.label(
            doc = "The `coco_registered_versions` setting whose value `versions` reports.",
            mandatory = True,
            providers = [_RegisteredVersionsInfo],
        ),
    },
)
