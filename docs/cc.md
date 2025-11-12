<!-- Generated with Stardoc: http://skydoc.bazel.build -->

C++ integration rules for Coco-generated code.

<a id="coco_cc_runtime"></a>

## coco_cc_runtime

<pre>
load("@rules_coco//coco:cc.bzl", "coco_cc_runtime")

coco_cc_runtime(<a href="#coco_cc_runtime-name">name</a>)
</pre>

Helper rule that provides the C++ runtime from the Coco toolchain.

This rule is typically not used directly by users. Instead, use `coco_cc_library`
or `coco_cc_test_library` which automatically add the C++ runtime as a dependency.

Example:
    coco_cc_runtime(name = "runtime")

    cc_library(
        name = "my_lib",
        srcs = ["my_code.cc"],
        deps = [":runtime"],
    )

Note: The C++ runtime must be enabled in your workspace by setting `cc=True` in
`coco_repositories()` (WORKSPACE) or `coco.toolchain(cc=True)` (bzlmod).

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="coco_cc_runtime-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |


<a id="coco_cc_library"></a>

## coco_cc_library

<pre>
load("@rules_coco//coco:cc.bzl", "coco_cc_library")

coco_cc_library(<a href="#coco_cc_library-name">name</a>, <a href="#coco_cc_library-generated_package">generated_package</a>, <a href="#coco_cc_library-srcs">srcs</a>, <a href="#coco_cc_library-deps">deps</a>, <a href="#coco_cc_library-kwargs">**kwargs</a>)
</pre>

Creates a C++ library from Coco-generated C++ code.

This automatically adds the Coco C++ runtime as a dependency by accessing
it from the Coco toolchain.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_cc_library-name"></a>name |  The name of the library   |  none |
| <a id="coco_cc_library-generated_package"></a>generated_package |  The coco_package_generate target that generates C++ code   |  none |
| <a id="coco_cc_library-srcs"></a>srcs |  Additional C++ source files   |  `[]` |
| <a id="coco_cc_library-deps"></a>deps |  Additional dependencies   |  `[]` |
| <a id="coco_cc_library-kwargs"></a>kwargs |  Additional arguments passed to cc_library   |  none |


<a id="coco_cc_test_library"></a>

## coco_cc_test_library

<pre>
load("@rules_coco//coco:cc.bzl", "coco_cc_test_library")

coco_cc_test_library(<a href="#coco_cc_test_library-name">name</a>, <a href="#coco_cc_test_library-generated_package">generated_package</a>, <a href="#coco_cc_test_library-srcs">srcs</a>, <a href="#coco_cc_test_library-deps">deps</a>, <a href="#coco_cc_test_library-gmock">gmock</a>, <a href="#coco_cc_test_library-kwargs">**kwargs</a>)
</pre>

Creates a C++ test library from Coco-generated C++ test code.

This automatically adds the Coco C++ testing runtime as a dependency by accessing
it from the Coco toolchain.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_cc_test_library-name"></a>name |  The name of the test library   |  none |
| <a id="coco_cc_test_library-generated_package"></a>generated_package |  The coco_package target that generates C++ test code   |  none |
| <a id="coco_cc_test_library-srcs"></a>srcs |  Additional C++ source files   |  `[]` |
| <a id="coco_cc_test_library-deps"></a>deps |  Additional dependencies   |  `[]` |
| <a id="coco_cc_test_library-gmock"></a>gmock |  The GoogleTest/GoogleMock library to use (default: @googletest//:gtest)   |  `"@googletest//:gtest"` |
| <a id="coco_cc_test_library-kwargs"></a>kwargs |  Additional arguments passed to cc_library   |  none |


