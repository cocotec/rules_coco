<!-- Generated with Stardoc: http://skydoc.bazel.build -->

C integration macros for Coco-generated code.

<a id="coco_c_library"></a>

## coco_c_library

<pre>
load("@rules_coco//coco:c.bzl", "coco_c_library")

coco_c_library(<a href="#coco_c_library-name">name</a>, <a href="#coco_c_library-generated_package">generated_package</a>, <a href="#coco_c_library-generated_packages">generated_packages</a>, <a href="#coco_c_library-srcs">srcs</a>, <a href="#coco_c_library-hdrs">hdrs</a>, <a href="#coco_c_library-deps">deps</a>, <a href="#coco_c_library-public_hdrs">public_hdrs</a>,
               <a href="#coco_c_library-library_rule">library_rule</a>, <a href="#coco_c_library-kwargs">**kwargs</a>)
</pre>

Creates a C library from Coco-generated C code.

This automatically adds the Coco C runtime as a dependency.

Generated headers are made available to downstream targets via CcInfo.
The `public_hdrs` parameter controls which generated headers are public:

- None (default): all generated headers are public
- ["ISensor.h", "Types.h"]: only listed headers are public, rest are private
- []: no generated headers are public (all private)

An entry matches a header by file name, or by a trailing part of its include path, such as
"sensors/ISensor.h", when several headers share a name. An entry that matches no header is
an error.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_c_library-name"></a>name |  The name of the library   |  none |
| <a id="coco_c_library-generated_package"></a>generated_package |  A coco_generate target (mutually exclusive with generated_packages)   |  `None` |
| <a id="coco_c_library-generated_packages"></a>generated_packages |  Multiple coco_generate targets to merge into one library   |  `[]` |
| <a id="coco_c_library-srcs"></a>srcs |  Additional C source files   |  `[]` |
| <a id="coco_c_library-hdrs"></a>hdrs |  Additional C header files   |  `[]` |
| <a id="coco_c_library-deps"></a>deps |  Additional dependencies   |  `[]` |
| <a id="coco_c_library-public_hdrs"></a>public_hdrs |  List of generated header names to make public, or None for all   |  `None` |
| <a id="coco_c_library-library_rule"></a>library_rule |  The rule or macro that compiles the library, such as a wrapper of cc_library adding your project's defaults. It is called with cc_library's attributes. None means rules_cc's cc_library.   |  `None` |
| <a id="coco_c_library-kwargs"></a>kwargs |  Additional arguments passed to library_rule   |  none |


<a id="coco_c_test_library"></a>

## coco_c_test_library

<pre>
load("@rules_coco//coco:c.bzl", "coco_c_test_library")

coco_c_test_library(<a href="#coco_c_test_library-name">name</a>, <a href="#coco_c_test_library-generated_package">generated_package</a>, <a href="#coco_c_test_library-generated_packages">generated_packages</a>, <a href="#coco_c_test_library-srcs">srcs</a>, <a href="#coco_c_test_library-hdrs">hdrs</a>, <a href="#coco_c_test_library-deps">deps</a>, <a href="#coco_c_test_library-public_hdrs">public_hdrs</a>,
                    <a href="#coco_c_test_library-gmock">gmock</a>, <a href="#coco_c_test_library-library_rule">library_rule</a>, <a href="#coco_c_test_library-kwargs">**kwargs</a>)
</pre>

Creates a C test library from Coco-generated C test code.

This automatically adds the Coco C runtime and GoogleTest as dependencies.

Generated test headers are made available to downstream targets via CcInfo.
The `public_hdrs` parameter controls which generated test headers are public:

- None (default): all generated test headers are public
- ["RunnableMock.h"]: only listed headers are public, rest are private
- []: no generated test headers are public (all private)

An entry matches a header by file name, or by a trailing part of its include path, such as
"runnable/RunnableMock.h", when several headers share a name. An entry that matches no
header is an error.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_c_test_library-name"></a>name |  The name of the test library   |  none |
| <a id="coco_c_test_library-generated_package"></a>generated_package |  A coco_generate target whose package has test sources (mutually exclusive with generated_packages)   |  `None` |
| <a id="coco_c_test_library-generated_packages"></a>generated_packages |  Multiple coco_generate targets to merge into one library   |  `[]` |
| <a id="coco_c_test_library-srcs"></a>srcs |  Additional C source files   |  `[]` |
| <a id="coco_c_test_library-hdrs"></a>hdrs |  Additional C header files   |  `[]` |
| <a id="coco_c_test_library-deps"></a>deps |  Additional dependencies   |  `[]` |
| <a id="coco_c_test_library-public_hdrs"></a>public_hdrs |  List of generated test header names to make public, or None for all   |  `None` |
| <a id="coco_c_test_library-gmock"></a>gmock |  The GoogleTest/GoogleMock library (default: @googletest//:gtest). Set to None to omit.   |  `"@googletest//:gtest"` |
| <a id="coco_c_test_library-library_rule"></a>library_rule |  The rule or macro that compiles the library, such as a wrapper of cc_library adding your project's defaults. It is called with cc_library's attributes. None means rules_cc's cc_library.   |  `None` |
| <a id="coco_c_test_library-kwargs"></a>kwargs |  Additional arguments passed to library_rule   |  none |


