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

load(":known_shas.bzl", "FILE_KEY_TO_SHA")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def BUILD_for_toolchain(name, parent_workspace_name, constraints):
    return """
toolchain(
    name = "toolchain",
    exec_compatible_with = [{constraints}],
    target_compatible_with = [{constraints}],
    toolchain = "@{parent_workspace_name}//:toolchain_impl",
    toolchain_type = "@io_cocotec_rules_coco//coco:toolchain_type",
)
""".format(
        name = name,
        constraints = ", ".join(['"%s"' % constraint for constraint in constraints]),
        parent_workspace_name = parent_workspace_name,
    )

def BUILD_for_coco_toolchain(workspace_name, name):
    """Emits a toolchain declaration to match an existing compiler and stdlib.

    Args:
      workspace_name: The name of the workspace that this toolchain resides in
      name: The name of the toolchain declaration
    """

    return """
coco_toolchain(
    name = "{toolchain_name}_impl",
    coco = "@{workspace_name}//:coco",
    cocotec_licensing_server = "@{workspace_name}//:cocotec_licensing_server",
    crashpad_handler = "@{workspace_name}//:crashpad_handler",
    visibility = ["//visibility:public"],
)
""".format(
        toolchain_name = name,
        workspace_name = workspace_name,
    )

def BUILD_for_coco_archive(binary_ext):
    """Emits a BUILD file the compiler .zip."""
    return """
load("@io_cocotec_rules_coco//coco:toolchain.bzl", "coco_toolchain")

filegroup(
    name = "coco",
    srcs = ["bin/coco{binary_ext}"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "cocotec_licensing_server",
    srcs = ["bin/cocotec-licensing-server{binary_ext}"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "crashpad_handler",
    srcs = ["bin/crashpad-handler{binary_ext}"],
    visibility = ["//visibility:public"],
)

""".format(
        binary_ext = binary_ext,
    )

def _platform_binary_ext(platform):
    if platform == "windows":
        return ".exe"
    return ""

def _coco_toolchain_repository_impl(ctx):
    """The implementation of the coco toolchain repository rule."""

    # Download the compiler
    platform = ctx.attr.name.split("_")[1]
    file_name = "coco-{platform}".format(
        platform = platform,
    )
    download_path = "{version}/{file_name}.zip".format(version = ctx.attr.version, file_name = file_name)
    ctx.download_and_extract(
        url = "https://dl.cocotec.io/cp/{download_path}".format(download_path = download_path),
        output = "bin",
        sha256 = FILE_KEY_TO_SHA.get(download_path) or "",
    )

    ctx.file("WORKSPACE", "")
    ctx.file("BUILD", "\n".join([
        BUILD_for_coco_archive(binary_ext = _platform_binary_ext(platform)),
        BUILD_for_coco_toolchain(name = "toolchain", workspace_name = ctx.attr.name),
    ]))

def _coco_toolchain_repository_proxy_impl(ctx):
    # Delete the cached license token
    ctx.delete("licenses.lic")

    ctx.file("WORKSPACE", "")
    ctx.file("BUILD", BUILD_for_toolchain(
        name = ctx.attr.name,
        parent_workspace_name = ctx.attr.parent_workspace_name,
        constraints = ctx.attr.constraints,
    ))

coco_toolchain_repository = repository_rule(
    attrs = {
        "version": attr.string(mandatory = True),
    },
    implementation = _coco_toolchain_repository_impl,
)

coco_toolchain_repository_proxy = repository_rule(
    attrs = {
        "parent_workspace_name": attr.string(mandatory = True),
        "constraints": attr.string_list(),
    },
    implementation = _coco_toolchain_repository_proxy_impl,
    # This ensures this is run on fetch, allowing us to refresh the license token
    local = True,
    configure = True,
)

def coco_repository_set(name, version, constraints):
    coco_toolchain_repository(
        name = name,
        version = version,
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

def _coco_license_repository_impl(ctx):
    """Creates a repository to allow users to easily acquire new licenses"""
    ctx.file("WORKSPACE", "")
    ctx.file("BUILD", """
load("@io_cocotec_rules_coco//coco:licensing.bzl", "run_cocotec_license_server")

run_cocotec_license_server(
    name = "fetch",
    args = ["--acquire", "coco-platform"],
)
""")

_coco_license_repository = repository_rule(
    attrs = {
    },
    implementation = _coco_license_repository_impl,
)

def _coco_deps(runtime_version):
    if not "bazel_skylib" in native.existing_rules():
        http_archive(
            name = "bazel_skylib",
            urls = [
                "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.2/bazel-skylib-1.0.2.tar.gz",
                "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.2/bazel-skylib-1.0.2.tar.gz",
            ],
            sha256 = "97e70364e9249702246c0e9444bccdc4b847bed1eb03c5a3ece4f83dfe6abc44",
        )

    http_archive(
        name = "io_cocotec_coco_cc_runtime",
        urls = [
            "https://dl.cocotec.io/cp/{version}/coco_cpp_runtime.zip".format(version = runtime_version),
        ],
        sha256 = FILE_KEY_TO_SHA.get("{version}/coco_cpp_runtime.zip".format(version = runtime_version)),
        build_file_content = """
cc_library(
    name = "io_cocotec_coco_cc_runtime",
    hdrs = ["coco/runtime.h", "coco/stream_logger.h"],
    visibility = ["//visibility:public"],
)
""",
    )

    _coco_license_repository(
        name = "io_cocotec_licensing",
    )

def coco_repositories(version = "stable"):
    _coco_deps(runtime_version = version)

    coco_repository_set(
        name = "io_cocotec_coco_mac",
        version = version,
        constraints = [
            "@platforms//os:osx",
            "@platforms//cpu:x86_64",
        ],
    )

    coco_repository_set(
        name = "io_cocotec_coco_linux",
        version = version,
        constraints = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
    )

    coco_repository_set(
        name = "io_cocotec_coco_windows",
        version = version,
        constraints = [
            "@platforms//os:windows",
            "@platforms//cpu:x86_64",
        ],
    )

def coco_local_repository_set(name, path):
    native.new_local_repository(
        name = name,
        path = path,
        build_file_content = "\n".join([
            BUILD_for_coco_archive(binary_ext = ""),
            BUILD_for_coco_toolchain(name = "toolchain", workspace_name = name),
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

def coco_local_repositories(path):
    _coco_deps(runtime_version = "stable")
    coco_local_repository_set(
        name = "coco_local",
        path = path,
    )
