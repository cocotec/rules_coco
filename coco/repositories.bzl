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

def _preferences_file_text(remote_verification_mode, verification_server):
    lines = [
        "[verification]",
        'remote = "%s"' % remote_verification_mode,
    ]
    if verification_server:
        lines.append(
            'server = "%s"' % verification_server,
        )
    return "\n".join(lines)

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

""".format(
        binary_ext = binary_ext,
    )

def _platform_binary_ext(os):
    if os == "windows":
        return ".exe"
    return ""

def _coco_toolchain_repository_impl(ctx):
    """The implementation of the coco toolchain repository rule."""

    # Download the compiler
    download_path = "{version}/coco_{os}_{arch}.zip".format(
        arch = ctx.attr.arch.replace("aarch64", "arm64").replace("x86_64", "amd64"),
        os = ctx.attr.os.replace("osx", "darwin"),
        version = ctx.attr.version,
    )
    ctx.download_and_extract(
        url = "https://dl.cocotec.io/cp/archive/{download_path}".format(download_path = download_path),
        output = "bin",
        sha256 = FILE_KEY_TO_SHA.get(download_path) or "",
    )

    ctx.file("WORKSPACE", "")
    ctx.file("BUILD", "\n".join([
        BUILD_for_coco_archive(binary_ext = _platform_binary_ext(ctx.attr.os)),
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
        "arch": attr.string(mandatory = True),
        "os": attr.string(mandatory = True),
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

def coco_repository_set(name, version, os, arch, constraints):
    coco_toolchain_repository(
        arch = arch,
        os = os,
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

def _platform_license_file(ctx):
    if "os x" in ctx.os.name:
        return "%s/Library/Application Support/Coco Platform/licenses.lic" % ctx.os.environ.get("HOME")
    if "windows" in ctx.os.name:
        return "%s\\..\\LocalLow\\Coco Platform\\licenses.lic" % ctx.os.environ.get("APPDATA")
    return "%s/.local/share/coco_platform" % ctx.os.environ.get("HOME")

def _coco_license_repository_impl(ctx):
    """Creates a repository to allow users to easily acquire new licenses"""
    ctx.file("WORKSPACE", "")

    auth_token = ctx.os.environ.get("COCOTEC_AUTH_TOKEN", "")
    if auth_token:
        ctx.file("auth_token.secret", auth_token)
        ctx.file("BUILD", """
load("@io_cocotec_rules_coco//coco:licensing.bzl", "fetch_license")

fetch_license(
    name = "licenses",
    product = "coco-platform",
    auth_token = "auth_token.secret",
    visibility = ["//visibility:public"],
)
""")
    else:
        ctx.symlink(_platform_license_file(ctx), "licenses.lic")
        ctx.file("BUILD", """
filegroup(
    name = "licenses",
    srcs = ["licenses.lic"],
    visibility = ["//visibility:public"],
)
""")

_coco_license_repository = repository_rule(
    attrs = {
    },
    implementation = _coco_license_repository_impl,
    environ = ["APPDATA", "COCOTEC_AUTH_TOKEN", "HOME"],
    local = True,
)

def _coco_preferences_repository_impl(ctx):
    """Creates a repository to allow users to easily acquire new licenses"""
    ctx.file("preferences.toml", _preferences_file_text(
        remote_verification_mode = ctx.attr.remote_verification_mode,
        verification_server = ctx.attr.verification_server,
    ))
    ctx.file("WORKSPACE", "")
    ctx.file("BUILD", """
filegroup(
    name = "preferences",
    srcs = ["preferences.toml"],
    visibility = ["//visibility:public"],
)
""")

_coco_preferences_repository = repository_rule(
    attrs = {
        "verification_server": attr.bool(),
        "remote_verification_mode": attr.string(
            default = "disabled",
            values = ["disabled", "enabled", "preferLocal", "preferRemote", "only"],
        ),
    },
    implementation = _coco_preferences_repository_impl,
)

def _coco_deps(runtime_version, **kwargs):
    if not "bazel_skylib" in native.existing_rules():
        http_archive(
            name = "bazel_skylib",
            urls = [
                "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.2/bazel-skylib-1.0.2.tar.gz",
                "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.2/bazel-skylib-1.0.2.tar.gz",
            ],
            sha256 = "97e70364e9249702246c0e9444bccdc4b847bed1eb03c5a3ece4f83dfe6abc44",
        )

    if not "platforms" in native.existing_rules():
        http_archive(
            name = "platforms",
            urls = [
                "https://mirror.bazel.build/github.com/bazelbuild/platforms/releases/download/0.0.7/platforms-0.0.7.tar.gz",
                "https://github.com/bazelbuild/platforms/releases/download/0.0.7/platforms-0.0.7.tar.gz",
            ],
            sha256 = "3a561c99e7bdbe9173aa653fd579fe849f1d8d67395780ab4770b1f381431d51",
        )

    http_archive(
        name = "io_cocotec_coco_cc_runtime",
        urls = [
            "https://dl.cocotec.io/cp/archive/{version}/coco-cpp-runtime.zip".format(version = runtime_version),
        ],
        sha256 = FILE_KEY_TO_SHA.get("{version}/coco-cpp-runtime.zip".format(version = runtime_version)),
        build_file_content = """
cc_library(
    name = "runtime",
    hdrs = ["coco/runtime.h", "coco/stream_logger.h"],
    visibility = ["//visibility:public"],
)

cc_library(
    name = "testing",
    hdrs = ["coco/gmock_helpers.h"],
    deps = [
      ":runtime",
    ],
    visibility = ["//visibility:public"],
)
""",
    )

    _coco_preferences_repository(
        name = "io_cocotec_coco_preferences",
        **kwargs
    )

    _coco_license_repository(
        name = "io_cocotec_licensing",
    )

def coco_repositories(version = "stable", **kwargs):
    _coco_deps(
        runtime_version = version,
        **kwargs
    )

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

def coco_local_repositories(path, **kwargs):
    _coco_deps(
        runtime_version = "stable",
        **kwargs
    )
    coco_local_repository_set(
        name = "coco_local",
        path = path,
    )
