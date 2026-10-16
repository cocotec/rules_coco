<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Coco toolchain implementation.

<a id="coco_toolchain"></a>

## coco_toolchain

<pre>
load("@rules_coco//coco:toolchain.bzl", "coco_toolchain")

coco_toolchain(<a href="#coco_toolchain-name">name</a>, <a href="#coco_toolchain-auth_token_path">auth_token_path</a>, <a href="#coco_toolchain-c_runtime">c_runtime</a>, <a href="#coco_toolchain-cc_runtime">cc_runtime</a>, <a href="#coco_toolchain-coco">coco</a>, <a href="#coco_toolchain-cocotec_licensing_server">cocotec_licensing_server</a>,
               <a href="#coco_toolchain-license_source">license_source</a>, <a href="#coco_toolchain-license_token">license_token</a>, <a href="#coco_toolchain-preferences_file">preferences_file</a>, <a href="#coco_toolchain-version">version</a>)
</pre>

Declares a Popili distribution as a Coco toolchain, for bringing your own instead of the toolchains `coco.toolchain` / `coco_repositories` generate. Register it with `toolchain(toolchain_type = "@rules_coco//coco:toolchain_type", ...)`.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="coco_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="coco_toolchain-auth_token_path"></a>auth_token_path |  The path to auth token file to use when license_source is 'action_file'. The file must be available in the execution environment. Optional.   | String | optional |  `""`  |
| <a id="coco_toolchain-c_runtime"></a>c_runtime |  The C runtime library for Coco. Optional - only needed when using coco_c_library.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="coco_toolchain-cc_runtime"></a>cc_runtime |  The C++ runtime library for Coco. Optional - only needed when using coco_cc_library. To inject extra deps into this target (e.g. Boost libraries for old libstdc++), use the coco.cc_runtime_deps tag in MODULE.bazel.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="coco_toolchain-coco"></a>coco |  The location of the `coco` binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="coco_toolchain-cocotec_licensing_server"></a>cocotec_licensing_server |  The location of the `cocotec-licensing-server` binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="coco_toolchain-license_source"></a>license_source |  The license source mode for this toolchain. Can be 'local_user', 'local_acquire', 'token', 'action_environment', or 'action_file'. If not specified, defaults to 'local_user'. Can be overridden via --@rules_coco//:license_source flag.   | String | optional |  `""`  |
| <a id="coco_toolchain-license_token"></a>license_token |  The license token to use when license_source is 'token'. Optional.   | String | optional |  `""`  |
| <a id="coco_toolchain-preferences_file"></a>preferences_file |  The location of the Popili `preferences.toml` file. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `"@io_cocotec_coco_preferences//:preferences"`  |
| <a id="coco_toolchain-version"></a>version |  The popili version of the `coco` binary, e.g. '1.5.7'. The toolchains rules_coco generates set it; a local distribution is 'local'. Optional: leave it empty when the version is unknown, which no version check rejects.   | String | optional |  `""`  |


