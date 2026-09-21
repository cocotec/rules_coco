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
| <a id="coco_local_repositories-kwargs"></a>kwargs |  Additional arguments:<br><br>license_source (str): Optional default license source mode. See `coco_repositories`.<br><br>license_token (str): Optional default license token.<br><br>auth_token_path (str): Optional auth token file path.   |  none |


<a id="coco_repositories"></a>

## coco_repositories

<pre>
load("@rules_coco//coco:repositories.bzl", "coco_repositories")

coco_repositories(<a href="#coco_repositories-version">version</a>, <a href="#coco_repositories-versions">versions</a>, <a href="#coco_repositories-c">c</a>, <a href="#coco_repositories-cc">cc</a>, <a href="#coco_repositories-license_source">license_source</a>, <a href="#coco_repositories-license_token">license_token</a>, <a href="#coco_repositories-auth_token_path">auth_token_path</a>,
                  <a href="#coco_repositories-cc_runtime_extra_deps">cc_runtime_extra_deps</a>, <a href="#coco_repositories-local_popili">local_popili</a>, <a href="#coco_repositories-local_cc_runtime">local_cc_runtime</a>, <a href="#coco_repositories-local_c_runtime">local_c_runtime</a>)
</pre>

Sets up Coco toolchain repositories for WORKSPACE mode.

Register several versions to build different targets against different Popili
releases in one build. The first entry of `versions` is the default; select any other
with `bazel build --@rules_coco//:version=1.5.1`, or per target with
`with_popili_version`. Call this at most once.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="coco_repositories-version"></a>version |  A single Coco version, for workspaces that need only one. Mutually exclusive with `versions`. Use an alias like 'stable' or an explicit version like '1.5.1'. Defaults to "stable" when neither argument is given.   |  `None` |
| <a id="coco_repositories-versions"></a>versions |  The Coco versions to register, in priority order; the first is used when `--@rules_coco//:version` is unset. Mutually exclusive with `version`.   |  `None` |
| <a id="coco_repositories-c"></a>c |  Whether to include C runtime support (for `coco_c_library`).   |  `False` |
| <a id="coco_repositories-cc"></a>cc |  Whether to include C++ runtime support (for `coco_cc_library`).   |  `False` |
| <a id="coco_repositories-license_source"></a>license_source |  Optional default license source mode for all toolchains (e.g. 'local_user', 'local_acquire', 'token', 'action_environment', 'action_file'). Can be overridden via the `--@rules_coco//:license_source` flag.   |  `""` |
| <a id="coco_repositories-license_token"></a>license_token |  Optional default license token for all toolchains when `license_source` is 'token'.   |  `""` |
| <a id="coco_repositories-auth_token_path"></a>auth_token_path |  Optional path to an auth token file for all toolchains when `license_source` is 'action_file'. The file must be available in the execution environment.   |  `""` |
| <a id="coco_repositories-cc_runtime_extra_deps"></a>cc_runtime_extra_deps |  cc_library labels appended to the Coco C++ runtime's deps. Use this to supply Boost (or equivalent) libraries on old compilers; see the rules_coco README. A list applies to every registered version; a dict maps a version (or alias) to the labels for that version alone. Labels are written verbatim into a generated repository, so they must be repository-absolute.   |  `[]` |
| <a id="coco_repositories-local_popili"></a>local_popili |  Optional path to a directory holding the `popili` and `cocotec-licensing-server` binaries, registered as an additional toolchain selected by `--@rules_coco//:version=local`.   |  `None` |
| <a id="coco_repositories-local_cc_runtime"></a>local_cc_runtime |  Optional path to a directory holding the local C++ runtime `coco/` subtree. Required to build `coco_cc_library` against `local_popili`.   |  `None` |
| <a id="coco_repositories-local_c_runtime"></a>local_c_runtime |  Optional path to a directory holding the local C runtime `coco_c/` subtree. Required to build `coco_c_library` against `local_popili`.   |  `None` |


