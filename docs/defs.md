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


<a id="coco_architecture_diagram"></a>

## coco_architecture_diagram

<pre>
load("@rules_coco//coco:defs.bzl", "coco_architecture_diagram")

coco_architecture_diagram(<a href="#coco_architecture_diagram-name">name</a>, <a href="#coco_architecture_diagram-package">package</a>, <a href="#coco_architecture_diagram-components">components</a>, <a href="#coco_architecture_diagram-port_names">port_names</a>, <a href="#coco_architecture_diagram-port_types">port_types</a>, <a href="#coco_architecture_diagram-component_names">component_names</a>,
                          <a href="#coco_architecture_diagram-component_types">component_types</a>, <a href="#coco_architecture_diagram-depth">depth</a>, <a href="#coco_architecture_diagram-hide_ports">hide_ports</a>, <a href="#coco_architecture_diagram-only_encapsulating">only_encapsulating</a>, <a href="#coco_architecture_diagram-only_roots">only_roots</a>,
                          <a href="#coco_architecture_diagram-kwargs">**kwargs</a>)
</pre>

Creates architecture diagrams.

Generates SVG diagrams showing component architecture using `popili graph-component`.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_architecture_diagram-name"></a>name |  Name of the diagram target   |  none |
| <a id="coco_architecture_diagram-package"></a>package |  The coco_package target to generate architecture diagrams for   |  none |
| <a id="coco_architecture_diagram-components"></a>components |  Dict mapping output filenames to component names (e.g., {"my_component.svg": "MyComponent"})   |  none |
| <a id="coco_architecture_diagram-port_names"></a>port_names |  Show instance name of each port (default: False)   |  `False` |
| <a id="coco_architecture_diagram-port_types"></a>port_types |  Show type of each port (default: True)   |  `True` |
| <a id="coco_architecture_diagram-component_names"></a>component_names |  Show instance name of child components (default: False)   |  `False` |
| <a id="coco_architecture_diagram-component_types"></a>component_types |  Show type of each component (default: True)   |  `True` |
| <a id="coco_architecture_diagram-depth"></a>depth |  Recursive drawing depth: integer string, 'auto', 'max', or empty for default   |  `""` |
| <a id="coco_architecture_diagram-hide_ports"></a>hide_ports |  Hide ports in diagrams (default: False)   |  `False` |
| <a id="coco_architecture_diagram-only_encapsulating"></a>only_encapsulating |  Don't draw implementation/external components (default: True)   |  `True` |
| <a id="coco_architecture_diagram-only_roots"></a>only_roots |  Only draw root components (default: False)   |  `False` |
| <a id="coco_architecture_diagram-kwargs"></a>kwargs |  Additional Bazel arguments (e.g., visibility, tags)   |  none |


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


<a id="coco_fmt_test"></a>

## coco_fmt_test

<pre>
load("@rules_coco//coco:defs.bzl", "coco_fmt_test")

coco_fmt_test(<a href="#coco_fmt_test-name">name</a>, <a href="#coco_fmt_test-package">package</a>, <a href="#coco_fmt_test-kwargs">**kwargs</a>)
</pre>

Creates both a format test and a format binary.

This macro creates two targets:
1. A test target (with the given name) that checks formatting via `bazel test`
2. A binary target (with _test suffix removed) that formats code via `bazel run`

For example, if you create `coco_fmt_test(name = "my_pkg_fmt_test", ...)`,
two targets are generated:
- `my_pkg_fmt_test`: Test that fails if code isn't formatted correctly
- `my_pkg_fmt`: Binary to format the code in-place


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_fmt_test-name"></a>name |  The name of the test target. Should typically end with '_test'.   |  none |
| <a id="coco_fmt_test-package"></a>package |  The coco_package target to check/format.   |  none |
| <a id="coco_fmt_test-kwargs"></a>kwargs |  Additional arguments forwarded to both rules (e.g., tags, visibility).   |  none |


<a id="coco_generate"></a>

## coco_generate

<pre>
load("@rules_coco//coco:defs.bzl", "coco_generate")

coco_generate(<a href="#coco_generate-name">name</a>, <a href="#coco_generate-package">package</a>, <a href="#coco_generate-language">language</a>, <a href="#coco_generate-mocks">mocks</a>, <a href="#coco_generate-c_file_name_mangler">c_file_name_mangler</a>, <a href="#coco_generate-c_flat_file_hierarchy">c_flat_file_hierarchy</a>,
              <a href="#coco_generate-c_header_file_extension">c_header_file_extension</a>, <a href="#coco_generate-c_header_file_prefix">c_header_file_prefix</a>, <a href="#coco_generate-c_implementation_file_extension">c_implementation_file_extension</a>,
              <a href="#coco_generate-c_implementation_file_prefix">c_implementation_file_prefix</a>, <a href="#coco_generate-c_regenerate_packages">c_regenerate_packages</a>, <a href="#coco_generate-cpp_file_name_mangler">cpp_file_name_mangler</a>,
              <a href="#coco_generate-cpp_flat_file_hierarchy">cpp_flat_file_hierarchy</a>, <a href="#coco_generate-cpp_header_file_extension">cpp_header_file_extension</a>, <a href="#coco_generate-cpp_header_file_prefix">cpp_header_file_prefix</a>,
              <a href="#coco_generate-cpp_implementation_file_extension">cpp_implementation_file_extension</a>, <a href="#coco_generate-cpp_implementation_file_prefix">cpp_implementation_file_prefix</a>,
              <a href="#coco_generate-cpp_regenerate_packages">cpp_regenerate_packages</a>, <a href="#coco_generate-csharp_regenerate_packages">csharp_regenerate_packages</a>, <a href="#coco_generate-kwargs">**kwargs</a>)
</pre>

Generate C, C++, or C# code from a Coco package.

This macro generates code from Coco source files in the specified language.
The generated files can then be compiled into libraries or executables using
standard build rules (e.g., cc_library for C/C++).

The generator configuration options (file extensions, prefixes, etc.) must match
the settings in your Coco.toml file under the corresponding generator section
(e.g., [generator.cpp] for C++, [generator.c] for C).


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_generate-name"></a>name |  Name of the code generation target   |  none |
| <a id="coco_generate-package"></a>package |  The coco_package target containing the source files to generate from   |  none |
| <a id="coco_generate-language"></a>language |  Target language for code generation: "cpp", "c", or "csharp"   |  none |
| <a id="coco_generate-mocks"></a>mocks |  Generate mock implementations for testing (default: False)   |  `False` |
| <a id="coco_generate-c_file_name_mangler"></a>c_file_name_mangler |  C file naming style - must match Coco.toml generator.c.fileNameMangler. Options: "Unaltered", "LowerCamelCase", "UpperCamelCase", "LowerUnderscore", "UpperUnderscore", "CapsUpperUnderscore"   |  `"Unaltered"` |
| <a id="coco_generate-c_flat_file_hierarchy"></a>c_flat_file_hierarchy |  Use flat directory structure for C files - must match Coco.toml generator.c.flatFileHierarchy   |  `False` |
| <a id="coco_generate-c_header_file_extension"></a>c_header_file_extension |  File extension for C headers (default: ".h")   |  `".h"` |
| <a id="coco_generate-c_header_file_prefix"></a>c_header_file_prefix |  Prefix for C header file names (default: "")   |  `""` |
| <a id="coco_generate-c_implementation_file_extension"></a>c_implementation_file_extension |  File extension for C implementation files (default: ".c")   |  `".c"` |
| <a id="coco_generate-c_implementation_file_prefix"></a>c_implementation_file_prefix |  Prefix for C implementation file names (default: "")   |  `""` |
| <a id="coco_generate-c_regenerate_packages"></a>c_regenerate_packages |  List of other coco_package targets to regenerate with this target's C generator settings   |  `[]` |
| <a id="coco_generate-cpp_file_name_mangler"></a>cpp_file_name_mangler |  C++ file naming style - must match Coco.toml generator.cpp.fileNameMangler. Options: "Unaltered", "LowerCamelCase", "UpperCamelCase", "LowerUnderscore", "UpperUnderscore", "CapsUpperUnderscore"   |  `"Unaltered"` |
| <a id="coco_generate-cpp_flat_file_hierarchy"></a>cpp_flat_file_hierarchy |  Use flat directory structure for C++ files - must match Coco.toml generator.cpp.flatFileHierarchy   |  `False` |
| <a id="coco_generate-cpp_header_file_extension"></a>cpp_header_file_extension |  File extension for C++ headers (default: ".h")   |  `".h"` |
| <a id="coco_generate-cpp_header_file_prefix"></a>cpp_header_file_prefix |  Prefix for C++ header file names (default: "")   |  `""` |
| <a id="coco_generate-cpp_implementation_file_extension"></a>cpp_implementation_file_extension |  File extension for C++ implementation files (default: ".cc")   |  `".cc"` |
| <a id="coco_generate-cpp_implementation_file_prefix"></a>cpp_implementation_file_prefix |  Prefix for C++ implementation file names (default: "")   |  `""` |
| <a id="coco_generate-cpp_regenerate_packages"></a>cpp_regenerate_packages |  List of other coco_package targets to regenerate with this target's C++ generator settings   |  `[]` |
| <a id="coco_generate-csharp_regenerate_packages"></a>csharp_regenerate_packages |  List of other coco_package targets to regenerate with this target's C# generator settings   |  `[]` |
| <a id="coco_generate-kwargs"></a>kwargs |  Additional Bazel arguments (e.g., visibility, tags)   |  none |


<a id="coco_package"></a>

## coco_package

<pre>
load("@rules_coco//coco:defs.bzl", "coco_package")

coco_package(<a href="#coco_package-name">name</a>, <a href="#coco_package-package">package</a>, <a href="#coco_package-srcs">srcs</a>, <a href="#coco_package-deps">deps</a>, <a href="#coco_package-test_srcs">test_srcs</a>, <a href="#coco_package-typecheck">typecheck</a>, <a href="#coco_package-kwargs">**kwargs</a>)
</pre>

Define a Coco package from Coco.toml and .coco source files.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_package-name"></a>name |  Name of the package target   |  none |
| <a id="coco_package-package"></a>package |  Label pointing to the Coco.toml file for this package   |  none |
| <a id="coco_package-srcs"></a>srcs |  List of .coco source files for this package   |  none |
| <a id="coco_package-deps"></a>deps |  List of other coco_package targets this package depends on   |  `[]` |
| <a id="coco_package-test_srcs"></a>test_srcs |  List of .coco test source files   |  `[]` |
| <a id="coco_package-typecheck"></a>typecheck |  Run typecheck validation during package creation. When enabled, the build will fail if typecheck errors are found.   |  `False` |
| <a id="coco_package-kwargs"></a>kwargs |  Additional Bazel arguments (e.g., visibility, tags)   |  none |


<a id="coco_state_diagram"></a>

## coco_state_diagram

<pre>
load("@rules_coco//coco:defs.bzl", "coco_state_diagram")

coco_state_diagram(<a href="#coco_state_diagram-name">name</a>, <a href="#coco_state_diagram-package">package</a>, <a href="#coco_state_diagram-targets">targets</a>, <a href="#coco_state_diagram-separate_edges">separate_edges</a>, <a href="#coco_state_diagram-kwargs">**kwargs</a>)
</pre>

Creates state machine diagrams.

Generates SVG diagrams showing state machine structure using `popili graph-states`.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_state_diagram-name"></a>name |  Name of the diagram target   |  none |
| <a id="coco_state_diagram-package"></a>package |  The coco_package target to generate state diagrams for   |  none |
| <a id="coco_state_diagram-targets"></a>targets |  List of fully qualified names of state machines/components/ports to generate diagrams for. If empty, generates diagrams for all state machines (e.g., ["MyComponent.myPort.stateMachine"])   |  `[]` |
| <a id="coco_state_diagram-separate_edges"></a>separate_edges |  Layout option for state transitions (default: False)   |  `False` |
| <a id="coco_state_diagram-kwargs"></a>kwargs |  Additional Bazel arguments (e.g., visibility, tags)   |  none |


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


<a id="coco_verify_test"></a>

## coco_verify_test

<pre>
load("@rules_coco//coco:defs.bzl", "coco_verify_test")

coco_verify_test(<a href="#coco_verify_test-name">name</a>, <a href="#coco_verify_test-package">package</a>, <a href="#coco_verify_test-kwargs">**kwargs</a>)
</pre>

Creates a test that runs Coco verification on a package.

This test executes the `popili verify` command on the specified coco_package,
verifying the Coco code.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_verify_test-name"></a>name |  Name of the test target   |  none |
| <a id="coco_verify_test-package"></a>package |  The coco_package target to verify   |  none |
| <a id="coco_verify_test-kwargs"></a>kwargs |  Additional Bazel test arguments (e.g., size, timeout, tags, visibility)   |  none |


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


