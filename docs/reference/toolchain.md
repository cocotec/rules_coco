<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Coco toolchain implementation.

<a id="coco_toolchain"></a>

## coco_toolchain

<pre>
load("@rules_coco//coco:toolchain.bzl", "coco_toolchain")

coco_toolchain(<a href="#coco_toolchain-name">name</a>, <a href="#coco_toolchain-auth_token_path">auth_token_path</a>, <a href="#coco_toolchain-c_runtime">c_runtime</a>, <a href="#coco_toolchain-cc_runtime">cc_runtime</a>, <a href="#coco_toolchain-coco">coco</a>, <a href="#coco_toolchain-cocotec_licensing_server">cocotec_licensing_server</a>,
               <a href="#coco_toolchain-license_protocol_version">license_protocol_version</a>, <a href="#coco_toolchain-license_source">license_source</a>, <a href="#coco_toolchain-license_token">license_token</a>, <a href="#coco_toolchain-popili_version">popili_version</a>,
               <a href="#coco_toolchain-preferences_file">preferences_file</a>)
</pre>

Declares a popili toolchain: the `popili` and `cocotec-licensing-server` binaries, the Coco runtimes and the
licence settings the Coco rules run with.

rules_coco generates one for every version that `coco.toolchain` or `coco_repositories` registers. Declare one
yourself only to bring your own popili: wrap it in a `toolchain()` with
`toolchain_type = "@rules_coco//coco:toolchain_type"` and register it. See
[Custom toolchains](../toolchains.md#bring-your-own-toolchain).

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="coco_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="coco_toolchain-auth_token_path"></a>auth_token_path |  The path to auth token file to use when license_source is 'action_file'. The file must be available in the execution environment. Optional.   | String | optional |  `""`  |
| <a id="coco_toolchain-c_runtime"></a>c_runtime |  The C runtime library for Coco. Optional - only needed when using coco_c_library.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="coco_toolchain-cc_runtime"></a>cc_runtime |  The C++ runtime library for Coco. Optional - only needed when using coco_cc_library. Give it any extra deps it needs, such as Boost libraries for an old libstdc++, in its own `deps`: the `coco.cc_runtime_deps` tag only reaches the runtimes rules_coco generates.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="coco_toolchain-coco"></a>coco |  The `popili` binary. Can be a file or a filegroup containing one file.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="coco_toolchain-cocotec_licensing_server"></a>cocotec_licensing_server |  The location of the `cocotec-licensing-server` binary. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="coco_toolchain-license_protocol_version"></a>license_protocol_version |  The licence protocol version the `popili` binary reads, `n` in `licenses_<n>.lic`, which picks its licence file under `local_user` licensing. Optional: 0 derives it from `popili_version`, or takes the newest protocol version rules_coco knows of when that is unknown. Set it when the popili reads a different protocol version than that.   | Integer | optional |  `0`  |
| <a id="coco_toolchain-license_source"></a>license_source |  The license source mode for this toolchain. Can be 'local_user', 'local_acquire', 'token', 'action_environment', or 'action_file'. If not specified, defaults to 'local_user'. Can be overridden via --@rules_coco//:license_source flag.   | String | optional |  `""`  |
| <a id="coco_toolchain-license_token"></a>license_token |  The license token to use when license_source is 'token'. Optional.   | String | optional |  `""`  |
| <a id="coco_toolchain-popili_version"></a>popili_version |  The version of the `popili` binary, such as "1.5.8"; not an alias such as "stable". It picks the licence file under `local_user` licensing, and every target this toolchain serves must ask for this version, or for none in particular. The toolchains rules_coco generates set it; a local distribution is 'local'.   | String | required |  |
| <a id="coco_toolchain-preferences_file"></a>preferences_file |  The location of the Popili `preferences.toml` file. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `"@io_cocotec_coco_preferences//:preferences"`  |


