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

def _version_tuple(version):
    """Converts a version string to a tuple of integers for comparison.

    Args:
        version: Version string like "1.5.0" or "1.4.9-rc.1"

    Returns:
        Tuple of integers representing the version (e.g., (1, 5, 0)), or None if parsing fails
    """

    base_version = version.split("-")[0]
    result = []
    for p in base_version.split("."):
        # Check if all characters are digits
        if not p or not p.isdigit():
            return None
        result.append(int(p))

    return tuple(result) if result else None

def _determine_product_name(versions):
    """Determines the product name based on versions in use.

    Args:
        versions: List of version strings (e.g., ["1.4.0", "1.5.0"])

    Returns:
        "popili" if any version >= 1.5.0, otherwise "coco-platform"
    """
    if not versions:
        return "popili"
    for version in versions:
        parsed = _version_tuple(version)
        if parsed == None or parsed >= (1, 5, 0):
            return "popili"
    return "coco-platform"

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

def _get_all_license_paths(ctx, version_suffix):
    """Returns all possible license file paths in priority order.

    Checks both modern (Popili, >= 1.5.0) and legacy (Coco Platform, < 1.5.0) paths.
    Returns paths in priority order: Popili first, then Coco Platform.

    Args:
        ctx: Repository context
        version_suffix: Version suffix for the license file (e.g., "_6" or "")

    Returns:
        List of possible license file paths to check
    """
    home = ctx.os.environ.get("HOME")
    appdata = ctx.os.environ.get("APPDATA")

    paths = []

    if "os x" in ctx.os.name or "mac" in ctx.os.name:
        # Try Popili path first (>= 1.5.0)
        paths.append("%s/Library/Application Support/Popili/licenses%s.lic" % (home, version_suffix))

        # Fall back to Coco Platform path (< 1.5.0)
        paths.append("%s/Library/Application Support/Coco Platform/licenses%s.lic" % (home, version_suffix))
    elif "windows" in ctx.os.name:
        # Try Popili path first (>= 1.5.0)
        paths.append("%s\\..\\LocalLow\\Popili\\licenses%s.lic" % (appdata, version_suffix))

        # Fall back to Coco Platform path (< 1.5.0)
        paths.append("%s\\..\\LocalLow\\Coco Platform\\licenses%s.lic" % (appdata, version_suffix))
    else:  # Linux/Unix
        # Try popili path first (>= 1.5.0)
        paths.append("%s/.local/share/popili/licenses%s.lic" % (home, version_suffix))

        # Fall back to coco_platform path (< 1.5.0)
        paths.append("%s/.local/share/coco_platform/licenses%s.lic" % (home, version_suffix))

    return paths

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

def _coco_c_runtime_repository_impl(ctx):
    """Implementation for C runtime repository rule."""
    version = ctx.attr.version
    ctx.download_and_extract(
        url = "https://dl.cocotec.io/popili/{download_prefix}/coco-c-runtime.zip".format(
            download_prefix = download_prefix(version),
        ),
        sha256 = FILE_KEY_TO_SHA.get("{version}/coco-c-runtime.zip".format(version = version)),
    )

    ctx.file("WORKSPACE", """workspace(name = "{}")""".format(ctx.name))

    ctx.file("BUILD.bazel", """
load("@rules_cc//cc:defs.bzl", "cc_library")

cc_library(
    name = "runtime",
    hdrs = glob(["coco_c/*.h"]),
    srcs = glob(["coco_c/src/*.c"], allow_empty = True) + glob(["coco_c/*.c"], allow_empty = True),
    visibility = ["//visibility:public"],
)
""")

_coco_c_runtime_repository = repository_rule(
    implementation = _coco_c_runtime_repository_impl,
    attrs = {
        "version": attr.string(
            doc = "The version of coco/popili to download C runtime for",
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
    """Creates a repository to allow users to easily acquire new licenses.

    Determines the correct product name based on versions in use:
    - Versions < 1.5.0 use "coco-platform"
    - Versions >= 1.5.0 use "popili"
    """
    ctx.file("WORKSPACE", "")
    auth_token = ctx.os.environ.get("COCOTEC_AUTH_TOKEN", "")

    # Determine product name based on versions
    versions = ctx.attr.versions
    product_name = _determine_product_name(versions)

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
    product = "%s",
    auth_token = "auth_token.secret",
    tags = ["manual"],
    visibility = ["//visibility:public"],
)
""" % product_name)

_coco_fetch_license_repository = repository_rule(
    attrs = {
        "versions": attr.string_list(
            doc = "List of Popili/Coco versions in use. Used to determine correct product name (coco-platform vs popili).",
            default = [],
        ),
    },
    implementation = _coco_fetch_license_repository_impl,
    environ = ["APPDATA", "HOME", "COCOTEC_AUTH_TOKEN"],
    local = True,
)

def _coco_symlink_license_repository_impl(ctx):
    """Creates a repository to symlink to locally installed licenses.

    Checks both modern (Popili, >= 1.5.0) and legacy (Coco Platform, < 1.5.0)
    license file locations. Prioritizes Popili paths but falls back to legacy paths
    for backward compatibility.
    """
    ctx.file("WORKSPACE", "")
    build_content = None

    for suffix in KNOWN_VERSION_SUFFIXES:
        if build_content == None:
            break

        # Try each path until we find one that exists
        for path_str in _get_all_license_paths(ctx, suffix):
            file = ctx.path(path_str)
            if file.exists:
                ctx.symlink(file, file.basename)
                build_content = """
filegroup(
    name = "licenses",
    srcs = ["%s"],
    visibility = ["//visibility:public"],
)
""" % (file.basename)
                break

    if build_content == None:
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
coco_c_runtime_repository = _coco_c_runtime_repository
coco_cc_repositories = _coco_cc_repositories
coco_cc_runtime_repository = _coco_cc_runtime_repository
coco_preferences_repository = _coco_preferences_repository
coco_fetch_license_repository = _coco_fetch_license_repository
coco_symlink_license_repository = _coco_symlink_license_repository
