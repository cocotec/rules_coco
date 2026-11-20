<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Coco toolchain implementation.

<a id="coco_toolchain"></a>

## coco_toolchain

<pre>
load("@rules_coco//coco:toolchain.bzl", "coco_toolchain")

coco_toolchain(<a href="#coco_toolchain-name">name</a>, <a href="#coco_toolchain-auth_token_path">auth_token_path</a>, <a href="#coco_toolchain-c_runtime">c_runtime</a>, <a href="#coco_toolchain-cc_runtime">cc_runtime</a>, <a href="#coco_toolchain-cc_test_runtime">cc_test_runtime</a>, <a href="#coco_toolchain-coco">coco</a>,
               <a href="#coco_toolchain-cocotec_licensing_server">cocotec_licensing_server</a>, <a href="#coco_toolchain-license_protocol_version">license_protocol_version</a>, <a href="#coco_toolchain-license_source">license_source</a>, <a href="#coco_toolchain-license_token">license_token</a>,
               <a href="#coco_toolchain-local_acquire_licenses">local_acquire_licenses</a>, <a href="#coco_toolchain-popili_version">popili_version</a>, <a href="#coco_toolchain-preferences_file">preferences_file</a>)
</pre>

Declares a popili toolchain: the `popili` binary, the Coco runtimes and the licence settings the Coco
rules run with.

rules_coco generates one for every version that `coco.toolchain` or `coco_repositories` registers. Declare one
yourself only to bring your own popili: wrap it in a `toolchain()` with
`toolchain_type = "@rules_coco//coco:toolchain_type"` and register it. See
[Custom toolchains](../toolchains.md#bring-your-own-toolchain).

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="coco_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="coco_toolchain-auth_token_path"></a>auth_token_path |  Path to the auth token file for `"action_file"` mode. The file must exist wherever actions run.   | String | optional |  `""`  |
| <a id="coco_toolchain-c_runtime"></a>c_runtime |  The C runtime library for Coco. Optional - only needed when using coco_c_library.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="coco_toolchain-cc_runtime"></a>cc_runtime |  The C++ runtime library for Coco. Optional - only needed when using coco_cc_library. Give it any extra deps it needs, such as Boost libraries for an old libstdc++, in its own `deps`: the `coco.cc_runtime_deps` tag only reaches the runtimes rules_coco generates.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="coco_toolchain-cc_test_runtime"></a>cc_test_runtime |  The library coco_cc_test_library links: `cc_runtime`, GoogleMock and the runtime's `coco/gmock_helpers.h`. Optional - only needed when a coco_cc_test_library compiles generated mocks; without it, coco_cc_test_library links `cc_runtime`. rules_coco's own toolchains set it when the GoogleMock library is configured, with the coco.cc_test_runtime tag in MODULE.bazel or `cc_test_runtime_gmock` of coco_repositories.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="coco_toolchain-coco"></a>coco |  The `popili` binary. Can be a file, a filegroup containing one file, or a binary built from source, which is built for the execution platform that runs it.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="coco_toolchain-cocotec_licensing_server"></a>cocotec_licensing_server |  Deprecated and unused: `local_acquire` acquires its licence when Bazel fetches repositories, with the server `coco_license_repository` names (see `local_acquire_licenses`). Will be removed.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="coco_toolchain-license_protocol_version"></a>license_protocol_version |  The licence protocol version the `popili` binary reads, `n` in `licenses_<n>.lic`, which picks its licence file under the local licence modes. Optional: 0 derives it from `popili_version`, or takes the newest protocol version rules_coco knows of when that is unknown. Set it when the popili reads a different protocol version than that.   | Integer | optional |  `0`  |
| <a id="coco_toolchain-license_source"></a>license_source |  The licence mode for this toolchain: `"local_user"`, `"local_acquire"`, `"token"`, `"action_environment"` or `"action_file"`; see [Licensing](../licensing.md#licence-modes). Empty means `"local_user"`. The `--@rules_coco//:license_source` flag overrides it.   | String | optional |  `""`  |
| <a id="coco_toolchain-license_token"></a>license_token |  The licence token for `"token"` mode.   | String | optional |  `""`  |
| <a id="coco_toolchain-local_acquire_licenses"></a>local_acquire_licenses |  The licences acquired for `local_acquire` licensing; popili gets the one of its licence protocol version by path. Required under `local_acquire`, where analysis fails without it. The toolchains rules_coco generates set it; a bring-your-own toolchain points it at a `coco_license_repository`.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="coco_toolchain-popili_version"></a>popili_version |  The version of the `popili` binary, such as `"1.5.8"`; an alias such as `"stable"` is rejected. Under the local licence modes it selects the licence file. A bring-your-own `toolchain()` without `target_settings` serves every target, so with it a target pinned to another version, or built with `--@rules_coco//:version` set to another version, fails. The toolchains rules_coco generates set it, and each serves only its own version; for a local distribution it is `"local"`.   | String | required |  |
| <a id="coco_toolchain-preferences_file"></a>preferences_file |  The location of the Popili `preferences.toml` file. Can be a direct source or a filegroup containing one item.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `"@io_cocotec_coco_preferences//:preferences"`  |


