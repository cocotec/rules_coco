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

# A package with testSources: popili reads the test sources too, so they must be inputs of its actions.
load("@rules_coco//coco:defs.bzl", "coco_package", "coco_verify_test")

coco_package(
    name = "test_sources",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
    test_srcs = glob(["test/**/*.coco"]),
)

coco_verify_test(
    name = "test_sources_verify",
    package = ":test_sources",
)
