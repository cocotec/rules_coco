<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API for Coco repository rules.

<a id="coco_local_repositories"></a>

## coco_local_repositories

<pre>
load("@rules_coco//coco:repositories.bzl", "coco_local_repositories")

coco_local_repositories(<a href="#coco_local_repositories-path">path</a>, <a href="#coco_local_repositories-cc_runtime_path">cc_runtime_path</a>, <a href="#coco_local_repositories-c_runtime_path">c_runtime_path</a>, <a href="#coco_local_repositories-kwargs">**kwargs</a>)
</pre>

Sets up Coco toolchain repositories from a local popili path (WORKSPACE mode).

Use this to point the rules at a popili distribution already present on the local
filesystem (one you download and manage yourself, or an internal build) instead of
having rules_coco fetch a published release.

Unlike the bzlmod `coco.local_toolchain` tag (which is gated behind
`--@rules_coco//:version=local`), WORKSPACE mode has no version flag plumbing, so
the local toolchain registered here becomes the active Coco toolchain for the build.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_local_repositories-path"></a>path |  Directory containing the `popili` and `cocotec-licensing-server` binaries at its top level (the extracted popili archive layout).   |  none |
| <a id="coco_local_repositories-cc_runtime_path"></a>cc_runtime_path |  Optional directory containing the local C++ runtime `coco/` subtree. Required to build `coco_cc_library` against the local toolchain.   |  `None` |
| <a id="coco_local_repositories-c_runtime_path"></a>c_runtime_path |  Optional directory containing the local C runtime `coco_c/` subtree. Required to build `coco_c_library` against the local toolchain.   |  `None` |
| <a id="coco_local_repositories-kwargs"></a>kwargs |  Additional arguments:<br><br>license_source (str): Optional default license source mode. See `coco_repositories`.<br><br>license_token (str): Optional default license token.<br><br>auth_token_path (str): Optional auth token file path.   |  none |


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
| <a id="coco_repositories-kwargs"></a>kwargs |  Additional arguments:<br><br>c (bool): Whether to include C runtime support.<br><br>cc (bool): Whether to include C++ runtime support.<br><br>license_source (str): Optional default license source mode for all toolchains (e.g., 'local_user', 'local_acquire', 'token', 'action_environment', 'action_file'). Can be overridden via --@rules_coco//:license_source flag.<br><br>license_token (str): Optional default license token for all toolchains when license_source is 'token'.<br><br>auth_token_path (str): Optional path to auth token file for all toolchains when license_source is 'action_file'. The file must be available in the execution environment.<br><br>cc_runtime_extra_deps (list): cc_library labels appended to the Coco C++ runtime's deps. Use this to supply Boost (or equivalent) libraries on old compilers; see the rules_coco README. Empty by default.   |  none |


