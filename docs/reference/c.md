<!-- Generated with Stardoc: http://skydoc.bazel.build -->

C integration macros for Coco-generated code.

<a id="coco_c_library"></a>

## coco_c_library

<pre>
load("@rules_coco//coco:c.bzl", "coco_c_library")

coco_c_library(<a href="#coco_c_library-name">name</a>, <a href="#coco_c_library-generated_package">generated_package</a>, <a href="#coco_c_library-generated_packages">generated_packages</a>, <a href="#coco_c_library-srcs">srcs</a>, <a href="#coco_c_library-hdrs">hdrs</a>, <a href="#coco_c_library-deps">deps</a>, <a href="#coco_c_library-public_hdrs">public_hdrs</a>,
               <a href="#coco_c_library-popili_version">popili_version</a>, <a href="#coco_c_library-library_rule">library_rule</a>, <a href="#coco_c_library-kwargs">**kwargs</a>)
</pre>

Creates a C library from Coco-generated C code.

The library depends on the Coco C runtime of its Popili version.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_c_library-name"></a>name |  The name of the library target.   |  none |
| <a id="coco_c_library-generated_package"></a>generated_package |  A coco_generate target (mutually exclusive with generated_packages)   |  `None` |
| <a id="coco_c_library-generated_packages"></a>generated_packages |  Multiple coco_generate targets to merge into one library   |  `[]` |
| <a id="coco_c_library-srcs"></a>srcs |  Hand-written C sources to add to the library.   |  `[]` |
| <a id="coco_c_library-hdrs"></a>hdrs |  Hand-written C headers to add to the library.   |  `[]` |
| <a id="coco_c_library-deps"></a>deps |  Other `cc_library` targets the library depends on, such as the library of each package this package depends on.   |  `[]` |
| <a id="coco_c_library-public_hdrs"></a>public_hdrs |  The generated headers dependents may include, each named by file name or by a trailing part of its include path, such as `"sensors/ISensor.h"`. An entry that matches no header is an error. Default: `None`, all of them; `[]` makes them all private.   |  `None` |
| <a id="coco_c_library-popili_version"></a>popili_version |  The registered Popili version whose runtime the library links, such as `"1.5.1"` or `"stable"`. The `coco_generate` targets in `generated_package` or `generated_packages` that have no `popili_version` of their own run with this version too, so pin the library like its `coco_generate` targets. `deps` is not affected: it is built as if the library had no pin. Default: `""`, the version the rest of the build uses. See [Pinning targets](../popili-versions.md#pinning-targets).   |  `""` |
| <a id="coco_c_library-library_rule"></a>library_rule |  The rule or macro that compiles the library, such as a wrapper of cc_library adding your project's defaults. It is called with cc_library's attributes. None means rules_cc's cc_library.   |  `None` |
| <a id="coco_c_library-kwargs"></a>kwargs |  Additional arguments passed to library_rule   |  none |


<a id="coco_c_test_library"></a>

## coco_c_test_library

<pre>
load("@rules_coco//coco:c.bzl", "coco_c_test_library")

coco_c_test_library(<a href="#coco_c_test_library-name">name</a>, <a href="#coco_c_test_library-generated_package">generated_package</a>, <a href="#coco_c_test_library-generated_packages">generated_packages</a>, <a href="#coco_c_test_library-srcs">srcs</a>, <a href="#coco_c_test_library-hdrs">hdrs</a>, <a href="#coco_c_test_library-deps">deps</a>, <a href="#coco_c_test_library-public_hdrs">public_hdrs</a>,
                    <a href="#coco_c_test_library-gmock">gmock</a>, <a href="#coco_c_test_library-popili_version">popili_version</a>, <a href="#coco_c_test_library-library_rule">library_rule</a>, <a href="#coco_c_test_library-kwargs">**kwargs</a>)
</pre>

Creates a C test library from Coco-generated C test code.

The library depends on the Coco C runtime of its Popili version, and on `gmock`.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_c_test_library-name"></a>name |  The name of the test library target.   |  none |
| <a id="coco_c_test_library-generated_package"></a>generated_package |  A coco_generate target whose package has test sources (mutually exclusive with generated_packages)   |  `None` |
| <a id="coco_c_test_library-generated_packages"></a>generated_packages |  Multiple coco_generate targets to merge into one library   |  `[]` |
| <a id="coco_c_test_library-srcs"></a>srcs |  Hand-written C sources to add to the library.   |  `[]` |
| <a id="coco_c_test_library-hdrs"></a>hdrs |  Hand-written C headers to add to the library.   |  `[]` |
| <a id="coco_c_test_library-deps"></a>deps |  Other `cc_library` targets the library depends on, such as the library of each package this package depends on.   |  `[]` |
| <a id="coco_c_test_library-public_hdrs"></a>public_hdrs |  The generated test headers dependents may include, each named by file name or by a trailing part of its include path, such as `"runnable/RunnableMock.h"`. An entry that matches no header is an error. Default: `None`, all of them; `[]` makes them all private.   |  `None` |
| <a id="coco_c_test_library-gmock"></a>gmock |  The GoogleTest/GoogleMock library (default: @googletest//:gtest). Set to None to omit.   |  `"@googletest//:gtest"` |
| <a id="coco_c_test_library-popili_version"></a>popili_version |  The registered Popili version whose runtime the library links, such as `"1.5.1"` or `"stable"`. The `coco_generate` targets in `generated_package` or `generated_packages` that have no `popili_version` of their own run with this version too, so pin the library like its `coco_generate` targets. `deps` and `gmock` are not affected: they are built as if the library had no pin. Default: `""`, the version the rest of the build uses. See [Pinning targets](../popili-versions.md#pinning-targets).   |  `""` |
| <a id="coco_c_test_library-library_rule"></a>library_rule |  The rule or macro that compiles the library, such as a wrapper of cc_library adding your project's defaults. It is called with cc_library's attributes. None means rules_cc's cc_library.   |  `None` |
| <a id="coco_c_test_library-kwargs"></a>kwargs |  Additional arguments passed to library_rule   |  none |


