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

load(
    "@rules_coco//coco:defs.bzl",
    "coco_architecture_diagram",
    "coco_counterexample_diagram",
    "coco_fmt_test",
    "coco_package",
    "counterexample_options",
)

coco_package(
    name = "diagrams",
    srcs = glob(["*.coco"]),
    package = "Coco.toml",
    typecheck = True,
)

coco_architecture_diagram(
    name = "outer_component_arch",
    components = {
        "outer.svg": "OuterEncapsulating",
    },
    package = ":diagrams",
    port_names = True,
    port_types = True,
)

coco_architecture_diagram(
    name = "multiple_components_arch",
    component_types = True,
    components = {
        "arch_alarm.svg": "Alarm",
        "arch_bottom.svg": "Bottom",
        "arch_logger.svg": "Logger",
        "arch_proxy.svg": "Proxy",
    },
    package = ":diagrams",
    port_names = False,
    port_types = True,
)

coco_architecture_diagram(
    name = "all_components_arch",
    component_names = True,
    components = {
        "outer_encapsulating.svg": "OuterEncapsulating",
    },
    package = ":diagrams",
)

coco_counterexample_diagram(
    name = "expected_counterexamples",
    counterexamples = {
        "alarm.svg": "Alarm",
        "bottom.svg": counterexample_options(decl = "Bottom"),
    },
    deterministic = True,
    package = ":diagrams",
)

coco_fmt_test(
    name = "diagrams_fmt_test",
    package = ":diagrams",
)
