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

# How coco_generate picks its output root (_output_directory), one fixture directory per scenario.
# Each scenario gets an analysis test (<name>_test, no popili) and a popili probe (<name>_popili_test);
# see layout_test.bzl. The analysis tests for everything but single_root and test_root fail on purpose
# until TODO-output-directory.md is resolved.

load(":layout_test.bzl", "output_layout_scenario")
load(":layouts.bzl", "LAYOUTS")

# Control: sources = ["src"], all files directly in src/.
output_layout_scenario(
    name = "single_root",
    srcs = glob(["single_root/src/**/*.coco"]),
    expected_output = "src",
    layout = LAYOUTS["single_root"],
)

# sources = ["src"], with a subdirectory that sorts before the top-level file
# (src/Api/Runnable.coco < src/Comp.coco). The shortest-path heuristic picks "src/Api".
output_layout_scenario(
    name = "deep_first",
    srcs = glob(["deep_first/src/**/*.coco"]),
    expected_output = "src",
    layout = LAYOUTS["deep_first"],
)

# sources = ["."], one file next to Coco.toml and one in sub/.
output_layout_scenario(
    name = "beside_manifest",
    srcs = glob(["beside_manifest/**/*.coco"]),
    expected_output = "",
    layout = LAYOUTS["beside_manifest"],
)

# sources = ["src"], but every file is in src/a/. popili still writes relative to src, so the right root
# is "src", which cannot be derived from the file paths.
output_layout_scenario(
    name = "nested_only",
    srcs = glob(["nested_only/src/**/*.coco"]),
    expected_output = "src",
    layout = LAYOUTS["nested_only"],
)

# sources = ["src", "generated"]. The layout records what popili does with two roots and one --output;
# which --output the rule should pass is still open, so it is not checked.
output_layout_scenario(
    name = "multi_root",
    srcs = glob([
        "multi_root/src/**/*.coco",
        "multi_root/generated/**/*.coco",
    ]),
    layout = LAYOUTS["multi_root"],
)

# sources = ["src/main"], testSources = ["test"]: the test root is shallower than the source root.
output_layout_scenario(
    name = "test_root",
    srcs = glob(["test_root/src/**/*.coco"]),
    expected_output = "src/main",
    expected_test_output = "test",
    layout = LAYOUTS["test_root"],
    mocks = True,
    test_srcs = glob(["test_root/test/**/*.coco"]),
)
