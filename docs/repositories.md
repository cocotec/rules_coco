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
| <a id="coco_repositories-version"></a>version |  The Coco version to use. Use version aliases like 'stable' or explicit versions like '1.5.1'. Default is "stable".   |  `"stable"` |
| <a id="coco_repositories-kwargs"></a>kwargs |  Additional arguments:<br><br>c (bool): Whether to include C runtime support.<br><br>cc (bool): Whether to include C++ runtime support.<br><br>license_source (str): Optional default license source mode for all toolchains (e.g., 'local_user', 'local_acquire', 'token', 'action_environment', 'action_file'). Can be overridden via --@rules_coco//:license_source flag.<br><br>license_token (str): Optional default license token for all toolchains when license_source is 'token'.<br><br>auth_token_path (str): Optional path to auth token file for all toolchains when license_source is 'action_file'. The file must be available in the execution environment.   |  none |


