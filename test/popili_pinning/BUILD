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

load("@rules_coco//coco:defs.bzl", "coco_generate")
load(":pinning_test.bzl", "popili_pinning_tests")

# The root registers `stable` and `testing`, so //test/simple pins its coco_generate and its
# libraries to the alias `stable`, which the transitions have to resolve for anything to build.
# Which popili each rule runs with a pin is asserted per rule by e2e/multi_version, which has two
# versions to choose between; here only what needs the root's registration is checked.

# Pinned to a version nobody registered; reached only by the analysis tests. In this package, so
# that forced into the configuration of //test/simple:base_cpp it does not write that target's files.
coco_generate(
    name = "unregistered_cpp",
    language = "cpp",
    package = "//test/simple:base",
    popili_version = "1.99.0",
    tags = ["manual"],
)

popili_pinning_tests(
    name = "pinning",
    # A library's pin is read off its ._gen target, whose CcInfo carries the runtime.
    alias_pinned = {
        "cc_library": "//test/simple:base_cc._gen",
        "generate": "//test/simple:base_cpp",
    },
    current_popili_version = "@rules_coco//coco:current_popili_version",
    unregistered = ":unregistered_cpp",
)
