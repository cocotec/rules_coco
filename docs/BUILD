# Copyright 2024 Cocotec Limited
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

"""Documentation generation for rules_coco."""

load("@stardoc//stardoc:stardoc.bzl", "stardoc")

# Generate documentation for main public API
stardoc(
    name = "defs",
    out = "defs.md",
    input = "//coco:defs.bzl",
    deps = ["//coco:defs"],
)

stardoc(
    name = "cc",
    out = "cc.md",
    input = "//coco:cc.bzl",
    deps = ["//coco:cc"],
)

stardoc(
    name = "c",
    out = "c.md",
    input = "//coco:c.bzl",
    deps = ["//coco:c"],
)

stardoc(
    name = "repositories",
    out = "repositories.md",
    input = "//coco:repositories.bzl",
    deps = ["//coco:repositories"],
)

stardoc(
    name = "extensions",
    out = "extensions.md",
    input = "//coco:extensions.bzl",
    deps = ["//coco:extensions"],
)

# Generate index/overview documentation
filegroup(
    name = "docs",
    srcs = [
        "c.md",
        "cc.md",
        "defs.md",
        "extensions.md",
        "repositories.md",
    ],
    visibility = ["//visibility:public"],
)
