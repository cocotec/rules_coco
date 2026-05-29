<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API for Coco package rules and code generation.

<a id="with_popili_version"></a>

## with_popili_version

<pre>
load("@rules_coco//coco:defs.bzl", "with_popili_version")

with_popili_version(<a href="#with_popili_version-name">name</a>, <a href="#with_popili_version-target">target</a>, <a href="#with_popili_version-version">version</a>)
</pre>

Wrapper rule to build a target with a specific popili version.

Use this when you need to build different targets with different popili versions
in the same build. For most cases, just use --@rules_coco//:version=X.Y.Z.

Example:
    coco_package(name = "pkg", ...)

    with_popili_version(
        name = "pkg_v147",
        target = ":pkg",
        version = "1.4.7",
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="with_popili_version-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="with_popili_version-target"></a>target |  The target to build with a specific popili version   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="with_popili_version-version"></a>version |  The popili version to use (e.g., '1.5.0', '1.4.7')   | String | required |  |


<a id="CocoWorkspaceInfo"></a>

## CocoWorkspaceInfo

<pre>
load("@rules_coco//coco:defs.bzl", "CocoWorkspaceInfo")

CocoWorkspaceInfo(<a href="#CocoWorkspaceInfo-files">files</a>)
</pre>

Information about a Coco workspace root whose shared settings flow down to member packages

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="CocoWorkspaceInfo-files"></a>files |  Coco.toml files a member must ship: this workspace's root manifest plus any parent workspaces    |


<a id="coco_counterexample_diagram"></a>

## coco_counterexample_diagram

<pre>
load("@rules_coco//coco:defs.bzl", "coco_counterexample_diagram")

coco_counterexample_diagram(<a href="#coco_counterexample_diagram-name">name</a>, <a href="#coco_counterexample_diagram-package">package</a>, <a href="#coco_counterexample_diagram-counterexamples">counterexamples</a>, <a href="#coco_counterexample_diagram-draw_title">draw_title</a>, <a href="#coco_counterexample_diagram-deterministic">deterministic</a>, <a href="#coco_counterexample_diagram-kwargs">**kwargs</a>)
</pre>

Creates counterexample diagrams.

Generates SVG diagrams for verification counterexamples using `popili verify`.
This rule succeeds even when verification fails (since that's when counterexamples
are generated). Use coco_verify_test for actual verification testing.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_counterexample_diagram-name"></a>name |  Name of the diagram target   |  none |
| <a id="coco_counterexample_diagram-package"></a>package |  The coco_package target to generate counterexample diagrams for   |  none |
| <a id="coco_counterexample_diagram-counterexamples"></a>counterexamples |  Dict mapping output filenames to target specifications. Values can be either a string with the target declaration name, or a struct from counterexample_options(decl, assertion) for filtering (e.g., {"alarm.svg": "Alarm"} or {"safety.svg": counterexample_options(decl="Checker", assertion="prop")})   |  none |
| <a id="coco_counterexample_diagram-draw_title"></a>draw_title |  Draw border and title on diagrams (default: True)   |  `True` |
| <a id="coco_counterexample_diagram-deterministic"></a>deterministic |  Ensure reproducible output (default: True)   |  `True` |
| <a id="coco_counterexample_diagram-kwargs"></a>kwargs |  Additional Bazel arguments (e.g., visibility, tags)   |  none |


<a id="coco_test_outputs_name"></a>

## coco_test_outputs_name

<pre>
load("@rules_coco//coco:defs.bzl", "coco_test_outputs_name")

coco_test_outputs_name(<a href="#coco_test_outputs_name-name">name</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_test_outputs_name-name"></a>name |  <p align="center"> - </p>   |  none |


<a id="counterexample_options"></a>

## counterexample_options

<pre>
load("@rules_coco//coco:defs.bzl", "counterexample_options")

counterexample_options(<a href="#counterexample_options-decl">decl</a>, <a href="#counterexample_options-assertion">assertion</a>)
</pre>

Specify counterexample filtering options.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="counterexample_options-decl"></a>decl |  Target declaration name (required)   |  none |
| <a id="counterexample_options-assertion"></a>assertion |  Assertion text to filter (optional, only needed if multiple counterexamples for the target)   |  `None` |

**RETURNS**

Struct with decl and assertion fields for use in coco_counterexample_diagram


<a id="coco_architecture_diagram"></a>

## coco_architecture_diagram

<pre>
load("@rules_coco//coco:defs.bzl", "coco_architecture_diagram")

coco_architecture_diagram(*, <a href="#coco_architecture_diagram-name">name</a>, <a href="#coco_architecture_diagram-compatible_with">compatible_with</a>, <a href="#coco_architecture_diagram-component_names">component_names</a>, <a href="#coco_architecture_diagram-component_types">component_types</a>, <a href="#coco_architecture_diagram-components">components</a>,
                          <a href="#coco_architecture_diagram-deprecation">deprecation</a>, <a href="#coco_architecture_diagram-depth">depth</a>, <a href="#coco_architecture_diagram-exec_compatible_with">exec_compatible_with</a>, <a href="#coco_architecture_diagram-exec_properties">exec_properties</a>, <a href="#coco_architecture_diagram-features">features</a>,
                          <a href="#coco_architecture_diagram-hide_ports">hide_ports</a>, <a href="#coco_architecture_diagram-only_encapsulating">only_encapsulating</a>, <a href="#coco_architecture_diagram-only_roots">only_roots</a>, <a href="#coco_architecture_diagram-package">package</a>, <a href="#coco_architecture_diagram-package_metadata">package_metadata</a>,
                          <a href="#coco_architecture_diagram-port_names">port_names</a>, <a href="#coco_architecture_diagram-port_types">port_types</a>, <a href="#coco_architecture_diagram-restricted_to">restricted_to</a>, <a href="#coco_architecture_diagram-tags">tags</a>, <a href="#coco_architecture_diagram-target_compatible_with">target_compatible_with</a>,
                          <a href="#coco_architecture_diagram-testonly">testonly</a>, <a href="#coco_architecture_diagram-toolchains">toolchains</a>, <a href="#coco_architecture_diagram-visibility">visibility</a>)
</pre>

Creates architecture diagrams.

Generates SVG diagrams showing component architecture using
`popili graph-component`.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="coco_architecture_diagram-name"></a>name |  A unique name for this macro instance. Normally, this is also the name for the macro's main or only target. The names of any other targets that this macro might create will be this name with a string suffix.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="coco_architecture_diagram-compatible_with"></a>compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_architecture_diagram-component_names"></a>component_names |  Show the instance name of child components. Disabled by default.   | Boolean | optional |  `None`  |
| <a id="coco_architecture_diagram-component_types"></a>component_types |  Show the type of each component. Enabled by default.   | Boolean | optional |  `None`  |
| <a id="coco_architecture_diagram-components"></a>components |  Maps each output SVG filename to the component to draw (e.g. {"my_component.svg": "MyComponent"}).   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | required |  |
| <a id="coco_architecture_diagram-deprecation"></a>deprecation |  <a href="https://bazel.build/reference/be/common-definitions#common.deprecation">Inherited rule attribute</a>   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_architecture_diagram-depth"></a>depth |  Recursive drawing depth: an integer string, 'auto', 'max', or empty for the default.   | String | optional |  `None`  |
| <a id="coco_architecture_diagram-exec_compatible_with"></a>exec_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_architecture_diagram-exec_properties"></a>exec_properties |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_properties">Inherited rule attribute</a>   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `None`  |
| <a id="coco_architecture_diagram-features"></a>features |  <a href="https://bazel.build/reference/be/common-definitions#common.features">Inherited rule attribute</a>   | List of strings | optional |  `None`  |
| <a id="coco_architecture_diagram-hide_ports"></a>hide_ports |  Hide ports in diagrams. Disabled by default.   | Boolean | optional |  `None`  |
| <a id="coco_architecture_diagram-only_encapsulating"></a>only_encapsulating |  Don't draw implementation/external components. Enabled by default.   | Boolean | optional |  `None`  |
| <a id="coco_architecture_diagram-only_roots"></a>only_roots |  Only draw root components. Disabled by default.   | Boolean | optional |  `None`  |
| <a id="coco_architecture_diagram-package"></a>package |  The coco_package target to generate architecture diagrams for.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="coco_architecture_diagram-package_metadata"></a>package_metadata |  <a href="https://bazel.build/reference/be/common-definitions#common.package_metadata">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_architecture_diagram-port_names"></a>port_names |  Show the instance name of each port. Disabled by default.   | Boolean | optional |  `None`  |
| <a id="coco_architecture_diagram-port_types"></a>port_types |  Show the type of each port. Enabled by default.   | Boolean | optional |  `None`  |
| <a id="coco_architecture_diagram-restricted_to"></a>restricted_to |  <a href="https://bazel.build/reference/be/common-definitions#common.restricted_to">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_architecture_diagram-tags"></a>tags |  <a href="https://bazel.build/reference/be/common-definitions#common.tags">Inherited rule attribute</a>   | List of strings; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_architecture_diagram-target_compatible_with"></a>target_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.target_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_architecture_diagram-testonly"></a>testonly |  <a href="https://bazel.build/reference/be/common-definitions#common.testonly">Inherited rule attribute</a>   | Boolean; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_architecture_diagram-toolchains"></a>toolchains |  <a href="https://bazel.build/reference/be/common-definitions#common.toolchains">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_architecture_diagram-visibility"></a>visibility |  The visibility to be passed to this macro's exported targets. It always implicitly includes the location where this macro is instantiated, so this attribute only needs to be explicitly set if you want the macro's targets to be additionally visible somewhere else.   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  |


<a id="coco_fmt_test"></a>

## coco_fmt_test

<pre>
load("@rules_coco//coco:defs.bzl", "coco_fmt_test")

coco_fmt_test(*, <a href="#coco_fmt_test-name">name</a>, <a href="#coco_fmt_test-args">args</a>, <a href="#coco_fmt_test-compatible_with">compatible_with</a>, <a href="#coco_fmt_test-deprecation">deprecation</a>, <a href="#coco_fmt_test-exec_compatible_with">exec_compatible_with</a>, <a href="#coco_fmt_test-exec_properties">exec_properties</a>,
              <a href="#coco_fmt_test-features">features</a>, <a href="#coco_fmt_test-flaky">flaky</a>, <a href="#coco_fmt_test-local">local</a>, <a href="#coco_fmt_test-package">package</a>, <a href="#coco_fmt_test-package_metadata">package_metadata</a>, <a href="#coco_fmt_test-restricted_to">restricted_to</a>, <a href="#coco_fmt_test-shard_count">shard_count</a>, <a href="#coco_fmt_test-size">size</a>,
              <a href="#coco_fmt_test-tags">tags</a>, <a href="#coco_fmt_test-target_compatible_with">target_compatible_with</a>, <a href="#coco_fmt_test-testonly">testonly</a>, <a href="#coco_fmt_test-timeout">timeout</a>, <a href="#coco_fmt_test-toolchains">toolchains</a>, <a href="#coco_fmt_test-visibility">visibility</a>)
</pre>

Create a Coco format-check test plus a companion formatter binary.

Two targets are created:

- `<name>`: a test (run via `bazel test`) that fails if the package's Coco
  sources are not correctly formatted (runs `popili format --verify`).
- `<name>.format`: a binary (run via `bazel run`) that formats the sources in
  place (runs `popili format`).

To skip the test for specific packages, use standard Bazel tags, e.g.
`tags = ["manual"]`.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="coco_fmt_test-name"></a>name |  A unique name for this macro instance. Normally, this is also the name for the macro's main or only target. The names of any other targets that this macro might create will be this name with a string suffix.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="coco_fmt_test-args"></a>args |  <a href="https://bazel.build/reference/be/common-definitions#test.args">Inherited rule attribute</a>   | List of strings | optional |  `None`  |
| <a id="coco_fmt_test-compatible_with"></a>compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_fmt_test-deprecation"></a>deprecation |  <a href="https://bazel.build/reference/be/common-definitions#common.deprecation">Inherited rule attribute</a>   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_fmt_test-exec_compatible_with"></a>exec_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_fmt_test-exec_properties"></a>exec_properties |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_properties">Inherited rule attribute</a>   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `None`  |
| <a id="coco_fmt_test-features"></a>features |  <a href="https://bazel.build/reference/be/common-definitions#common.features">Inherited rule attribute</a>   | List of strings | optional |  `None`  |
| <a id="coco_fmt_test-flaky"></a>flaky |  <a href="https://bazel.build/reference/be/common-definitions#test.flaky">Inherited rule attribute</a>   | Boolean; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_fmt_test-local"></a>local |  <a href="https://bazel.build/reference/be/common-definitions#test.local">Inherited rule attribute</a>   | Boolean; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_fmt_test-package"></a>package |  The coco_package target to check/format.   | <a href="https://bazel.build/concepts/labels">Label</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | required |  |
| <a id="coco_fmt_test-package_metadata"></a>package_metadata |  <a href="https://bazel.build/reference/be/common-definitions#common.package_metadata">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_fmt_test-restricted_to"></a>restricted_to |  <a href="https://bazel.build/reference/be/common-definitions#common.restricted_to">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_fmt_test-shard_count"></a>shard_count |  <a href="https://bazel.build/reference/be/common-definitions#test.shard_count">Inherited rule attribute</a>   | Integer | optional |  `None`  |
| <a id="coco_fmt_test-size"></a>size |  <a href="https://bazel.build/reference/be/common-definitions#test.size">Inherited rule attribute</a>   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_fmt_test-tags"></a>tags |  <a href="https://bazel.build/reference/be/common-definitions#common.tags">Inherited rule attribute</a>   | List of strings; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_fmt_test-target_compatible_with"></a>target_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.target_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_fmt_test-testonly"></a>testonly |  <a href="https://bazel.build/reference/be/common-definitions#common.testonly">Inherited rule attribute</a>   | Boolean; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_fmt_test-timeout"></a>timeout |  <a href="https://bazel.build/reference/be/common-definitions#test.timeout">Inherited rule attribute</a>   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_fmt_test-toolchains"></a>toolchains |  <a href="https://bazel.build/reference/be/common-definitions#common.toolchains">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_fmt_test-visibility"></a>visibility |  The visibility to be passed to this macro's exported targets. It always implicitly includes the location where this macro is instantiated, so this attribute only needs to be explicitly set if you want the macro's targets to be additionally visible somewhere else.   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  |


<a id="coco_generate"></a>

## coco_generate

<pre>
load("@rules_coco//coco:defs.bzl", "coco_generate")

coco_generate(*, <a href="#coco_generate-name">name</a>, <a href="#coco_generate-c_file_name_mangler">c_file_name_mangler</a>, <a href="#coco_generate-c_flat_file_hierarchy">c_flat_file_hierarchy</a>, <a href="#coco_generate-c_header_file_extension">c_header_file_extension</a>,
              <a href="#coco_generate-c_header_file_prefix">c_header_file_prefix</a>, <a href="#coco_generate-c_implementation_file_extension">c_implementation_file_extension</a>, <a href="#coco_generate-c_implementation_file_prefix">c_implementation_file_prefix</a>,
              <a href="#coco_generate-c_regenerate_packages">c_regenerate_packages</a>, <a href="#coco_generate-compatible_with">compatible_with</a>, <a href="#coco_generate-cpp_file_name_mangler">cpp_file_name_mangler</a>, <a href="#coco_generate-cpp_flat_file_hierarchy">cpp_flat_file_hierarchy</a>,
              <a href="#coco_generate-cpp_header_file_extension">cpp_header_file_extension</a>, <a href="#coco_generate-cpp_header_file_prefix">cpp_header_file_prefix</a>, <a href="#coco_generate-cpp_implementation_file_extension">cpp_implementation_file_extension</a>,
              <a href="#coco_generate-cpp_implementation_file_prefix">cpp_implementation_file_prefix</a>, <a href="#coco_generate-cpp_regenerate_packages">cpp_regenerate_packages</a>, <a href="#coco_generate-csharp_regenerate_packages">csharp_regenerate_packages</a>,
              <a href="#coco_generate-deprecation">deprecation</a>, <a href="#coco_generate-exec_compatible_with">exec_compatible_with</a>, <a href="#coco_generate-exec_properties">exec_properties</a>, <a href="#coco_generate-features">features</a>, <a href="#coco_generate-language">language</a>, <a href="#coco_generate-mocks">mocks</a>, <a href="#coco_generate-package">package</a>,
              <a href="#coco_generate-package_metadata">package_metadata</a>, <a href="#coco_generate-restricted_to">restricted_to</a>, <a href="#coco_generate-tags">tags</a>, <a href="#coco_generate-target_compatible_with">target_compatible_with</a>, <a href="#coco_generate-testonly">testonly</a>, <a href="#coco_generate-toolchains">toolchains</a>,
              <a href="#coco_generate-visibility">visibility</a>)
</pre>

Generate C, C++, or C# code from a Coco package.

The generated files can then be compiled into libraries or executables using
standard build rules (e.g., cc_library for C/C++).

The generator configuration options (file extensions, prefixes, etc.) must
match the settings in your Coco.toml file under the corresponding generator
section (e.g., [generator.cpp] for C++, [generator.c] for C).

Alongside the main code-generation target, a companion `<name>.tst` target is
created that exposes the generated test sources and headers.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="coco_generate-name"></a>name |  A unique name for this macro instance. Normally, this is also the name for the macro's main or only target. The names of any other targets that this macro might create will be this name with a string suffix.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="coco_generate-c_file_name_mangler"></a>c_file_name_mangler |  C file naming style. Must match Coco.toml generator.c.fileNameMangler. Options: "Unaltered" (default), "LowerCamelCase", "UpperCamelCase", "LowerUnderscore", "UpperUnderscore", "CapsUpperUnderscore".   | String | optional |  `None`  |
| <a id="coco_generate-c_flat_file_hierarchy"></a>c_flat_file_hierarchy |  Use a flat directory structure for C files. Must match Coco.toml generator.c.flatFileHierarchy. Disabled by default.   | Boolean | optional |  `None`  |
| <a id="coco_generate-c_header_file_extension"></a>c_header_file_extension |  File extension for C headers. Defaults to ".h".   | String | optional |  `None`  |
| <a id="coco_generate-c_header_file_prefix"></a>c_header_file_prefix |  Prefix for C header file names. Empty by default.   | String | optional |  `None`  |
| <a id="coco_generate-c_implementation_file_extension"></a>c_implementation_file_extension |  File extension for C implementation files. Defaults to ".c".   | String | optional |  `None`  |
| <a id="coco_generate-c_implementation_file_prefix"></a>c_implementation_file_prefix |  Prefix for C implementation file names. Empty by default.   | String | optional |  `None`  |
| <a id="coco_generate-c_regenerate_packages"></a>c_regenerate_packages |  Other coco_package targets to regenerate with this target's C generator settings.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_generate-compatible_with"></a>compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_generate-cpp_file_name_mangler"></a>cpp_file_name_mangler |  C++ file naming style. Must match Coco.toml generator.cpp.fileNameMangler. Options: "Unaltered" (default), "LowerCamelCase", "UpperCamelCase", "LowerUnderscore", "UpperUnderscore", "CapsUpperUnderscore".   | String | optional |  `None`  |
| <a id="coco_generate-cpp_flat_file_hierarchy"></a>cpp_flat_file_hierarchy |  Use a flat directory structure for C++ files. Must match Coco.toml generator.cpp.flatFileHierarchy. Disabled by default.   | Boolean | optional |  `None`  |
| <a id="coco_generate-cpp_header_file_extension"></a>cpp_header_file_extension |  File extension for C++ headers. Defaults to ".h".   | String | optional |  `None`  |
| <a id="coco_generate-cpp_header_file_prefix"></a>cpp_header_file_prefix |  Prefix for C++ header file names. Empty by default.   | String | optional |  `None`  |
| <a id="coco_generate-cpp_implementation_file_extension"></a>cpp_implementation_file_extension |  File extension for C++ implementation files. Defaults to ".cc".   | String | optional |  `None`  |
| <a id="coco_generate-cpp_implementation_file_prefix"></a>cpp_implementation_file_prefix |  Prefix for C++ implementation file names. Empty by default.   | String | optional |  `None`  |
| <a id="coco_generate-cpp_regenerate_packages"></a>cpp_regenerate_packages |  Other coco_package targets to regenerate with this target's C++ generator settings.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_generate-csharp_regenerate_packages"></a>csharp_regenerate_packages |  Other coco_package targets to regenerate with this target's C# generator settings.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_generate-deprecation"></a>deprecation |  <a href="https://bazel.build/reference/be/common-definitions#common.deprecation">Inherited rule attribute</a>   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_generate-exec_compatible_with"></a>exec_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_generate-exec_properties"></a>exec_properties |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_properties">Inherited rule attribute</a>   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `None`  |
| <a id="coco_generate-features"></a>features |  <a href="https://bazel.build/reference/be/common-definitions#common.features">Inherited rule attribute</a>   | List of strings | optional |  `None`  |
| <a id="coco_generate-language"></a>language |  Target language for code generation: "cpp", "c", or "csharp".   | String | required |  |
| <a id="coco_generate-mocks"></a>mocks |  Generate mock implementations for testing. Disabled by default.   | Boolean | optional |  `None`  |
| <a id="coco_generate-package"></a>package |  The coco_package target containing the source files to generate from.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="coco_generate-package_metadata"></a>package_metadata |  <a href="https://bazel.build/reference/be/common-definitions#common.package_metadata">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_generate-restricted_to"></a>restricted_to |  <a href="https://bazel.build/reference/be/common-definitions#common.restricted_to">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_generate-tags"></a>tags |  <a href="https://bazel.build/reference/be/common-definitions#common.tags">Inherited rule attribute</a>   | List of strings; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_generate-target_compatible_with"></a>target_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.target_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_generate-testonly"></a>testonly |  <a href="https://bazel.build/reference/be/common-definitions#common.testonly">Inherited rule attribute</a>   | Boolean; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_generate-toolchains"></a>toolchains |  <a href="https://bazel.build/reference/be/common-definitions#common.toolchains">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_generate-visibility"></a>visibility |  The visibility to be passed to this macro's exported targets. It always implicitly includes the location where this macro is instantiated, so this attribute only needs to be explicitly set if you want the macro's targets to be additionally visible somewhere else.   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  |


<a id="coco_package"></a>

## coco_package

<pre>
load("@rules_coco//coco:defs.bzl", "coco_package")

coco_package(*, <a href="#coco_package-name">name</a>, <a href="#coco_package-deps">deps</a>, <a href="#coco_package-srcs">srcs</a>, <a href="#coco_package-compatible_with">compatible_with</a>, <a href="#coco_package-deprecation">deprecation</a>, <a href="#coco_package-exec_compatible_with">exec_compatible_with</a>,
             <a href="#coco_package-exec_properties">exec_properties</a>, <a href="#coco_package-features">features</a>, <a href="#coco_package-package">package</a>, <a href="#coco_package-package_metadata">package_metadata</a>, <a href="#coco_package-restricted_to">restricted_to</a>, <a href="#coco_package-tags">tags</a>,
             <a href="#coco_package-target_compatible_with">target_compatible_with</a>, <a href="#coco_package-test_srcs">test_srcs</a>, <a href="#coco_package-testonly">testonly</a>, <a href="#coco_package-toolchains">toolchains</a>, <a href="#coco_package-typecheck">typecheck</a>, <a href="#coco_package-visibility">visibility</a>,
             <a href="#coco_package-workspace">workspace</a>)
</pre>

Define a Coco package from a Coco.toml and its .coco source files.

A coco_package is the unit the other Coco rules operate on: pass it to
coco_generate to produce code, to coco_verify_test to verify it, or to
coco_fmt_test to check formatting. Packages may depend on other packages via
`deps`, and may inherit shared settings from a coco_workspace via `workspace`.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="coco_package-name"></a>name |  A unique name for this macro instance. Normally, this is also the name for the macro's main or only target. The names of any other targets that this macro might create will be this name with a string suffix.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="coco_package-deps"></a>deps |  Other coco_package targets this package depends on.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_package-srcs"></a>srcs |  The .coco source files for this package.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="coco_package-compatible_with"></a>compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_package-deprecation"></a>deprecation |  <a href="https://bazel.build/reference/be/common-definitions#common.deprecation">Inherited rule attribute</a>   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_package-exec_compatible_with"></a>exec_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_package-exec_properties"></a>exec_properties |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_properties">Inherited rule attribute</a>   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `None`  |
| <a id="coco_package-features"></a>features |  <a href="https://bazel.build/reference/be/common-definitions#common.features">Inherited rule attribute</a>   | List of strings | optional |  `None`  |
| <a id="coco_package-package"></a>package |  Label pointing to the Coco.toml file for this package.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="coco_package-package_metadata"></a>package_metadata |  <a href="https://bazel.build/reference/be/common-definitions#common.package_metadata">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_package-restricted_to"></a>restricted_to |  <a href="https://bazel.build/reference/be/common-definitions#common.restricted_to">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_package-tags"></a>tags |  <a href="https://bazel.build/reference/be/common-definitions#common.tags">Inherited rule attribute</a>   | List of strings; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_package-target_compatible_with"></a>target_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.target_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_package-test_srcs"></a>test_srcs |  The .coco test source files for this package.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_package-testonly"></a>testonly |  <a href="https://bazel.build/reference/be/common-definitions#common.testonly">Inherited rule attribute</a>   | Boolean; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_package-toolchains"></a>toolchains |  <a href="https://bazel.build/reference/be/common-definitions#common.toolchains">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_package-typecheck"></a>typecheck |  Run typecheck validation during package creation. When enabled, the build fails if typecheck errors are found. Disabled by default.   | Boolean | optional |  `None`  |
| <a id="coco_package-visibility"></a>visibility |  The visibility to be passed to this macro's exported targets. It always implicitly includes the location where this macro is instantiated, so this attribute only needs to be explicitly set if you want the macro's targets to be additionally visible somewhere else.   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  |
| <a id="coco_package-workspace"></a>workspace |  Optional coco_workspace whose Coco.toml settings this package inherits.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |


<a id="coco_state_diagram"></a>

## coco_state_diagram

<pre>
load("@rules_coco//coco:defs.bzl", "coco_state_diagram")

coco_state_diagram(*, <a href="#coco_state_diagram-name">name</a>, <a href="#coco_state_diagram-compatible_with">compatible_with</a>, <a href="#coco_state_diagram-deprecation">deprecation</a>, <a href="#coco_state_diagram-exec_compatible_with">exec_compatible_with</a>, <a href="#coco_state_diagram-exec_properties">exec_properties</a>,
                   <a href="#coco_state_diagram-features">features</a>, <a href="#coco_state_diagram-package">package</a>, <a href="#coco_state_diagram-package_metadata">package_metadata</a>, <a href="#coco_state_diagram-restricted_to">restricted_to</a>, <a href="#coco_state_diagram-separate_edges">separate_edges</a>, <a href="#coco_state_diagram-tags">tags</a>,
                   <a href="#coco_state_diagram-target_compatible_with">target_compatible_with</a>, <a href="#coco_state_diagram-targets">targets</a>, <a href="#coco_state_diagram-testonly">testonly</a>, <a href="#coco_state_diagram-toolchains">toolchains</a>, <a href="#coco_state_diagram-visibility">visibility</a>)
</pre>

Creates state machine diagrams.

Generates SVG diagrams showing state machine structure using
`popili graph-states`.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="coco_state_diagram-name"></a>name |  A unique name for this macro instance. Normally, this is also the name for the macro's main or only target. The names of any other targets that this macro might create will be this name with a string suffix.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="coco_state_diagram-compatible_with"></a>compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_state_diagram-deprecation"></a>deprecation |  <a href="https://bazel.build/reference/be/common-definitions#common.deprecation">Inherited rule attribute</a>   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_state_diagram-exec_compatible_with"></a>exec_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_state_diagram-exec_properties"></a>exec_properties |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_properties">Inherited rule attribute</a>   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `None`  |
| <a id="coco_state_diagram-features"></a>features |  <a href="https://bazel.build/reference/be/common-definitions#common.features">Inherited rule attribute</a>   | List of strings | optional |  `None`  |
| <a id="coco_state_diagram-package"></a>package |  The coco_package target to generate state diagrams for.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="coco_state_diagram-package_metadata"></a>package_metadata |  <a href="https://bazel.build/reference/be/common-definitions#common.package_metadata">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_state_diagram-restricted_to"></a>restricted_to |  <a href="https://bazel.build/reference/be/common-definitions#common.restricted_to">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_state_diagram-separate_edges"></a>separate_edges |  Lay out each state transition as a separate edge. Disabled by default.   | Boolean | optional |  `None`  |
| <a id="coco_state_diagram-tags"></a>tags |  <a href="https://bazel.build/reference/be/common-definitions#common.tags">Inherited rule attribute</a>   | List of strings; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_state_diagram-target_compatible_with"></a>target_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.target_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_state_diagram-targets"></a>targets |  Fully qualified names of state machines/components/ports to diagram (e.g. "MyComponent.myPort.stateMachine"). If empty, all state machines are drawn.   | List of strings | optional |  `None`  |
| <a id="coco_state_diagram-testonly"></a>testonly |  <a href="https://bazel.build/reference/be/common-definitions#common.testonly">Inherited rule attribute</a>   | Boolean; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_state_diagram-toolchains"></a>toolchains |  <a href="https://bazel.build/reference/be/common-definitions#common.toolchains">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_state_diagram-visibility"></a>visibility |  The visibility to be passed to this macro's exported targets. It always implicitly includes the location where this macro is instantiated, so this attribute only needs to be explicitly set if you want the macro's targets to be additionally visible somewhere else.   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  |


<a id="coco_verify_test"></a>

## coco_verify_test

<pre>
load("@rules_coco//coco:defs.bzl", "coco_verify_test")

coco_verify_test(*, <a href="#coco_verify_test-name">name</a>, <a href="#coco_verify_test-args">args</a>, <a href="#coco_verify_test-compatible_with">compatible_with</a>, <a href="#coco_verify_test-deprecation">deprecation</a>, <a href="#coco_verify_test-exec_compatible_with">exec_compatible_with</a>, <a href="#coco_verify_test-exec_properties">exec_properties</a>,
                 <a href="#coco_verify_test-features">features</a>, <a href="#coco_verify_test-flaky">flaky</a>, <a href="#coco_verify_test-local">local</a>, <a href="#coco_verify_test-package">package</a>, <a href="#coco_verify_test-package_metadata">package_metadata</a>, <a href="#coco_verify_test-restricted_to">restricted_to</a>, <a href="#coco_verify_test-shard_count">shard_count</a>, <a href="#coco_verify_test-size">size</a>,
                 <a href="#coco_verify_test-tags">tags</a>, <a href="#coco_verify_test-target_compatible_with">target_compatible_with</a>, <a href="#coco_verify_test-testonly">testonly</a>, <a href="#coco_verify_test-timeout">timeout</a>, <a href="#coco_verify_test-toolchains">toolchains</a>, <a href="#coco_verify_test-visibility">visibility</a>)
</pre>

Creates a test that runs Coco verification on a package.

Executes `popili verify` on the specified coco_package, failing the test if
verification does not pass.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="coco_verify_test-name"></a>name |  A unique name for this macro instance. Normally, this is also the name for the macro's main or only target. The names of any other targets that this macro might create will be this name with a string suffix.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="coco_verify_test-args"></a>args |  <a href="https://bazel.build/reference/be/common-definitions#test.args">Inherited rule attribute</a>   | List of strings | optional |  `None`  |
| <a id="coco_verify_test-compatible_with"></a>compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_verify_test-deprecation"></a>deprecation |  <a href="https://bazel.build/reference/be/common-definitions#common.deprecation">Inherited rule attribute</a>   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_verify_test-exec_compatible_with"></a>exec_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_verify_test-exec_properties"></a>exec_properties |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_properties">Inherited rule attribute</a>   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `None`  |
| <a id="coco_verify_test-features"></a>features |  <a href="https://bazel.build/reference/be/common-definitions#common.features">Inherited rule attribute</a>   | List of strings | optional |  `None`  |
| <a id="coco_verify_test-flaky"></a>flaky |  <a href="https://bazel.build/reference/be/common-definitions#test.flaky">Inherited rule attribute</a>   | Boolean; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_verify_test-local"></a>local |  <a href="https://bazel.build/reference/be/common-definitions#test.local">Inherited rule attribute</a>   | Boolean; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_verify_test-package"></a>package |  The coco_package target to verify.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="coco_verify_test-package_metadata"></a>package_metadata |  <a href="https://bazel.build/reference/be/common-definitions#common.package_metadata">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_verify_test-restricted_to"></a>restricted_to |  <a href="https://bazel.build/reference/be/common-definitions#common.restricted_to">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_verify_test-shard_count"></a>shard_count |  <a href="https://bazel.build/reference/be/common-definitions#test.shard_count">Inherited rule attribute</a>   | Integer | optional |  `None`  |
| <a id="coco_verify_test-size"></a>size |  <a href="https://bazel.build/reference/be/common-definitions#test.size">Inherited rule attribute</a>   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_verify_test-tags"></a>tags |  <a href="https://bazel.build/reference/be/common-definitions#common.tags">Inherited rule attribute</a>   | List of strings; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_verify_test-target_compatible_with"></a>target_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.target_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_verify_test-testonly"></a>testonly |  <a href="https://bazel.build/reference/be/common-definitions#common.testonly">Inherited rule attribute</a>   | Boolean; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_verify_test-timeout"></a>timeout |  <a href="https://bazel.build/reference/be/common-definitions#test.timeout">Inherited rule attribute</a>   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_verify_test-toolchains"></a>toolchains |  <a href="https://bazel.build/reference/be/common-definitions#common.toolchains">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_verify_test-visibility"></a>visibility |  The visibility to be passed to this macro's exported targets. It always implicitly includes the location where this macro is instantiated, so this attribute only needs to be explicitly set if you want the macro's targets to be additionally visible somewhere else.   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  |


<a id="coco_workspace"></a>

## coco_workspace

<pre>
load("@rules_coco//coco:defs.bzl", "coco_workspace")

coco_workspace(*, <a href="#coco_workspace-name">name</a>, <a href="#coco_workspace-compatible_with">compatible_with</a>, <a href="#coco_workspace-deprecation">deprecation</a>, <a href="#coco_workspace-exec_compatible_with">exec_compatible_with</a>, <a href="#coco_workspace-exec_properties">exec_properties</a>,
               <a href="#coco_workspace-features">features</a>, <a href="#coco_workspace-package_metadata">package_metadata</a>, <a href="#coco_workspace-parent">parent</a>, <a href="#coco_workspace-restricted_to">restricted_to</a>, <a href="#coco_workspace-tags">tags</a>, <a href="#coco_workspace-target_compatible_with">target_compatible_with</a>,
               <a href="#coco_workspace-testonly">testonly</a>, <a href="#coco_workspace-toolchains">toolchains</a>, <a href="#coco_workspace-visibility">visibility</a>, <a href="#coco_workspace-workspace">workspace</a>)
</pre>

Declares a Coco workspace root.

A workspace's Coco.toml carries shared settings that popili applies to member
packages. Reference this target from a coco_package's `workspace` attribute.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="coco_workspace-name"></a>name |  A unique name for this macro instance. Normally, this is also the name for the macro's main or only target. The names of any other targets that this macro might create will be this name with a string suffix.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="coco_workspace-compatible_with"></a>compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_workspace-deprecation"></a>deprecation |  <a href="https://bazel.build/reference/be/common-definitions#common.deprecation">Inherited rule attribute</a>   | String; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_workspace-exec_compatible_with"></a>exec_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_workspace-exec_properties"></a>exec_properties |  <a href="https://bazel.build/reference/be/common-definitions#common.exec_properties">Inherited rule attribute</a>   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `None`  |
| <a id="coco_workspace-features"></a>features |  <a href="https://bazel.build/reference/be/common-definitions#common.features">Inherited rule attribute</a>   | List of strings | optional |  `None`  |
| <a id="coco_workspace-package_metadata"></a>package_metadata |  <a href="https://bazel.build/reference/be/common-definitions#common.package_metadata">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_workspace-parent"></a>parent |  An enclosing coco_workspace, when this workspace is nested inside another   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="coco_workspace-restricted_to"></a>restricted_to |  <a href="https://bazel.build/reference/be/common-definitions#common.restricted_to">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_workspace-tags"></a>tags |  <a href="https://bazel.build/reference/be/common-definitions#common.tags">Inherited rule attribute</a>   | List of strings; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_workspace-target_compatible_with"></a>target_compatible_with |  <a href="https://bazel.build/reference/be/common-definitions#common.target_compatible_with">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_workspace-testonly"></a>testonly |  <a href="https://bazel.build/reference/be/common-definitions#common.testonly">Inherited rule attribute</a>   | Boolean; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  `None`  |
| <a id="coco_workspace-toolchains"></a>toolchains |  <a href="https://bazel.build/reference/be/common-definitions#common.toolchains">Inherited rule attribute</a>   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `None`  |
| <a id="coco_workspace-visibility"></a>visibility |  The visibility to be passed to this macro's exported targets. It always implicitly includes the location where this macro is instantiated, so this attribute only needs to be explicitly set if you want the macro's targets to be additionally visible somewhere else.   | <a href="https://bazel.build/concepts/labels">List of labels</a>; <a href="https://bazel.build/reference/be/common-definitions#configurable-attributes">nonconfigurable</a> | optional |  |
| <a id="coco_workspace-workspace"></a>workspace |  Label pointing to the workspace's root Coco.toml (must contain a [workspace] section)   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


