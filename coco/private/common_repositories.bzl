# Copyright 2024 Cocotec Limited
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

"""Common repository implementations shared between WORKSPACE and bzlmod."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load(":known_shas.bzl", "FILE_KEY_TO_SHA")

# Known license file version suffixes to check for
KNOWN_VERSION_SUFFIXES = [
    "_6",
    "",
]

def download_prefix(version):
    """Returns the download path prefix for a given version.

    Args:
      version: The version string to get the prefix for.

    Returns:
      The download path prefix string.
    """
    parts = version.split("-")[0].split(".")
    if len(parts) >= 2:
        return "archive/%s" % version
    return version

def version_to_repo_suffix(version):
    """Converts a version string to a valid repository name suffix.

    Examples:
        "1.5.0" -> "1_5_0"
        "1.5.0-rc.3" -> "1_5_0_rc_3"
        "stable" -> "stable"

    Args:
        version: Version string to normalize

    Returns:
        Normalized version string suitable for use in repository names
    """
    return version.replace(".", "_").replace("-", "_")

def _platform_license_file(ctx, version_suffix):
    """Get platform-specific license file path."""
    if "os x" in ctx.os.name or "mac" in ctx.os.name:
        return "%s/Library/Application Support/Coco Platform/licenses%s.lic" % (
            ctx.os.environ.get("HOME"),
            version_suffix,
        )
    if "windows" in ctx.os.name:
        return "%s\\..\\LocalLow\\Coco Platform\\licenses%s.lic" % (
            ctx.os.environ.get("APPDATA"),
            version_suffix,
        )
    return "%s/.local/share/coco_platform/licenses%s.lic" % (
        ctx.os.environ.get("HOME"),
        version_suffix,
    )

def _coco_cc_runtime_repository_impl(ctx):
    """Implementation for C++ runtime repository rule."""
    version = ctx.attr.version
    ctx.download_and_extract(
        url = "https://dl.cocotec.io/popili/{download_prefix}/coco-cpp-runtime.zip".format(
            download_prefix = download_prefix(version),
        ),
        sha256 = FILE_KEY_TO_SHA.get("{version}/coco-cpp-runtime.zip".format(version = version)),
    )

    ctx.file("WORKSPACE", """workspace(name = "{}")""".format(ctx.name))

    ctx.file("BUILD.bazel", """
load("@rules_cc//cc:defs.bzl", "cc_library")

cc_library(
    name = "runtime",
    hdrs = glob(["coco/*.h"], exclude = ["coco/gmock_helpers.h"]),
    srcs = glob(["coco/src/*.cc"], allow_empty = True) + glob(["coco/*.cc"], allow_empty = True),
    visibility = ["//visibility:public"],
)

cc_library(
    name = "testing",
    hdrs = glob(["coco/gmock_helpers.h"], allow_empty = True),
    deps = [
      ":runtime",
    ],
    visibility = ["//visibility:public"],
)
""")

_coco_cc_runtime_repository = repository_rule(
    implementation = _coco_cc_runtime_repository_impl,
    attrs = {
        "version": attr.string(
            doc = "The version of coco/popili to download C++ runtime for",
            mandatory = True,
        ),
    },
)

def _coco_cc_repositories(version):
    """Set up C++ runtime repository with version-specific name.

    This is the WORKSPACE-compatible version using http_archive.
    For bzlmod, use _coco_cc_runtime_repository directly.
    """
    version_suffix = version_to_repo_suffix(version)
    repo_name = "io_cocotec_coco_cc_runtime__%s" % version_suffix

    http_archive(
        name = repo_name,
        urls = [
            "https://dl.cocotec.io/popili/{download_prefix}/coco-cpp-runtime.zip".format(
                download_prefix = download_prefix(version),
            ),
        ],
        sha256 = FILE_KEY_TO_SHA.get("{version}/coco-cpp-runtime.zip".format(version = version)),
        build_file_content = """
load("@rules_cc//cc:defs.bzl", "cc_library")

cc_library(
    name = "runtime",
    hdrs = glob(["coco/*.h"], exclude = ["coco/gmock_helpers.h"]),
    srcs = glob(["coco/src/*.cc"]),
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

def _coco_preferences_repository_impl(ctx):
    """Creates a repository for user preferences."""
    ctx.file("preferences.toml", "")
    ctx.file("WORKSPACE", "")
    ctx.file("BUILD", """
filegroup(
    name = "preferences",
    srcs = ["preferences.toml"],
    visibility = ["//visibility:public"],
)
""")

_coco_preferences_repository = repository_rule(
    attrs = {},
    implementation = _coco_preferences_repository_impl,
)

def _coco_fetch_license_repository_impl(ctx):
    """Creates a repository to allow users to easily acquire new licenses."""
    ctx.file("WORKSPACE", "")
    auth_token = ctx.os.environ.get("COCOTEC_AUTH_TOKEN", "")
    if not auth_token:
        # Create a stub repository that will fail only if actually used
        ctx.file("BUILD", """
filegroup(
    name = "licenses",
    srcs = [],
    visibility = ["//visibility:public"],
)
""")
    else:
        ctx.file("auth_token.secret", auth_token)
        ctx.file("BUILD", """
load("@rules_coco//coco/private:licensing.bzl", "fetch_license")

# Note: This target is never actually built in practice - license acquisition
# happens outside of Bazel. This exists only for compatibility.
fetch_license(
    name = "licenses",
    product = "coco-platform",
    auth_token = "auth_token.secret",
    tags = ["manual"],
    visibility = ["//visibility:public"],
)
""")

_coco_fetch_license_repository = repository_rule(
    attrs = {},
    implementation = _coco_fetch_license_repository_impl,
    environ = ["APPDATA", "HOME", "COCOTEC_AUTH_TOKEN"],
    local = True,
)

def _coco_symlink_license_repository_impl(ctx):
    """Creates a repository to symlink to locally installed licenses."""
    ctx.file("WORKSPACE", "")
    build_content = ""
    for suffix in KNOWN_VERSION_SUFFIXES:
        file = ctx.path(_platform_license_file(ctx, suffix))
        if file.exists:
            ctx.symlink(file, file.basename)
            build_content += """
filegroup(
    name = "licenses",
    srcs = ["%s"],
    visibility = ["//visibility:public"],
)
""" % (file.basename)
            break

    if build_content == "":
        # Create a stub repository that will fail only if actually used
        build_content = """
filegroup(
    name = "licenses",
    srcs = [],
    visibility = ["//visibility:public"],
)
"""

    ctx.file("BUILD", build_content)

_coco_symlink_license_repository = repository_rule(
    attrs = {},
    implementation = _coco_symlink_license_repository_impl,
    environ = ["APPDATA", "HOME"],
    local = True,
)

# Public API - these are the functions/rules that should be imported
coco_cc_repositories = _coco_cc_repositories
coco_cc_runtime_repository = _coco_cc_runtime_repository
coco_preferences_repository = _coco_preferences_repository
coco_fetch_license_repository = _coco_fetch_license_repository
coco_symlink_license_repository = _coco_symlink_license_repository
