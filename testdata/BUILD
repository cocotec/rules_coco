# Copyright 2025 Cocotec Limited
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

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

# The name mangling conformance corpus, shared with popili. See README.md.
#
# This is public on purpose: popili depends on rules_coco as a Bazel module and
# loads this file directly, so that both repositories assert against the same
# cases. Keep it loadable from outside the repository.
exports_files(
    ["name_mangling_corpus.bzl"],
    visibility = ["//visibility:public"],
)

bzl_library(
    name = "name_mangling_corpus",
    srcs = ["name_mangling_corpus.bzl"],
    visibility = ["//visibility:public"],
)
