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

"""Public API for Coco package rules and code generation."""

load(
    "//coco/private:coco.bzl",
    _coco_generate = "coco_generate",
    _coco_package = "coco_package",
    _coco_test_outputs_name = "coco_test_outputs_name",
    _coco_verify_test = "coco_verify_test",
    _with_popili_version = "with_popili_version",
)
load(
    "//coco/private:diagram.bzl",
    _coco_architecture_diagram = "coco_architecture_diagram",
    _coco_counterexample_diagram = "coco_counterexample_diagram",
    _coco_state_diagram = "coco_state_diagram",
    _counterexample_options = "counterexample_options",
)
load(
    "//coco/private:format.bzl",
    _coco_fmt_test = "coco_fmt_test",
)
load(
    "//coco/private:licensing.bzl",
    _LICENSE_SOURCES = "LICENSE_SOURCES",
)

coco_package = _coco_package

coco_verify_test = _coco_verify_test

coco_generate = _coco_generate

coco_fmt_test = _coco_fmt_test

coco_test_outputs_name = _coco_test_outputs_name

with_popili_version = _with_popili_version

coco_architecture_diagram = _coco_architecture_diagram

coco_state_diagram = _coco_state_diagram

coco_counterexample_diagram = _coco_counterexample_diagram

counterexample_options = _counterexample_options

LICENSE_SOURCES = _LICENSE_SOURCES
