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
        ),
        "component_names": attr.bool(
            default = False,
            doc = "Show the instance name of child components. Disabled by default.",
        ),
        "component_targets": attr.string_list(
            mandatory = True,
        ),
        "component_types": attr.bool(
            default = True,
            doc = "Show the type of each component. Enabled by default.",
        ),
        "depth": attr.string(
            default = "",
            doc = "Recursive drawing depth: an integer string, 'auto', 'max', or empty for the default.",
        ),
        "hide_ports": attr.bool(
            default = False,
            doc = "Hide ports in diagrams. Disabled by default.",
        ),
        "only_encapsulating": attr.bool(
            default = True,
            doc = "Don't draw implementation/external components. Enabled by default.",
        ),
        "only_roots": attr.bool(
            default = False,
            doc = "Only draw root components. Disabled by default.",
        ),
        "package": attr.label(
            providers = [CocoPackageInfo],
            mandatory = True,
            doc = "The coco_package target to generate architecture diagrams for.",
        ),
        "port_names": attr.bool(
            default = False,
            doc = "Show the instance name of each port. Disabled by default.",
        ),
        "port_types": attr.bool(
            default = True,
            doc = "Show the type of each port. Enabled by default.",
        ),
    }.items()),
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
            doc = "The coco_package target to generate state diagrams for.",
        ),
        "separate_edges": attr.bool(
            default = False,
            doc = "Lay out each state transition as a separate edge. Disabled by default.",
        ),
        "targets": attr.string_list(
            default = [],
            doc = "Fully qualified names of state machines/components/ports to diagram " +
                  "(e.g. \"MyComponent.myPort.stateMachine\"). If empty, all state machines are drawn.",
        ),
    }.items()),
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
        ),
        "counterexample_filenames": attr.string_list(
            mandatory = True,
        ),
        "counterexample_targets": attr.string_list(
            mandatory = True,
        ),
        "deterministic": attr.bool(
            default = True,
        ),
        "draw_title": attr.bool(
            default = True,
        ),
        "package": attr.label(
            providers = [CocoPackageInfo],
            mandatory = True,
        ),
        "_verification_backend": attr.label(default = Label("//:verification_backend")),
    }.items()),
    toolchains = [COCO_TOOLCHAIN_TYPE],
)

# Public macros

def _coco_architecture_diagram_macro_impl(name, visibility, components, **kwargs):
    if not components:
        fail("components must specify at least one component to diagram")

    # components is {filename: component}; keys()/values() stay aligned by insertion order.
    _coco_architecture_diagram(
        name = name,
        component_filenames = components.keys(),
        component_targets = components.values(),
        visibility = visibility,
        **kwargs
    )

coco_architecture_diagram = macro(
    doc = """Creates architecture diagrams.

Generates SVG diagrams showing component architecture using
`popili graph-component`.""",
    inherit_attrs = _coco_architecture_diagram,
    attrs = {
        # Hidden from callers: supplied by the impl from `components`.
        "component_filenames": None,
        "component_targets": None,
        "components": attr.string_dict(
            mandatory = True,
            configurable = False,
            doc = "Maps each output SVG filename to the component to draw " +
                  "(e.g. {\"my_component.svg\": \"MyComponent\"}).",
        ),
    },
    implementation = _coco_architecture_diagram_macro_impl,
)

def _coco_state_diagram_macro_impl(name, visibility, **kwargs):
    _coco_state_diagram(
        name = name,
        visibility = visibility,
        **kwargs
    )

coco_state_diagram = macro(
    doc = """Creates state machine diagrams.

Generates SVG diagrams showing state machine structure using
`popili graph-states`.""",
    inherit_attrs = _coco_state_diagram,
    implementation = _coco_state_diagram_macro_impl,
)

def coco_counterexample_diagram(
        name,
        package,
        counterexamples,
        draw_title = True,
        deterministic = True,
        **kwargs):
    """Creates counterexample diagrams.

    Generates SVG diagrams for verification counterexamples using `popili verify`.
    This rule succeeds even when verification fails (since that's when counterexamples
    are generated). Use coco_verify_test for actual verification testing.

    Args:
        name: Name of the diagram target
        package: The coco_package target to generate counterexample diagrams for
        counterexamples: Dict mapping output filenames to target specifications. Values can be either a string with the
          target declaration name, or a struct from counterexample_options(decl, assertion) for filtering
          (e.g., {"alarm.svg": "Alarm"} or {"safety.svg": counterexample_options(decl="Checker", assertion="prop")})
        draw_title: Draw border and title on diagrams (default: True)
        deterministic: Ensure reproducible output (default: True)
        **kwargs: Additional Bazel arguments (e.g., visibility, tags)
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
        package = package,
        counterexample_filenames = filenames,
        counterexample_targets = targets,
        counterexample_assertions = assertions,
        draw_title = draw_title,
        deterministic = deterministic,
        **kwargs
    )
