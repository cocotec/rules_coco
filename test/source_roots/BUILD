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

# Packages with several or non-default source roots, one fixture directory per scenario; see scenario.bzl.
# Root inference itself is covered by the unit tests in //coco/private:coco_tests.

load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@rules_cc//cc:defs.bzl", "cc_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")
load(":scenario.bzl", "generate_flags_test", "package_failure_test", "source_root_scenario")

# sources = ["src", "interfaces"]: module paths are relative to each file's own root, so both roots' files
# are generated side by side.
source_root_scenario(
    name = "multi_root",
    srcs = glob([
        "multi_root/src/**/*.coco",
        "multi_root/interfaces/**/*.coco",
    ]),
    source_roots = [
        "src",
        "interfaces",
    ],
)

# sources = ["src/main"], testSources = ["test"], with mocks: both roots are inferred, and popili reads the
# test sources too, so they must be inputs of its actions.
source_root_scenario(
    name = "test_root",
    srcs = glob(["test_root/src/**/*.coco"]),
    mocks = True,
    test_srcs = glob(["test_root/test/**/*.coco"]),
)

# Everything, test code and mocks included, is written directly below the include root: the package
# has no includePrefix, so --output is the root itself, and no prefix is passed to popili.
generate_flags_test(
    name = "test_root_flags_test",
    target_under_test = ":test_root_cpp",
)

# The generated files of test_root, included as the generated code includes them: by module path.
cc_library(
    name = "test_root_includes",
    srcs = ["includes/default.cc"],
    deps = [":test_root_cc_tst"],
)

# include_prefix may not leave the generate's include root.
coco_generate(
    name = "test_root_escaping_cpp",
    include_prefix = "../test_root",
    language = "cpp",
    package = ":test_root",
    tags = ["manual"],
)

package_failure_test(
    name = "test_root_escaping_test",
    expected_message = "include_prefix must be a normalised relative path within the include root",
    target_under_test = ":test_root_escaping_cpp",
)

# C# has no include prefix.
coco_generate(
    name = "test_root_csharp_prefix",
    include_prefix = "x",
    language = "csharp",
    package = ":test_root",
    tags = ["manual"],
)

package_failure_test(
    name = "test_root_csharp_prefix_test",
    expected_message = "include_prefix is not supported for language = \"csharp\"",
    target_under_test = ":test_root_csharp_prefix",
)

build_test(
    name = "include_prefix_build_test",
    targets = [":test_root_includes"],
)

# sources = ["src", "../outside_root_shared"]: a root outside the Coco.toml directory. Module paths are
# relative to that root (api/Runnable).
source_root_scenario(
    name = "outside_root",
    srcs = glob([
        "outside_root/src/**/*.coco",
        "outside_root_shared/**/*.coco",
    ]),
    source_roots = [
        "src",
        "../outside_root_shared",
    ],
)

# source_roots that do not cover every source file must fail at analysis time, with a hint.
coco_package(
    name = "root_mismatch",
    srcs = glob([
        "multi_root/src/**/*.coco",
        "multi_root/interfaces/**/*.coco",
    ]),
    package = "multi_root/Coco.toml",
    source_roots = ["src"],
    tags = ["manual"],
)

package_failure_test(
    name = "root_mismatch_test",
    expected_message = "source_roots must match `sources` in Coco.toml",
    target_under_test = ":root_mismatch",
)

# Sources outside the Coco.toml directory cannot be placed by inference, so source_roots is required.
coco_package(
    name = "outside_root_inferred",
    srcs = glob([
        "outside_root/src/**/*.coco",
        "outside_root_shared/**/*.coco",
    ]),
    package = "outside_root/Coco.toml",
    tags = ["manual"],
)

package_failure_test(
    name = "outside_root_inferred_test",
    expected_message = "outside the directory containing Coco.toml of ",
    target_under_test = ":outside_root_inferred",
)
