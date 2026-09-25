# Copyright 2019 Cocotec Limited
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""WORKSPACE-mode entrypoints for Coco toolchains.

The repositories themselves are declared by `//coco/private:toolchain_hub.bzl`, which is
shared with the bzlmod module extension so that both modes produce identical repository
names and an identical hub. This file adds only what a WORKSPACE can do and an extension
cannot: bootstrapping missing dependencies via `native.existing_rules`, and registering
the hub's toolchains via `native.register_toolchains`.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load(":cc_runtime_deps.bzl", "normalize_cc_runtime_extra_deps")
load(
    ":toolchain_hub.bzl",
    "DEFAULT_HUB_NAME",
    "declare_coco_toolchains",
    "resolve_versions",
)
load(":version_aliases.bzl", "VERSION_ALIASES")

def _resolve_version(version):
    if version in VERSION_ALIASES:
        return VERSION_ALIASES[version]
    return version

def _coco_bootstrap_deps():
    """Fetches the dependencies the generated repositories need, if absent.

    Only reaches repositories the user has not already declared, so a workspace pinning
    its own bazel_skylib or platforms keeps it. `native.existing_rules` only sees
    repositories declared earlier in the same WORKSPACE file, so `coco_repositories`
    should come after any such pin.
    """
    if not "bazel_skylib" in native.existing_rules():
        http_archive(
            name = "bazel_skylib",
            urls = [
                "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.9.2/bazel-skylib-1.9.2.tar.gz",
                "https://github.com/bazelbuild/bazel-skylib/releases/download/1.9.2/bazel-skylib-1.9.2.tar.gz",
            ],
            sha256 = "37cdfbc6faefea94f7b37760a305c98c08981116c2bc9e821e3b423221fad8c8",
        )

    if not "platforms" in native.existing_rules():
        http_archive(
            name = "platforms",
            urls = [
                "https://mirror.bazel.build/github.com/bazelbuild/platforms/releases/download/1.1.0/platforms-1.1.0.tar.gz",
                "https://github.com/bazelbuild/platforms/releases/download/1.1.0/platforms-1.1.0.tar.gz",
            ],
            sha256 = "dbad4a23abcca6171e47b79edc53bd6a41067a3b75f9e8b104656b459ff25046",
        )

# buildifier: disable=unnamed-macro
def coco_repositories(
        version = None,
        versions = None,
        c = False,
        cc = False,
        license_source = "",
        license_token = "",
        auth_token_path = "",
        cc_runtime_extra_deps = [],
        local_popili = None,
        local_cc_runtime = None,
        local_c_runtime = None):
    """Sets up Coco toolchain repositories for WORKSPACE mode.

    Register several versions to build different targets against different Popili
    releases in one build. The first entry of `versions` is the default; select any other
    with `bazel build --@rules_coco//:version=1.5.1`, or per target with
    `with_popili_version`. Call this at most once.

    Args:
      version: A single Coco version, for workspaces that need only one. Mutually
        exclusive with `versions`. Use an alias like 'stable' or an explicit version like
        '1.5.1'. Defaults to "stable" when neither argument is given.
      versions: The Coco versions to register, in priority order; the first is used when
        `--@rules_coco//:version` is unset. Mutually exclusive with `version`.
      c: Whether to include C runtime support (for `coco_c_library`).
      cc: Whether to include C++ runtime support (for `coco_cc_library`).
      license_source: Optional default license source mode for all toolchains (e.g.
        'local_user', 'local_acquire', 'token', 'action_environment', 'action_file').
        Can be overridden via the `--@rules_coco//:license_source` flag.
      license_token: Optional default license token for all toolchains when
        `license_source` is 'token'.
      auth_token_path: Optional path to an auth token file for all toolchains when
        `license_source` is 'action_file'. The file must be available in the execution
        environment.
      cc_runtime_extra_deps: cc_library labels appended to the Coco C++ runtime's deps.
        Use this to supply Boost (or equivalent) libraries on old compilers; see the
        rules_coco README. A list applies to every registered version; a dict maps a
        version (or alias) to the labels for that version alone. Labels are written
        verbatim into a generated repository, so they must be repository-absolute.
      local_popili: Optional path to a directory holding the `popili` and
        `cocotec-licensing-server` binaries, registered as an additional toolchain
        selected by `--@rules_coco//:version=local`.
      local_cc_runtime: Optional path to a directory holding the local C++ runtime
        `coco/` subtree. Required to build `coco_cc_library` against `local_popili`.
      local_c_runtime: Optional path to a directory holding the local C runtime `coco_c/`
        subtree. Required to build `coco_c_library` against `local_popili`.
    """
    if DEFAULT_HUB_NAME in native.existing_rules():
        fail(
            "coco_repositories() and coco_local_repositories() may be called at most " +
            "once per workspace. Pass every version you need in `versions = [...]`, and " +
            "a popili distribution on the local filesystem via `local_popili = ...`.",
        )

    if version != None and versions != None:
        fail("coco_repositories(): pass either `version` or `versions`, not both.")

    if versions == None:
        versions = [version if version != None else "stable"]

    resolved_versions, error = resolve_versions(versions, _resolve_version)
    if error:
        fail(error)

    if not resolved_versions and not local_popili:
        fail(
            "coco_repositories(): no versions and no `local_popili`, so no Coco " +
            "toolchain would be registered.",
        )

    _coco_bootstrap_deps()

    extra_deps_by_version, error = normalize_cc_runtime_extra_deps(
        cc_runtime_extra_deps,
        {resolved: True for resolved in resolved_versions},
        _resolve_version,
    )
    if error:
        fail(error)

    local = None
    if local_popili:
        local = struct(
            popili = local_popili,
            cc_runtime = local_cc_runtime or "",
            c_runtime = local_c_runtime or "",
        )

    declare_coco_toolchains(
        versions = resolved_versions,
        c = c,
        cc = cc,
        cc_runtime_extra_deps_by_version = extra_deps_by_version,
        license_source = license_source,
        license_token = license_token,
        auth_token_path = auth_token_path,
        local = local,
    )

    native.register_toolchains("@%s//:all" % DEFAULT_HUB_NAME)

def coco_local_repositories(path, cc_runtime_path = None, c_runtime_path = None, **kwargs):
    """Sets up Coco toolchain repositories from a local popili path (WORKSPACE mode).

    Use this to point the rules at a popili distribution already present on the local
    filesystem (one you download and manage yourself, or an internal build) instead of
    having rules_coco fetch a published release.

    The registered toolchain is selected by `--@rules_coco//:version=local`, matching the
    bzlmod `coco.local_toolchain` tag. To register a local distribution *alongside*
    downloaded releases, call `coco_repositories(versions = [...], local_popili = ...)`
    instead.

    Args:
      path: Directory containing the `popili` and `cocotec-licensing-server`
        binaries at its top level (the extracted popili archive layout).
      cc_runtime_path: Optional directory containing the local C++ runtime `coco/` subtree.
        Required to build `coco_cc_library` against the local toolchain.
      c_runtime_path: Optional directory containing the local C runtime `coco_c/` subtree.
        Required to build `coco_c_library` against the local toolchain.
      **kwargs: Additional arguments:

          license_source (str): Optional default license source mode. See `coco_repositories`.

          license_token (str): Optional default license token.

          auth_token_path (str): Optional auth token file path.
    """

    # buildifier: disable=print
    print(
        "coco_local_repositories(): the local Coco toolchain is selected by " +
        "--@rules_coco//:version=local. Builds that do not set that flag will report " +
        "no matching toolchain for @rules_coco//coco:toolchain_type.",
    )

    coco_repositories(
        versions = [],
        local_popili = path,
        local_cc_runtime = cc_runtime_path,
        local_c_runtime = c_runtime_path,
        license_source = kwargs.get("license_source", ""),
        license_token = kwargs.get("license_token", ""),
        auth_token_path = kwargs.get("auth_token_path", ""),
    )
