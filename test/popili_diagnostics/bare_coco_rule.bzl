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

"""Custom rules that resolve the Coco toolchain without all of TOOLCHAIN_ATTRIBUTES."""

load("@rules_coco//coco/private:coco.bzl", "COCO_TOOLCHAIN_TYPE", "TOOLCHAIN_ATTRIBUTES", "coco_toolchain_or_fail")  # buildifier: disable=bzl-visibility

def _bare_coco_rule_impl(ctx):
    coco_toolchain_or_fail(ctx)
    return []

bare_coco_rule = rule(
    implementation = _bare_coco_rule_impl,
    toolchains = [COCO_TOOLCHAIN_TYPE],
)

# The version and the registry, but not where the version came from.
partial_coco_rule = rule(
    implementation = _bare_coco_rule_impl,
    attrs = {name: TOOLCHAIN_ATTRIBUTES[name] for name in ["_version", "_version_registry"]},
    toolchains = [COCO_TOOLCHAIN_TYPE],
)
