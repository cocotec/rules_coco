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

"""WORKSPACE-mode repository rules for Coco toolchains."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load(
    ":common_repositories.bzl",
    "KNOWN_VERSION_SUFFIXES",
    "coco_cc_repositories",
    "coco_fetch_license_repository",
    "coco_preferences_repository",
    "coco_symlink_license_repository",
    "download_prefix",
    "version_to_repo_suffix",
)
load(":known_shas.bzl", "FILE_KEY_TO_SHA")

def BUILD_for_toolchain(name, parent_workspace_name, constraints):
    return """
toolchain(
    name = "toolchain",
    exec_compatible_with = [{constraints}],
    toolchain = "@{parent_workspace_name}//:toolchain_impl",
    toolchain_type = "@rules_coco//coco:toolchain_type",
)
""".format(
        name = name,
        constraints = ", ".join(['"%s"' % constraint for constraint in constraints]),
        parent_workspace_name = parent_workspace_name,
    )

def BUILD_for_coco_toolchain(name, cc_runtime_label = None):
    """Emits a toolchain declaration to match an existing compiler and stdlib.

    Args:
      name: The name of the toolchain declaration
      cc_runtime_label: Optional label to the C++ runtime library (can be a Label object or string)

    Returns:
      A string containing BUILD file content for the toolchain.
    """

    # Use relative labels since coco and cocotec_licensing_server are defined
    # in the same BUILD file. This works in both WORKSPACE and bzlmod.
    cc_runtime_attr = ""
    if cc_runtime_label:
        cc_runtime_attr = '\n    cc_runtime = "{}",'.format(str(cc_runtime_label))

    return """
coco_toolchain(
    name = "{toolchain_name}_impl",
    coco = "//:coco",
    cocotec_licensing_server = "//:cocotec_licensing_server",{cc_runtime_attr}
    visibility = ["//visibility:public"],
)
""".format(
        toolchain_name = name,
        cc_runtime_attr = cc_runtime_attr,
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

def _coco_toolchain_repository_impl(ctx):
    """The implementation of the coco toolchain repository rule."""

    product = _product_for(ctx.attr.version)

    # Download the compiler
    download_path = "{download_prefix}/{product}_{os}_{arch}.zip".format(
        arch = ctx.attr.arch.replace("aarch64", "arm64").replace("x86_64", "amd64"),
        os = ctx.attr.os.replace("osx", "darwin"),
        download_prefix = download_prefix(ctx.attr.version),
        product = product,
    )
    ctx.download_and_extract(
        url = "https://dl.cocotec.io/popili/{download_path}".format(download_path = download_path),
        output = "bin",
        sha256 = FILE_KEY_TO_SHA.get(download_path) or "",
    )

    ctx.file("WORKSPACE", "")
    ctx.file("BUILD", "\n".join([
        BUILD_for_coco_archive(binary_ext = _platform_binary_ext(ctx.attr.os), product = product),
        BUILD_for_coco_toolchain(
            name = "toolchain",
            cc_runtime_label = ctx.attr.cc_runtime_label,
        ),
    ]))

def _coco_toolchain_repository_proxy_impl(ctx):
    # Delete the cached license token
    for suffix in KNOWN_VERSION_SUFFIXES:
        ctx.delete("licenses%s.lic" % suffix)

    ctx.file("WORKSPACE", "")
    ctx.file("BUILD", BUILD_for_toolchain(
        name = ctx.attr.name,
        parent_workspace_name = ctx.attr.parent_workspace_name,
        constraints = ctx.attr.constraints,
    ))

coco_toolchain_repository = repository_rule(
    attrs = {
        "arch": attr.string(mandatory = True),
        "cc_runtime_label": attr.label(
            doc = "Optional label to the C++ runtime library",
            default = None,
        ),
        "os": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
    },
    implementation = _coco_toolchain_repository_impl,
)

coco_toolchain_repository_proxy = repository_rule(
    attrs = {
        "constraints": attr.string_list(),
        "parent_workspace_name": attr.string(mandatory = True),
    },
    implementation = _coco_toolchain_repository_proxy_impl,
    # This ensures this is run on fetch, allowing us to refresh the license token
    local = True,
    configure = True,
)

def coco_repository_set(name, version, os, arch, constraints, cc_runtime_label = None):
    coco_toolchain_repository(
        arch = arch,
        os = os,
        name = name,
        version = version,
        cc_runtime_label = cc_runtime_label,
    )

    coco_toolchain_repository_proxy(
        name = name + "_toolchains",
        constraints = constraints,
        parent_workspace_name = name,
    )

    # Register toolchains
    native.register_toolchains("@{name}_toolchains//:toolchain".format(
        name = name,
    ))

def _coco_deps(version, cc = False):
    if not "bazel_skylib" in native.existing_rules():
        http_archive(
            name = "bazel_skylib",
            urls = [
                "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.8.1/bazel-skylib-1.8.1.tar.gz",
                "https://github.com/bazelbuild/bazel-skylib/releases/download/1.8.1/bazel-skylib-1.8.1.tar.gz",
            ],
            sha256 = "51b5105a760b353773f904d2bbc5e664d0987fbaf22265164de65d43e910d8ac",
        )

    if not "platforms" in native.existing_rules():
        http_archive(
            name = "platforms",
            urls = [
                "https://mirror.bazel.build/github.com/bazelbuild/platforms/releases/download/1.0.0/platforms-1.0.0.tar.gz",
                "https://github.com/bazelbuild/platforms/releases/download/1.0.0/platforms-1.0.0.tar.gz",
            ],
            sha256 = "3384eb1c30762704fbe38e440204e114154086c8fc8a8c2e3e28441028c019a8",
        )

    if cc:
        coco_cc_repositories(version = version)

    coco_preferences_repository(name = "io_cocotec_coco_preferences")
    coco_fetch_license_repository(
        name = "io_cocotec_licensing_fetch",
        versions = [version],
    )
    coco_symlink_license_repository(name = "io_cocotec_licensing_local")

def coco_repositories(version = "stable", **kwargs):
    """Sets up Coco toolchain repositories for WORKSPACE mode.

    Args:
      version: The Coco version to use (default: "stable").
      **kwargs: Additional arguments including 'cc' for C++ support.
    """
    cc = kwargs.get("cc", False)
    _coco_deps(
        version = version,
        **kwargs
    )

    # Determine cc_runtime_label if CC support is enabled
    cc_runtime_label = None
    if cc:
        version_suffix = version_to_repo_suffix(version)
        cc_runtime_label = "@io_cocotec_coco_cc_runtime__%s//:runtime" % version_suffix

    for (os, arch) in [
        ("osx", "aarch64"),
        ("osx", "x86_64"),
        ("linux", "aarch64"),
        ("linux", "x86_64"),
        ("windows", "x86_64"),
    ]:
        coco_repository_set(
            name = "io_cocotec_coco_%s_%s" % (os, arch),
            os = os,
            arch = arch,
            version = version,
            constraints = [
                "@platforms//os:%s" % os,
                "@platforms//cpu:%s" % arch,
            ],
            cc_runtime_label = cc_runtime_label,
        )

def coco_local_repository_set(name, path):
    native.new_local_repository(
        name = name,
        path = path,
        build_file_content = "\n".join([
            BUILD_for_coco_archive(binary_ext = "", product = "popili"),
            BUILD_for_coco_toolchain(
                name = "toolchain",
            ),
        ]),
        workspace_file_content = "",
    )

    coco_toolchain_repository_proxy(
        name = name + "_toolchains",
        constraints = [],
        parent_workspace_name = name,
    )

    # Register toolchains
    native.register_toolchains("@{name}_toolchains//:toolchain".format(
        name = name,
    ))

def coco_local_repositories(path, **kwargs):
    _coco_deps(
        version = "stable",
        **kwargs
    )
    coco_local_repository_set(
        name = "coco_local",
        path = path,
    )
