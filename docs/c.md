<!-- Generated with Stardoc: http://skydoc.bazel.build -->

C integration macros for Coco-generated code.

<a id="coco_c_library"></a>

## coco_c_library

<pre>
load("@rules_coco//coco:c.bzl", "coco_c_library")

coco_c_library(<a href="#coco_c_library-name">name</a>, <a href="#coco_c_library-generated_package">generated_package</a>, <a href="#coco_c_library-srcs">srcs</a>, <a href="#coco_c_library-deps">deps</a>, <a href="#coco_c_library-kwargs">**kwargs</a>)
</pre>

Creates a C library from Coco-generated C code.

This automatically adds the Coco C runtime as a dependency by accessing
it from the Coco toolchain.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_c_library-name"></a>name |  The name of the library   |  none |
| <a id="coco_c_library-generated_package"></a>generated_package |  The coco_generate target that generates C code   |  none |
| <a id="coco_c_library-srcs"></a>srcs |  Additional C source files   |  `[]` |
| <a id="coco_c_library-deps"></a>deps |  Additional dependencies   |  `[]` |
| <a id="coco_c_library-kwargs"></a>kwargs |  Additional arguments passed to cc_library   |  none |


<a id="coco_c_test_library"></a>

## coco_c_test_library

<pre>
load("@rules_coco//coco:c.bzl", "coco_c_test_library")

coco_c_test_library(<a href="#coco_c_test_library-name">name</a>, <a href="#coco_c_test_library-generated_package">generated_package</a>, <a href="#coco_c_test_library-srcs">srcs</a>, <a href="#coco_c_test_library-deps">deps</a>, <a href="#coco_c_test_library-gmock">gmock</a>, <a href="#coco_c_test_library-kwargs">**kwargs</a>)
</pre>

Creates a C test library from Coco-generated C test code.

This automatically adds the Coco C runtime as a dependency by accessing
it from the Coco toolchain.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_c_test_library-name"></a>name |  The name of the test library   |  none |
| <a id="coco_c_test_library-generated_package"></a>generated_package |  The coco_package target that generates C test code   |  none |
| <a id="coco_c_test_library-srcs"></a>srcs |  Additional C source files   |  `[]` |
| <a id="coco_c_test_library-deps"></a>deps |  Additional dependencies   |  `[]` |
| <a id="coco_c_test_library-gmock"></a>gmock |  The GoogleTest/GoogleMock library to use (default: @googletest//:gtest)   |  `"@googletest//:gtest"` |
| <a id="coco_c_test_library-kwargs"></a>kwargs |  Additional arguments passed to cc_library   |  none |


