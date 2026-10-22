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

load(":known_shas.bzl", "FILE_KEY_TO_SHA")
load(":version_resolution.bzl", "version_tuple")

_CC_RUNTIME_BUILD_TEMPLATE = """
load("@rules_cc//cc:defs.bzl", "cc_library")
load("@rules_coco//coco/private:cc_runtime.bzl", "coco_cc_runtime_extra_deps")

cc_library(
    name = "runtime",
    hdrs = glob(["coco/*.h"], exclude = ["coco/gmock_helpers.h"]),
    srcs = glob(["coco/src/*.cc"], allow_empty = True) + glob(["coco/*.cc"], allow_empty = True),
    deps = [":extra_deps"],
    visibility = ["//visibility:public"],
)

# Built where unpinned targets are, however many popili versions are pinned.
coco_cc_runtime_extra_deps(
    name = "extra_deps",
    deps = {deps},
)

cc_library(
    name = "testing",
    hdrs = glob(["coco/gmock_helpers.h"], allow_empty = True),
    deps = [":runtime"],
    visibility = ["//visibility:public"],
)
"""

_C_RUNTIME_BUILD = """
load("@rules_cc//cc:defs.bzl", "cc_library")

cc_library(
    name = "runtime",
    hdrs = glob(["coco_c/*.h"]),
    srcs = glob(["coco_c/src/*.c"], allow_empty = True) + glob(["coco_c/*.c"], allow_empty = True),
    visibility = ["//visibility:public"],
)
"""

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
        parsed = version_tuple(version)
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
    parsed = version_tuple(version)
    if parsed != None and len(parsed) >= 2:
        return "archive/%s" % version
    return version

def coco_download(version, archive):
    """Returns where to download a release archive from, and its known checksum.

    Args:
      version: The resolved Coco version (aliases must already be resolved), e.g. "1.5.7".
      archive: The archive's file name within the release, e.g. "coco-cpp-runtime.zip".

    Returns:
      A struct with `url` and `sha256` fields. `sha256` is "" when no checksum is known
      for the archive, which makes the download unverified.
    """

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

def _path_separator(ctx):
    """The host's path separator; host OS, not target platform."""
    return "\\" if "windows" in ctx.os.name else "/"

def _license_directories(ctx):
    """Returns the directories popili may keep its license files in, in priority order.

    Popili's data directory is $POPILI_DATA or $COCO_PLATFORM_DATA if set, else the
    per-user one: the modern Popili (>= 1.5.0) directory first, then the legacy Coco
    Platform (< 1.5.0) one.

    Args:
        ctx: Repository context

    Returns:
        A list of directory path strings.
    """
    home = ctx.os.environ.get("HOME")
    appdata = ctx.os.environ.get("APPDATA")

    # Host OS, not target platform
    is_windows = "windows" in ctx.os.name
    is_mac = "os x" in ctx.os.name or "mac" in ctx.os.name
    sep = _path_separator(ctx)

    data = ctx.os.environ.get("POPILI_DATA") or ctx.os.environ.get("COCO_PLATFORM_DATA")
    if data:
        return [data]

    if is_mac:
        parents = [home and home + "/Library/Application Support"]
        products = ["Popili", "Coco Platform"]
    elif is_windows:
        parents = [ctx.os.environ.get("LOCALAPPDATA") or (appdata and appdata + "\\..\\Local")]
        products = ["Popili", "Coco Platform"]
    else:  # Linux/Unix
        parents = [ctx.os.environ.get("XDG_DATA_HOME") or (home and home + "/.local/share")]
        products = ["popili", "coco_platform"]

    return [
        "%s%s%s" % (parent, sep, product)
        for parent in parents
        if parent  # Unset env var would show up as "None" in the path
        for product in products
    ]

def _coco_cc_runtime_repository_impl(ctx):
    """Implementation for C++ runtime repository rule."""
    download = coco_download(ctx.attr.version, "coco-cpp-runtime.zip")
    ctx.download_and_extract(url = download.url, sha256 = download.sha256)

    ctx.file("WORKSPACE", """workspace(name = "{}")""".format(ctx.name))
    ctx.file("BUILD.bazel", _CC_RUNTIME_BUILD_TEMPLATE.format(
        deps = json.encode(ctx.attr.extra_deps),
    ))

_coco_cc_runtime_repository = repository_rule(
    implementation = _coco_cc_runtime_repository_impl,
    attrs = {
        "extra_deps": attr.string_list(
            doc = "Canonical label strings appended to the runtime's deps; typically Boost libraries for old compilers.",
            default = [],
        ),
        "version": attr.string(
            doc = "The version of coco/popili to download C++ runtime for",
            mandatory = True,
        ),
    },
)

def _coco_c_runtime_repository_impl(ctx):
    """Implementation for C runtime repository rule."""
    download = coco_download(ctx.attr.version, "coco-c-runtime.zip")
    ctx.download_and_extract(url = download.url, sha256 = download.sha256)

    ctx.file("WORKSPACE", """workspace(name = "{}")""".format(ctx.name))

    ctx.file("BUILD.bazel", _C_RUNTIME_BUILD)

_coco_c_runtime_repository = repository_rule(
    implementation = _coco_c_runtime_repository_impl,
    attrs = {
        "version": attr.string(
            doc = "The version of coco/popili to download C runtime for",
            mandatory = True,
        ),
    },
)

def _is_absolute(path):
    # Matches skylib's paths.is_absolute; inlined because this file is loaded before
    # skylib is fetched in WORKSPACE mode, so we can't load it here.
    return path.startswith("/") or (len(path) > 2 and path[1] == ":")

def resolve_local_path(ctx, path):
    """Resolves a local_toolchain path: absolute as-is, relative against the workspace root.

    ctx.path resolves a bare relative string against the generated repo, not the
    consuming workspace, so relative paths must be anchored explicitly.
    """
    if _is_absolute(path):
        return ctx.path(path)
    return ctx.path("%s/%s" % (ctx.workspace_root, path))

def _coco_cc_local_runtime_repository_impl(ctx):
    """C++ runtime repository symlinked from a local path instead of downloaded."""
    runtime_dir = resolve_local_path(ctx, ctx.attr.path).get_child("coco")
    if not runtime_dir.exists:
        fail("Local C++ runtime path '%s' does not contain a 'coco' directory" % ctx.attr.path)
    ctx.symlink(runtime_dir, "coco")

    ctx.file("WORKSPACE", """workspace(name = "{}")""".format(ctx.name))
    ctx.file("BUILD.bazel", _CC_RUNTIME_BUILD_TEMPLATE.format(
        deps = json.encode(ctx.attr.extra_deps),
    ))

_coco_cc_local_runtime_repository = repository_rule(
    implementation = _coco_cc_local_runtime_repository_impl,
    # Reevaluated on every fetch so a replaced runtime tree is picked up.
    local = True,
    attrs = {
        "extra_deps": attr.string_list(
            doc = "Canonical label strings appended to the runtime's deps; typically Boost libraries for old compilers.",
            default = [],
        ),
        "path": attr.string(
            doc = "Local filesystem path to a directory containing the C++ runtime `coco/` subtree.",
            mandatory = True,
        ),
    },
)

def _coco_c_local_runtime_repository_impl(ctx):
    """C runtime repository symlinked from a local path instead of downloaded."""
    runtime_dir = resolve_local_path(ctx, ctx.attr.path).get_child("coco_c")
    if not runtime_dir.exists:
        fail("Local C runtime path '%s' does not contain a 'coco_c' directory" % ctx.attr.path)
    ctx.symlink(runtime_dir, "coco_c")

    ctx.file("WORKSPACE", """workspace(name = "{}")""".format(ctx.name))
    ctx.file("BUILD.bazel", _C_RUNTIME_BUILD)

_coco_c_local_runtime_repository = repository_rule(
    implementation = _coco_c_local_runtime_repository_impl,
    # Reevaluated on every fetch so a replaced runtime tree is picked up.
    local = True,
    attrs = {
        "path": attr.string(
            doc = "Local filesystem path to a directory containing the C runtime `coco_c/` subtree.",
            mandatory = True,
        ),
    },
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

def _repository_list_directory(ctx, directory):
    """Lists the entries of a directory via the repository context; empty if there is none."""
    path = ctx.path(directory)
    if not path.exists or not path.is_dir:
        return []
    return [entry.basename for entry in path.readdir()]

def is_license_file_name(basename):
    """Whether a file name is a license file of some licence protocol version, `licenses_<n>.lic`.

    Args:
        basename: A file name, without its directory.

    Returns:
        True when `n` is a positive number without leading zeros.
    """
    if not basename.startswith("licenses_") or not basename.endswith(".lic"):
        return False
    protocol = basename[len("licenses_"):-len(".lic")]
    return protocol.isdigit() and not protocol.startswith("0")

def find_local_license_paths(ctx, list_directory = _repository_list_directory):
    """Finds the locally installed license files of every licence protocol version.

    Lists popili's license directories for `licenses_<n>.lic` files, whatever `n`; for each
    file name, the Popili directory takes priority over the legacy Coco Platform one.

    Args:
        ctx: Repository context, used to find the directories.
        list_directory: Callable taking (ctx, directory string) and returning the names
            of its entries, or an empty list when it does not exist. Injectable so that
            this can be unit tested.

    Returns:
        A dict from file name to path string.
    """
    sep = _path_separator(ctx)
    found = {}
    for directory in _license_directories(ctx):
        for basename in sorted(list_directory(ctx, directory)):
            if is_license_file_name(basename) and basename not in found:
                found[basename] = directory + sep + basename
    return found

def _coco_symlink_license_repository_impl(ctx):
    """Creates a repository to symlink to locally installed licenses.

    `:licenses` holds every `licenses_<n>.lic` found in popili's data directory, each
    under its own name, and is empty when there is none. The rules pick the one of
    their popili's licence protocol version (see license_versions.bzl).
    """
    ctx.file("WORKSPACE", "")
    found = find_local_license_paths(ctx)
    for basename, path_str in found.items():
        ctx.symlink(ctx.path(path_str), basename)

    ctx.file("BUILD", """
filegroup(
    name = "licenses",
    srcs = %s,
    visibility = ["//visibility:public"],
)
""" % json.encode(sorted(found.keys())))

_coco_symlink_license_repository = repository_rule(
    attrs = {},
    implementation = _coco_symlink_license_repository_impl,
    environ = ["APPDATA", "COCO_PLATFORM_DATA", "HOME", "LOCALAPPDATA", "POPILI_DATA", "XDG_DATA_HOME"],
    local = True,
)

# Public API - these are the functions/rules that should be imported
coco_c_runtime_repository = _coco_c_runtime_repository
coco_c_local_runtime_repository = _coco_c_local_runtime_repository
coco_cc_runtime_repository = _coco_cc_runtime_repository
coco_cc_local_runtime_repository = _coco_cc_local_runtime_repository
coco_preferences_repository = _coco_preferences_repository
coco_fetch_license_repository = _coco_fetch_license_repository
coco_symlink_license_repository = _coco_symlink_license_repository
