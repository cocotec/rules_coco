<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Bazel module extensions for rules_coco.

<a id="coco"></a>

## coco

<pre>
coco = use_extension("@rules_coco//coco:extensions.bzl", "coco")
coco.toolchain(<a href="#coco.toolchain-auth_token_path">auth_token_path</a>, <a href="#coco.toolchain-c">c</a>, <a href="#coco.toolchain-cc">cc</a>, <a href="#coco.toolchain-license_source">license_source</a>, <a href="#coco.toolchain-license_token">license_token</a>, <a href="#coco.toolchain-versions">versions</a>)
</pre>


**TAG CLASSES**

<a id="coco.toolchain"></a>

### toolchain

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="coco.toolchain-auth_token_path"></a>auth_token_path |  Optional path to auth token file for all toolchains when license_source is 'action_file'. The file must be available in the execution environment.   | String | optional |  `""`  |
| <a id="coco.toolchain-c"></a>c |  Whether to include C runtime support   | Boolean | optional |  `False`  |
| <a id="coco.toolchain-cc"></a>cc |  Whether to include C++ runtime support   | Boolean | optional |  `False`  |
| <a id="coco.toolchain-license_source"></a>license_source |  Optional default license source mode for all toolchains (e.g., 'local_user', 'local_acquire', 'token', 'action_environment', 'action_file'). Can be overridden via --@rules_coco//:license_source flag.   | String | optional |  `""`  |
| <a id="coco.toolchain-license_token"></a>license_token |  Optional default license token for all toolchains when license_source is 'token'.   | String | optional |  `""`  |
| <a id="coco.toolchain-versions"></a>versions |  List of Coco/Popili versions to register (e.g., ['1.5.0', '1.4.0']). Use version aliases like 'stable' or explicit versions like '1.5.1'.   | List of strings | optional |  `["stable"]`  |


