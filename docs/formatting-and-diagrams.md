# Formatting and diagrams

## Formatting

Format checking can be integrated into your test suite using [`coco_fmt_test`](reference/defs.md#coco_fmt_test):

```starlark
load("@rules_coco//coco:defs.bzl", "coco_fmt_test")

coco_fmt_test(
    name = "my_package_fmt_test",
    package = ":my_package",
)
```

This creates two targets:

- `my_package_fmt_test`: Test that fails if code isn't formatted, with
  [`popili format`](https://cocotec.io/popili/doc/stable/tools/cli.html#format-subcommand) and the
  [`[format]`](https://cocotec.io/popili/doc/stable/language/structure.html#format) settings of `Coco.toml`
  (`bazel test`)
- `my_package_fmt_test.format`: Binary to format code in-place (`bazel run`)

## Diagram generation

`rules_coco` provides rules for generating diagrams from Coco code. Each diagram rule writes SVG files. Build the
target, for example `bazel build //path/to:my_component_arch`, and find them in `bazel-bin/path/to/`. Architecture and
counterexample diagrams are named after the keys of `components` and `counterexamples` (here `my_component.svg`);
state diagrams are named as described below.

### Architecture diagrams

Generate component architecture diagrams showing the structure and connections of your components, with
[`popili graph-component`](https://cocotec.io/popili/doc/stable/tools/cli.html#graph-component-subcommand):

```starlark
load("@rules_coco//coco:defs.bzl", "coco_architecture_diagram")

# Generate diagram for a single component
coco_architecture_diagram(
    name = "my_component_arch",
    package = ":my_package",
    components = {
        "my_component.svg": "MyComponent",
    },
    port_names = True,
    port_types = True,
)

# Generate diagrams for multiple components
coco_architecture_diagram(
    name = "all_components_arch",
    package = ":my_package",
    components = {
        "component1.svg": "Component1",
        "component2.svg": "Component2",
        "component3.svg": "Component3",
    },
)
```

Other options: [`depth`](reference/defs.md#coco_architecture_diagram-depth) (how many levels to draw: an integer such as
`"2"`, `"auto"` or `"max"`), [`hide_ports`](reference/defs.md#coco_architecture_diagram-hide_ports),
[`only_roots`](reference/defs.md#coco_architecture_diagram-only_roots),
[`only_encapsulating`](reference/defs.md#coco_architecture_diagram-only_encapsulating) (on by default: implementation
and external components are left out), [`component_names`](reference/defs.md#coco_architecture_diagram-component_names),
and [`component_types`](reference/defs.md#coco_architecture_diagram-component_types) (on by default). The
[reference](reference/defs.md#coco_architecture_diagram) lists every attribute with its default.

### State machine diagrams

Generate state machine diagrams with
[`popili graph-states`](https://cocotec.io/popili/doc/stable/tools/cli.html#graph-states-subcommand):

```starlark
load("@rules_coco//coco:defs.bzl", "coco_state_diagram")

coco_state_diagram(
    name = "my_state_machine",
    package = ":my_package",
    targets = ["MyComponent.MyMachine"],
    separate_edges = False,
)
```

The diagram is written to `<name>.svg`. Without [`targets`](reference/defs.md#coco_state_diagram-targets), that one file
shows every state machine. With several `targets`, each gets its own file, `<name>_<target>.svg`, with the dots in the
target replaced by underscores (`my_state_machine_MyComponent_MyMachine.svg`).

### Counterexample diagrams

Generate sequence diagrams for
[verification](https://cocotec.io/popili/doc/stable/language/verification.html#verification) failures. You must specify
the expected counterexamples as a dict mapping output file names to the declaration whose counterexample to draw, such
as a component name:

```starlark
load("@rules_coco//coco:defs.bzl", "coco_counterexample_diagram")

coco_counterexample_diagram(
    name = "my_counterexamples",
    package = ":my_package",
    counterexamples = {
        "alarm_failure.svg": "Alarm",
        "safety_violation.svg": "SafetyChecker",
    },
    deterministic = True,
)
```

[`draw_title`](reference/defs.md#coco_counterexample_diagram-draw_title) (default `True`) draws a border and title on
each diagram. [`deterministic`](reference/defs.md#coco_counterexample_diagram-deterministic) (default `True`) makes
Popili produce the same counterexample on every run, so the output is reproducible.

For filtering by specific assertions, use the [`counterexample_options()`](reference/defs.md#counterexample_options)
helper. [`assertion`](reference/defs.md#counterexample_options-assertion) is the name of a check as Popili reports it in
the verification results, such as `"Well-formedness"`. rules_coco passes it to
`popili verify --counterexample-assertion`.

```starlark
load("@rules_coco//coco:defs.bzl", "coco_counterexample_diagram", "counterexample_options")

coco_counterexample_diagram(
    name = "specific_counterexamples",
    package = ":my_package",
    counterexamples = {
        "safety.svg": counterexample_options(
            decl = "SafetyChecker",
            assertion = "Well-formedness",
        ),
        "liveness.svg": counterexample_options(
            decl = "LivenessChecker",
            assertion = "Implements Provided Port",
        ),
    },
)
```
