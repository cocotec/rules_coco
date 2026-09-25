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

"""Repository rules that materialise a single Coco toolchain.

Shared by WORKSPACE mode and bzlmod. Nothing here may call `native.*`: these rules
are instantiated both from a WORKSPACE macro and from a module extension, and the
native module is inaccessible inside an extension.
"""

load(
    ":common_repositories.bzl",
    "download_prefix",
    "resolve_local_path",
)
load(":known_shas.bzl", "FILE_KEY_TO_SHA")

def BUILD_for_coco_toolchain(name, cc_runtime_label = None, c_runtime_label = None, license_source = None, license_token = None, auth_token_path = None, version = None):
    """Emits a toolchain declaration to match an existing compiler and stdlib.

    Args:
      name: The name of the toolchain declaration
      cc_runtime_label: Optional label to the C++ runtime library (can be a Label object or string)
      c_runtime_label: Optional label to the C runtime library (can be a Label object or string)
      license_source: Optional license source mode (e.g., "local_user", "local_acquire", "token", "action_environment", "action_file")
      license_token: Optional license token string
      auth_token_path: Optional auth token file path string
      version: Optional popili version the toolchain provides (e.g. "1.5.1" or "local")

    Returns:
      A string containing BUILD file content for the toolchain.
    """

    # Use relative labels since coco and cocotec_licensing_server are defined
    # in the same BUILD file. This works in both WORKSPACE and bzlmod.
    cc_runtime_attr = ""
    if cc_runtime_label:
        cc_runtime_attr = '\n    cc_runtime = "{}",'.format(str(cc_runtime_label))

    c_runtime_attr = ""
    if c_runtime_label:
        c_runtime_attr = '\n    c_runtime = "{}",'.format(str(c_runtime_label))

    license_source_attr = ""
    if license_source and license_source != "":
        license_source_attr = '\n    license_source = "{}",'.format(license_source)

    license_token_attr = ""
    if license_token and license_token != "":
        license_token_attr = '\n    license_token = "{}",'.format(license_token)

    auth_token_path_attr = ""
    if auth_token_path and auth_token_path != "":
        auth_token_path_attr = '\n    auth_token_path = "{}",'.format(auth_token_path)

    version_attr = ""
    if version:
        version_attr = '\n    version = "{}",'.format(version)

    return """
coco_toolchain(
    name = "{toolchain_name}_impl",
    coco = "//:coco",
    cocotec_licensing_server = "//:cocotec_licensing_server",{cc_runtime_attr}{c_runtime_attr}{license_source_attr}{license_token_attr}{auth_token_path_attr}{version_attr}
    visibility = ["//visibility:public"],
)
""".format(
        toolchain_name = name,
        cc_runtime_attr = cc_runtime_attr,
        c_runtime_attr = c_runtime_attr,
        license_source_attr = license_source_attr,
        license_token_attr = license_token_attr,
        auth_token_path_attr = auth_token_path_attr,
        version_attr = version_attr,
    )

def BUILD_for_coco_archive(binary_ext, product):
    """Emits a BUILD file the compiler .zip."""
    return """
load("@rules_coco//coco:toolchain.bzl", "coco_toolchain")

filegroup(
    name = "coco",
    srcs = ["bin/{product}{binary_ext}"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "cocotec_licensing_server",
    srcs = ["bin/cocotec-licensing-server{binary_ext}"],
    visibility = ["//visibility:public"],
)

""".format(
        binary_ext = binary_ext,
        product = product,
    )

def _platform_binary_ext(os):
    if os == "windows":
        return ".exe"
    return ""

def _product_for(version):
    parts = version.split("-")[0].split(".")
    if len(parts) >= 2 and int(parts[0]) == 1 and int(parts[1]) < 5:
        return "coco"
    return "popili"

def coco_toolchain_download(version, os, arch):
    """Returns where to download a popili toolchain archive from, and its known checksum.

    Args:
      version: The resolved Coco version (aliases must already be resolved), e.g. "1.5.7".
      os: The toolchain OS, as passed to the repository rule ("osx", "linux" or "windows").
      arch: The toolchain CPU, as passed to the repository rule ("aarch64" or "x86_64").

    Returns:
      A struct with `url` and `sha256` fields. `sha256` is "" when no checksum is known
      for the archive, which makes the download unverified.
    """
    archive = "{product}_{os}_{arch}.zip".format(
        arch = arch.replace("aarch64", "arm64").replace("x86_64", "amd64"),
        os = os.replace("osx", "darwin"),
        product = _product_for(version),
    )

    # known_shas.bzl is keyed by version, not by download path, so the "archive/"
    # prefix that download_prefix() adds must not be part of the lookup key.
    key = "{version}/{archive}".format(version = version, archive = archive)
    return struct(
        url = "https://dl.cocotec.io/popili/{download_prefix}/{archive}".format(
            download_prefix = download_prefix(version),
            archive = archive,
        ),
        sha256 = FILE_KEY_TO_SHA.get(key) or "",
    )

def _coco_toolchain_repository_impl(ctx):
    """The implementation of the coco toolchain repository rule."""

    product = _product_for(ctx.attr.version)

    # Download the compiler
    download = coco_toolchain_download(ctx.attr.version, ctx.attr.os, ctx.attr.arch)
    ctx.download_and_extract(
        url = download.url,
        output = "bin",
        sha256 = download.sha256,
    )

    ctx.file("WORKSPACE", "")
    ctx.file("BUILD", "\n".join([
        BUILD_for_coco_archive(binary_ext = _platform_binary_ext(ctx.attr.os), product = product),
        BUILD_for_coco_toolchain(
            name = "toolchain",
            cc_runtime_label = ctx.attr.cc_runtime_label,
            c_runtime_label = ctx.attr.c_runtime_label,
            license_source = ctx.attr.license_source,
            license_token = ctx.attr.license_token,
            auth_token_path = ctx.attr.auth_token_path,
            version = ctx.attr.version,
        ),
    ]))

coco_toolchain_repository = repository_rule(
    attrs = {
        "arch": attr.string(mandatory = True),
        "auth_token_path": attr.string(
            doc = "Optional auth token file path string",
            default = "",
        ),
        "c_runtime_label": attr.label(
            doc = "Optional label to the C runtime library",
            default = None,
        ),
        "cc_runtime_label": attr.label(
            doc = "Optional label to the C++ runtime library",
            default = None,
        ),
        "license_source": attr.string(
            doc = "Optional license source mode (e.g., 'local_user', 'local_acquire', 'token', 'action_environment', 'action_file')",
            default = "",
        ),
        "license_token": attr.string(
            doc = "Optional license token string",
            default = "",
        ),
        "os": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
    },
    implementation = _coco_toolchain_repository_impl,
)

def _coco_local_toolchain_repository_impl(ctx):
    """Coco toolchain repository symlinked from a local path instead of downloaded.

    Host-only, and the product is always "popili" (no os/arch/version attrs, unlike
    the download rule).
    """
    dist_dir = resolve_local_path(ctx, ctx.attr.path)

    # Take the extension from what's actually staged rather than guessing the host OS.
    binary_ext = ".exe" if dist_dir.get_child("popili.exe").exists else ""
    for binary in ["popili", "cocotec-licensing-server"]:
        src = dist_dir.get_child(binary + binary_ext)
        if not src.exists:
            fail("Local popili path '%s' does not contain '%s'" % (ctx.attr.path, binary + binary_ext))
        ctx.symlink(src, "bin/" + binary + binary_ext)

    ctx.file("WORKSPACE", "")
    ctx.file("BUILD", "\n".join([
        BUILD_for_coco_archive(binary_ext = binary_ext, product = "popili"),
        BUILD_for_coco_toolchain(
            name = "toolchain",
            cc_runtime_label = ctx.attr.cc_runtime_label,
            c_runtime_label = ctx.attr.c_runtime_label,
            license_source = ctx.attr.license_source,
            license_token = ctx.attr.license_token,
            auth_token_path = ctx.attr.auth_token_path,
            version = "local",
        ),
    ]))

coco_local_toolchain_repository = repository_rule(
    attrs = {
        "auth_token_path": attr.string(
            doc = "Optional auth token file path string",
            default = "",
        ),
        "c_runtime_label": attr.label(
            doc = "Optional label to the C runtime library",
            default = None,
        ),
        "cc_runtime_label": attr.label(
            doc = "Optional label to the C++ runtime library",
            default = None,
        ),
        "license_source": attr.string(
            doc = "Optional license source mode (e.g., 'local_user', 'local_acquire', 'token', 'action_environment', 'action_file')",
            default = "",
        ),
        "license_token": attr.string(
            doc = "Optional license token string",
            default = "",
        ),
        "path": attr.string(
            doc = "Local filesystem path to a directory containing the popili and cocotec-licensing-server binaries at its top level.",
            mandatory = True,
        ),
    },
    implementation = _coco_local_toolchain_repository_impl,
    # Reevaluated on every fetch so a replaced binary is picked up.
    local = True,
)
