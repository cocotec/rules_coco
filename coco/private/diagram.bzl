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

"""Diagram generation support for Coco packages."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load(
    "//coco/private:coco.bzl",
    "COCO_TOOLCHAIN_TYPE",
    "CocoPackageInfo",
    "LICENSE_ATTRIBUTES",
    "run_coco",
)

def counterexample_options(decl, assertion = None):
    """Specify counterexample filtering options.

    Args:
        decl: Target declaration name (required)
        assertion: Assertion text to filter (optional, only needed if multiple counterexamples for the target)

    Returns:
        Struct with decl and assertion fields for use in coco_counterexample_diagram
    """
    return struct(
        decl = decl,
        assertion = assertion,
    )

def _coco_architecture_diagram_impl(ctx):
    """Implementation for coco_architecture_diagram rule.

    Generates architecture diagrams using `popili graph-component`.
    """
    package = ctx.attr.package

    filenames = ctx.attr.component_filenames
    targets = ctx.attr.component_targets

    # Declare output files
    outputs = []
    for filename in filenames:
        outputs.append(ctx.actions.declare_file(filename))

    # Build command arguments for each component
    for i in range(len(filenames)):
        component = targets[i]
        arguments = ["graph-component"]

        # Add component selection
        if component:
            arguments += ["--component", component]

        # Add display options
        if ctx.attr.port_names:
            arguments.append("--port-names")
        if not ctx.attr.port_types:
            arguments.append("--port-types=false")
        if ctx.attr.component_names:
            arguments.append("--component-names")
        if not ctx.attr.component_types:
            arguments.append("--component-types=false")

        # Add layout options
        if ctx.attr.depth:
            arguments += ["--depth", ctx.attr.depth]
        if ctx.attr.hide_ports:
            arguments.append("--hide-ports")
        if not ctx.attr.only_encapsulating:
            arguments.append("--only-encapsulating=false")
        if ctx.attr.only_roots:
            arguments.append("--only-roots")

        # Add output
        arguments += ["--output", outputs[i].path]

        # Run command for this component
        run_coco(
            ctx = ctx,
            package = package,
            verb = "Generating architecture diagram for",
            mnemonic = "CocoDiagram",
            arguments = arguments,
            outputs = [outputs[i]],
        )

    return [DefaultInfo(files = depset(outputs))]

_coco_architecture_diagram = rule(
    implementation = _coco_architecture_diagram_impl,
    attrs = dict(LICENSE_ATTRIBUTES.items() + {
        "component_filenames": attr.string_list(
            mandatory = True,
            doc = "List of output filenames (internal use - populated by macro)",
        ),
        "component_names": attr.bool(
            default = False,
            doc = "Show instance name of child components",
        ),
        "component_targets": attr.string_list(
            mandatory = True,
            doc = "List of component names to generate diagrams for (internal use - populated by macro)",
        ),
        "component_types": attr.bool(
            default = True,
            doc = "Show type of each component",
        ),
        # Layout options
        "depth": attr.string(
            default = "",
            doc = "Recursive drawing depth: integer, 'auto', or 'max'. Empty string uses default.",
        ),
        "hide_ports": attr.bool(
            default = False,
            doc = "Draw simpler diagrams for encapsulating components",
        ),
        "only_encapsulating": attr.bool(
            default = True,
            doc = "Don't draw implementation/external components",
        ),
        "only_roots": attr.bool(
            default = False,
            doc = "Only draw root components",
        ),
        "package": attr.label(
            providers = [CocoPackageInfo],
            mandatory = True,
            doc = "The coco_package target to generate architecture diagrams for",
        ),
        # Display options
        "port_names": attr.bool(
            default = False,
            doc = "Show instance name of each port",
        ),
        "port_types": attr.bool(
            default = True,
            doc = "Show type of each port",
        ),
    }.items()),
    doc = """Generates architecture diagrams for Coco components.

This rule generates SVG diagrams showing component architecture using `popili graph-component`.

Example (single component):
    ```python
    coco_package(
        name = "my_pkg",
        package = "Coco.toml",
        srcs = glob(["src/**/*.coco"]),
    )

    coco_architecture_diagram(
        name = "my_component_arch",
        package = ":my_pkg",
        components = {
            "my_component.svg": "MyComponent",
        },
        port_names = True,
        port_types = True,
    )
    ```

Example (multiple components):
    ```python
    coco_architecture_diagram(
        name = "all_architectures",
        package = ":my_pkg",
        components = {
            "component1.svg": "Component1",
            "component2.svg": "Component2",
        },
    )
    ```
""",
    toolchains = [COCO_TOOLCHAIN_TYPE],
)

def _coco_state_diagram_impl(ctx):
    """Implementation for coco_state_diagram rule.

    Generates state machine diagrams using `popili graph-states`.
    """
    package = ctx.attr.package

    # Determine targets to generate
    targets = ctx.attr.targets if ctx.attr.targets else [""]

    # Declare output files
    outputs = []
    if len(targets) == 1:
        # Single target: use rule name
        output = ctx.actions.declare_file(ctx.label.name + ".svg")
        outputs.append(output)
    else:
        # Multiple targets: create one file per target
        for target in targets:
            if target:
                filename = "%s_%s.svg" % (ctx.label.name, target.replace(".", "_"))
            else:
                filename = "%s_all.svg" % ctx.label.name
            outputs.append(ctx.actions.declare_file(filename))

    # Build command arguments for each target
    for i, target in enumerate(targets):
        arguments = ["graph-states"]

        # Add target selection
        if target:
            arguments += ["--target", target]

        # Add options
        if ctx.attr.separate_edges:
            arguments.append("--separate-edges")

        # Add output
        arguments += ["--output", outputs[i].path]

        # Run command for this target
        run_coco(
            ctx = ctx,
            package = package,
            verb = "Generating state diagram for",
            mnemonic = "CocoDiagram",
            arguments = arguments,
            outputs = [outputs[i]],
        )

    return [DefaultInfo(files = depset(outputs))]

_coco_state_diagram = rule(
    implementation = _coco_state_diagram_impl,
    attrs = dict(LICENSE_ATTRIBUTES.items() + {
        "package": attr.label(
            providers = [CocoPackageInfo],
            mandatory = True,
            doc = "The coco_package target to generate state diagrams for",
        ),
        "separate_edges": attr.bool(
            default = False,
            doc = "Layout option for state transitions",
        ),
        "targets": attr.string_list(
            default = [],
            doc = "List of fully qualified names of state machines/components/ports to generate diagrams for. If empty, generates diagrams for all state machines.",
        ),
    }.items()),
    doc = """Generates state machine diagrams for Coco state machines.

This rule generates SVG diagrams showing state machine structure using `popili graph-states`.

Example:
    ```python
    coco_package(
        name = "my_pkg",
        package = "Coco.toml",
        srcs = glob(["src/**/*.coco"]),
    )

    coco_state_diagram(
        name = "my_state_machine",
        package = ":my_pkg",
        targets = ["MyComponent.myPort.stateMachine"],
    )
    ```

For multiple state machines:
    ```python
    coco_state_diagram(
        name = "all_states",
        package = ":my_pkg",
        targets = [
            "Component1.port1.states",
            "Component2.port2.states",
        ],
    )
    ```
""",
    toolchains = [COCO_TOOLCHAIN_TYPE],
)

def _coco_counterexample_diagram_impl(ctx):
    """Implementation for coco_counterexample_diagram rule.

    Generates counterexample diagrams using `popili verify --counterexample-svg`.
    """
    package = ctx.attr.package

    filenames = ctx.attr.counterexample_filenames
    targets = ctx.attr.counterexample_targets
    assertions = ctx.attr.counterexample_assertions

    if not filenames:
        fail("counterexamples must specify at least one expected counterexample")

    # Build base arguments
    arguments = [
        "verify",
        "--exit-code=fatal-only",
    ]
    if ctx.attr.draw_title:
        arguments.append("--counterexamples-draw-title")
    if ctx.attr.deterministic:
        arguments.append("--deterministic-counterexamples")
    backend = ctx.attr._verification_backend[BuildSettingInfo].value
    if backend != "":
        arguments += ["--backend", backend]

    # Process each counterexample specification
    outputs = []
    for i in range(len(filenames)):
        filename = filenames[i]
        target = targets[i]
        assertion = assertions[i] if i < len(assertions) else ""

        # Declare output file
        output = ctx.actions.declare_file(filename)
        outputs.append(output)

        # Add output file argument
        arguments += ["--counterexample-svg", output.path]

        # Add target filter (required when multiple outputs)
        if len(filenames) > 1 or target:
            arguments += ["--counterexample-target", target]

        # Add assertion filter if specified
        if assertion:
            arguments += ["--counterexample-assertion", assertion]

    # Run verification with counterexample generation
    run_coco(
        ctx = ctx,
        package = package,
        verb = "Generating counterexample diagrams for",
        mnemonic = "CocoDiagram",
        arguments = arguments,
        outputs = outputs,
    )

    return [DefaultInfo(files = depset(outputs))]

_coco_counterexample_diagram = rule(
    implementation = _coco_counterexample_diagram_impl,
    attrs = dict(LICENSE_ATTRIBUTES.items() + {
        "counterexample_assertions": attr.string_list(
            default = [],
            doc = "List of assertion filters (internal use - populated by macro)",
        ),
        "counterexample_filenames": attr.string_list(
            mandatory = True,
            doc = "List of output filenames (internal use - populated by macro)",
        ),
        "counterexample_targets": attr.string_list(
            mandatory = True,
            doc = "List of target declaration names (internal use - populated by macro)",
        ),
        "deterministic": attr.bool(
            default = True,
            doc = "Ensure reproducible output",
        ),
        "draw_title": attr.bool(
            default = True,
            doc = "Draw border and title on diagrams",
        ),
        "package": attr.label(
            providers = [CocoPackageInfo],
            mandatory = True,
            doc = "The coco_package target to generate counterexample diagrams for",
        ),
        "_verification_backend": attr.label(default = Label("//:verification_backend")),
    }.items()),
    doc = """Generates counterexample diagrams for Coco verification failures.

This rule runs `popili verify` and generates individual SVG files for each expected counterexample.
You must specify the expected counterexamples as a dict mapping filenames to target specifications.

Example (basic):
    ```python
    coco_package(
        name = "my_pkg",
        package = "Coco.toml",
        srcs = glob(["src/**/*.coco"]),
    )

    coco_counterexample_diagram(
        name = "my_counterexamples",
        package = ":my_pkg",
        counterexamples = {
            "alarm.svg": "Alarm",
            "bottom.svg": "Bottom",
        },
        deterministic = True,
    )
    ```

This generates:
- `alarm.svg` (counterexamples from Alarm component)
- `bottom.svg` (counterexamples from Bottom component)

Example (with assertion filtering):
    ```python
    load("@rules_coco//coco:defs.bzl", "coco_counterexample_diagram", "counterexample_options")

    coco_counterexample_diagram(
        name = "specific_failures",
        package = ":my_pkg",
        counterexamples = {
            "safety.svg": counterexample_options(
                decl = "SafetyChecker",
                assertion = "safetyProperty",
            ),
            "liveness.svg": counterexample_options(
                decl = "LivenessChecker",
                assertion = "livenessProperty",
            ),
        },
    )
    ```

Note: This rule succeeds even when verification fails (since that's when counterexamples are generated).
Use coco_verify_test for actual verification testing.
""",
    toolchains = [COCO_TOOLCHAIN_TYPE],
)

# Public macros with platform selection

def coco_architecture_diagram(name, components, **kwargs):
    """Creates an architecture diagram generation rule.

    Args:
        name: Name of the diagram target
        components: Dict mapping output filenames to component names (required)
        **kwargs: Additional arguments passed to the underlying rule
    """
    if not components:
        fail("components must specify at least one component to diagram")

    # Process the components dict into parallel lists
    filenames = []
    targets = []

    for filename, component in components.items():
        filenames.append(filename)
        targets.append(component)

    _coco_architecture_diagram(
        name = name,
        component_filenames = filenames,
        component_targets = targets,
        **kwargs
    )

def coco_state_diagram(name, **kwargs):
    """Creates a state machine diagram generation rule.

    Args:
        name: Name of the diagram target
        **kwargs: Additional arguments passed to the underlying rule
    """
    _coco_state_diagram(
        name = name,
        **kwargs
    )

def coco_counterexample_diagram(name, counterexamples, **kwargs):
    """Creates a counterexample diagram generation rule.

    Args:
        name: Name of the diagram target
        counterexamples: Dict mapping output filenames to target specifications.
            Values can be either:
            - A string with the target declaration name
            - A struct from counterexample_options(decl, assertion) for filtering
        **kwargs: Additional arguments passed to the underlying rule
    """
    if not counterexamples:
        fail("counterexamples must specify at least one expected counterexample")

    # Process the counterexamples dict into parallel lists
    filenames = []
    targets = []
    assertions = []

    for filename, spec in counterexamples.items():
        filenames.append(filename)

        # Check if spec is a string or a struct
        if type(spec) == "string":
            # Simple case: spec is just the target name
            targets.append(spec)
            assertions.append("")
        else:
            # Struct case: extract decl and assertion fields
            if not hasattr(spec, "decl"):
                fail("counterexample specification must be a string or a struct with 'decl' field")
            targets.append(spec.decl)
            assertions.append(spec.assertion if hasattr(spec, "assertion") and spec.assertion else "")

    _coco_counterexample_diagram(
        name = name,
        counterexample_filenames = filenames,
        counterexample_targets = targets,
        counterexample_assertions = assertions,
        **kwargs
    )
