<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API for Coco repository rules.

<a id="coco_repositories"></a>

## coco_repositories

<pre>
load("@rules_coco//coco:repositories.bzl", "coco_repositories")

coco_repositories(<a href="#coco_repositories-version">version</a>, <a href="#coco_repositories-kwargs">**kwargs</a>)
</pre>

Sets up Coco toolchain repositories for WORKSPACE mode.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_repositories-version"></a>version |  The Coco version to use (default: "stable").   |  `"stable"` |
| <a id="coco_repositories-kwargs"></a>kwargs |  Additional arguments including 'cc' for C++ support.   |  none |


