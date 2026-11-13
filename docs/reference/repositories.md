<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Repository rules for `WORKSPACE` setup.

Also exports `AVAILABLE_STABLE_VERSIONS`: every stable popili version (1.5.0 onwards, no betas or release candidates)
whose downloads this rules_coco knows, newest first. `coco_repositories(versions = AVAILABLE_STABLE_VERSIONS)`
registers them all, with the newest as the default.

<a id="coco_local_repositories"></a>

## coco_local_repositories

<pre>
load("@rules_coco//coco:repositories.bzl", "coco_local_repositories")

coco_local_repositories(<a href="#coco_local_repositories-path">path</a>, <a href="#coco_local_repositories-cc_runtime_path">cc_runtime_path</a>, <a href="#coco_local_repositories-c_runtime_path">c_runtime_path</a>, *, <a href="#coco_local_repositories-license_source">license_source</a>, <a href="#coco_local_repositories-license_token">license_token</a>,
                        <a href="#coco_local_repositories-auth_token_path">auth_token_path</a>, <a href="#coco_local_repositories-license_protocol_version">license_protocol_version</a>)
</pre>

Sets up Coco toolchain repositories from a local popili path (WORKSPACE mode).

Use this to point the rules at a popili distribution already present on the local
filesystem (one you download and manage yourself, or an internal build) instead of
having rules_coco fetch a published release.

The registered toolchain is selected by `--@rules_coco//:version=local`, matching the
bzlmod `coco.local_toolchain` tag. To register a local distribution *alongside*
downloaded releases, call `coco_repositories(versions = [...], local_popili = ...)`
instead.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_local_repositories-path"></a>path |  Directory containing the `popili` and `cocotec-licensing-server` binaries at its top level (the extracted popili archive layout).   |  none |
| <a id="coco_local_repositories-cc_runtime_path"></a>cc_runtime_path |  Optional directory containing the local C++ runtime `coco/` subtree. Required to build `coco_cc_library` against the local toolchain.   |  `None` |
| <a id="coco_local_repositories-c_runtime_path"></a>c_runtime_path |  Optional directory containing the local C runtime `coco_c/` subtree. Required to build `coco_c_library` against the local toolchain.   |  `None` |
| <a id="coco_local_repositories-license_source"></a>license_source |  As for `coco_repositories`.   |  `""` |
| <a id="coco_local_repositories-license_token"></a>license_token |  As for `coco_repositories`.   |  `""` |
| <a id="coco_local_repositories-auth_token_path"></a>auth_token_path |  As for `coco_repositories`.   |  `""` |
| <a id="coco_local_repositories-license_protocol_version"></a>license_protocol_version |  Optional licence protocol version the local popili reads. See [`coco_toolchain`](toolchain.md#coco_toolchain-license_protocol_version).   |  `0` |


<a id="coco_repositories"></a>

## coco_repositories

<pre>
load("@rules_coco//coco:repositories.bzl", "coco_repositories")

coco_repositories(<a href="#coco_repositories-version">version</a>, *, <a href="#coco_repositories-versions">versions</a>, <a href="#coco_repositories-c">c</a>, <a href="#coco_repositories-cc">cc</a>, <a href="#coco_repositories-license_source">license_source</a>, <a href="#coco_repositories-license_token">license_token</a>, <a href="#coco_repositories-auth_token_path">auth_token_path</a>,
                  <a href="#coco_repositories-cc_runtime_extra_deps">cc_runtime_extra_deps</a>, <a href="#coco_repositories-local_popili">local_popili</a>, <a href="#coco_repositories-local_cc_runtime">local_cc_runtime</a>, <a href="#coco_repositories-local_c_runtime">local_c_runtime</a>,
                  <a href="#coco_repositories-local_license_protocol_version">local_license_protocol_version</a>)
</pre>

Sets up Coco toolchain repositories for WORKSPACE mode.

Register several versions to build different targets against different Popili
releases in one build. The first entry of `versions` is the default; select any other
with `bazel build --@rules_coco//:version=1.5.1`, or per target with
`popili_version`. Call this at most once. Every argument but `version` is
keyword-only.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_repositories-version"></a>version |  A single Popili version, for workspaces that need only one. Mutually exclusive with `versions`. Use an alias like 'stable' or an explicit version like '1.5.1'. Defaults to "stable" when neither argument is given.   |  `None` |
| <a id="coco_repositories-versions"></a>versions |  The Popili versions to register, in priority order; the first is used when `--@rules_coco//:version` is unset. Mutually exclusive with `version`.   |  `None` |
| <a id="coco_repositories-c"></a>c |  Whether to include C runtime support (for `coco_c_library`).   |  `False` |
| <a id="coco_repositories-cc"></a>cc |  Whether to include C++ runtime support (for `coco_cc_library`).   |  `False` |
| <a id="coco_repositories-license_source"></a>license_source |  Default licence mode for every toolchain: `"local_user"`, `"local_acquire"`, `"token"`, `"action_environment"` or `"action_file"`; see [Licensing](../licensing.md#licence-modes). Empty means `"local_user"`. The `--@rules_coco//:license_source` flag overrides it.   |  `""` |
| <a id="coco_repositories-license_token"></a>license_token |  The licence token for `"token"` mode.   |  `""` |
| <a id="coco_repositories-auth_token_path"></a>auth_token_path |  Path to the auth token file for `"action_file"` mode. The file must exist wherever actions run.   |  `""` |
| <a id="coco_repositories-cc_runtime_extra_deps"></a>cc_runtime_extra_deps |  cc_library labels appended to the Coco C++ runtime's deps. Use this to supply Boost (or equivalent) libraries on old compilers; see [Older C++ compilers](../old-compilers.md). A list applies to every registered version, including `local_popili`; a dict maps a version (or alias, or "local") to the labels for that version alone. Labels are written verbatim into a generated repository, so they must be repository-absolute. None is the same as an empty list.   |  `[]` |
| <a id="coco_repositories-local_popili"></a>local_popili |  Optional path to a directory holding the `popili` and `cocotec-licensing-server` binaries, registered as an additional toolchain selected by `--@rules_coco//:version=local`.   |  `None` |
| <a id="coco_repositories-local_cc_runtime"></a>local_cc_runtime |  Optional path to a directory holding the local C++ runtime `coco/` subtree. Required to build `coco_cc_library` against `local_popili`.   |  `None` |
| <a id="coco_repositories-local_c_runtime"></a>local_c_runtime |  Optional path to a directory holding the local C runtime `coco_c/` subtree. Required to build `coco_c_library` against `local_popili`.   |  `None` |
| <a id="coco_repositories-local_license_protocol_version"></a>local_license_protocol_version |  Optional licence protocol version `local_popili` reads. See [`coco_toolchain`](toolchain.md#coco_toolchain-license_protocol_version).   |  `0` |


