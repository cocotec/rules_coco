<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Bazel module extensions for rules_coco.

<a id="coco"></a>

## coco

<pre>
coco = use_extension("@rules_coco//coco:extensions.bzl", "coco")
coco.cc_runtime_deps(<a href="#coco.cc_runtime_deps-deps">deps</a>, <a href="#coco.cc_runtime_deps-version">version</a>)
coco.local_toolchain(<a href="#coco.local_toolchain-c_runtime">c_runtime</a>, <a href="#coco.local_toolchain-cc_runtime">cc_runtime</a>, <a href="#coco.local_toolchain-license_protocol_version">license_protocol_version</a>, <a href="#coco.local_toolchain-popili">popili</a>)
coco.toolchain(<a href="#coco.toolchain-auth_token_path">auth_token_path</a>, <a href="#coco.toolchain-c">c</a>, <a href="#coco.toolchain-cc">cc</a>, <a href="#coco.toolchain-license_source">license_source</a>, <a href="#coco.toolchain-license_token">license_token</a>, <a href="#coco.toolchain-versions">versions</a>)
</pre>


**TAG CLASSES**

<a id="coco.cc_runtime_deps"></a>

### cc_runtime_deps

Inject extra `cc_library` deps into the Coco C++ runtime for a specific Popili version. Root-module only. See [Older C++ compilers](../old-compilers.md) for when this is needed (typically Boost libraries when building against old libstdc++).

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="coco.cc_runtime_deps-deps"></a>deps |  List of `cc_library` targets to append to the runtime's deps.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="coco.cc_runtime_deps-version"></a>version |  Popili version these deps apply to. May be an explicit version (e.g. `"1.5.1"`), an alias (e.g. `"stable"`), or `"local"` for the `coco.local_toolchain` runtime.   | String | required |  |

<a id="coco.local_toolchain"></a>

### local_toolchain

Register a Coco toolchain from a popili distribution on the local filesystem, instead of fetching a published release. Root-module only, at most once. Used only under `--@rules_coco//:version=local`. Paths mirror the extracted release archive layout; see [Custom toolchains](../toolchains.md).

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="coco.local_toolchain-c_runtime"></a>c_runtime |  Optional path to a dir holding the C runtime `coco_c/` subtree. Absolute or workspace-relative.   | String | optional |  `""`  |
| <a id="coco.local_toolchain-cc_runtime"></a>cc_runtime |  Optional path to a dir holding the C++ runtime `coco/` subtree. Absolute or workspace-relative.   | String | optional |  `""`  |
| <a id="coco.local_toolchain-license_protocol_version"></a>license_protocol_version |  Optional licence protocol version the local popili reads. See [`coco_toolchain`](toolchain.md#coco_toolchain-license_protocol_version).   | Integer | optional |  `0`  |
| <a id="coco.local_toolchain-popili"></a>popili |  Path to a dir holding the `popili` and `cocotec-licensing-server` binaries. Absolute or workspace-relative.   | String | required |  |

<a id="coco.toolchain"></a>

### toolchain

Register Coco toolchains for one or more popili versions. Every module declaring this tag contributes its versions and runtimes. When no module declares one, `stable` is registered with the C and C++ runtimes.

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="coco.toolchain-auth_token_path"></a>auth_token_path |  Path to the auth token file for `"action_file"` mode. The file must exist wherever actions run.   | String | optional |  `""`  |
| <a id="coco.toolchain-c"></a>c |  Register the C runtime, needed by `coco_c_library` and `coco_c_test_library`. A runtime is registered when any module's tag asks for it. Default: `False`; when no module declares `coco.toolchain`, both runtimes are registered.   | Boolean | optional |  `False`  |
| <a id="coco.toolchain-cc"></a>cc |  Register the C++ runtime, needed by `coco_cc_library` and `coco_cc_test_library`. A runtime is registered when any module's tag asks for it. Default: `False`; when no module declares `coco.toolchain`, both runtimes are registered.   | Boolean | optional |  `False`  |
| <a id="coco.toolchain-license_source"></a>license_source |  Default licence mode for every toolchain rules_coco generates: `"local_user"`, `"local_acquire"`, `"token"`, `"action_environment"` or `"action_file"`; see [Licensing](../licensing.md#licence-modes). Empty means `"local_user"`. The `--@rules_coco//:license_source` flag overrides it. When several modules set it, the first wins.   | String | optional |  `""`  |
| <a id="coco.toolchain-license_token"></a>license_token |  The licence token for `"token"` mode.   | String | optional |  `""`  |
| <a id="coco.toolchain-versions"></a>versions |  Popili versions to register, such as `["1.5.1", "1.5.0"]`: explicit versions or aliases like `"stable"`. The versions of every module's tags are combined in module order, root module first, and the first of them is the default, used when `--@rules_coco//:version` is unset.   | List of strings | optional |  `["stable"]`  |


