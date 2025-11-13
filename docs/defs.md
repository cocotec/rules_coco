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

coco_generate(<a href="#coco_generate-name">name</a>, <a href="#coco_generate-kwargs">**kwargs</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_generate-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="coco_generate-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


<a id="coco_package"></a>

## coco_package

<pre>
load("@rules_coco//coco:defs.bzl", "coco_package")

coco_package(<a href="#coco_package-name">name</a>, <a href="#coco_package-kwargs">**kwargs</a>)
</pre>

Define a Coco package from Coco.toml and .coco source files.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_package-name"></a>name |  Name of the package target   |  none |
| <a id="coco_package-kwargs"></a>kwargs |  Additional arguments passed to the underlying rule   |  none |


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

coco_verify_test(<a href="#coco_verify_test-kwargs">**kwargs</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_verify_test-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


