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
load(":platforms.bzl", "host_platform")
load(":version_resolution.bzl", "version_tuple")

_CC_RUNTIME_BUILD_TEMPLATE = """
load("@rules_cc//cc:defs.bzl", "cc_library")

cc_library(
    name = "runtime",
    hdrs = glob(["coco/*.h"], exclude = ["coco/gmock_helpers.h"]),
    srcs = glob(["coco/src/*.cc"], allow_empty = True) + glob(["coco/*.cc"], allow_empty = True),
    deps = {deps},
    visibility = ["//visibility:public"],
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

def toolchain_repo_name(os, arch, version_suffix):
    """Returns the name of the repository holding one platform's popili distribution.

    Args:
      os: The toolchain OS ("osx", "linux" or "windows").
      arch: The toolchain CPU ("aarch64" or "x86_64").
      version_suffix: The mangled version, as returned by `version_to_repo_suffix`.

    Returns:
      The repository name.
    """
    return "io_cocotec_coco_%s_%s__%s" % (os, arch, version_suffix)

def _license_data_directories(ctx):
    """Returns popili's candidate data directories on the host, in the order popili uses them.

    Mirrors popili's own lookup: the POPILI_DATA or COCO_PLATFORM_DATA override, else the
    per-user data directory. There, popili uses a "Popili" directory and falls back to the
    "Coco Platform" one of earlier releases, so both are probed in that order.

    On Windows the per-user data directory is %LOCALAPPDATA% (FOLDERID_LocalAppData). The
    LocalLow directory next to it, which earlier rules_coco releases probed, is kept as a
    fallback: no test covers Windows local_user, so a licence that only exists there keeps
    working.

    Args:
      ctx: A repository context.

    Returns:
      A list of directory paths. Empty when the variables it needs are unset.
    """
    environ = ctx.os.environ
    for override in ["POPILI_DATA", "COCO_PLATFORM_DATA"]:
        if environ.get(override):
            return [environ[override]]

    name = ctx.os.name.lower()
    if "windows" in name:
        appdata = environ.get("APPDATA")
        parents = [environ.get("LOCALAPPDATA") or (appdata + "\\..\\Local" if appdata else None)]
        if appdata:
            parents.append(appdata + "\\..\\LocalLow")
        return [
            parent + "\\" + product
            for parent in parents
            if parent
            for product in ["Popili", "Coco Platform"]
        ]

    home = environ.get("HOME")
    if "mac" in name or "os x" in name:
        if not home:
            return []
        parent = home + "/Library/Application Support"
        return [parent + "/Popili", parent + "/Coco Platform"]

    parent = environ.get("XDG_DATA_HOME")
    if not parent:
        if not home:
            return []
        parent = home + "/.local/share"
    return [parent + "/popili", parent + "/coco_platform"]

def local_license_paths(ctx, lv):
    """Returns where popili may keep the local user's licence of a licence version.

    Args:
      ctx: A repository context.
      lv: The licence version, e.g. 6.

    Returns:
      Candidate file paths, in priority order.
    """
    separator = "\\" if "windows" in ctx.os.name.lower() else "/"
    return ["%s%slicenses_%d.lic" % (directory, separator, lv) for directory in _license_data_directories(ctx)]

def _repository_path_exists(ctx, path_str):
    """Checks whether a path exists on disk, via the repository context."""
    return ctx.path(path_str).exists

def find_local_license(ctx, lv, path_exists = _repository_path_exists):
    """Finds the local user's licence of a licence version, if there is one.

    Args:
      ctx: A repository context.
      lv: The licence version, e.g. 6.
      path_exists: Callable taking (ctx, path string) and returning whether that path exists.
        Injectable so that this can be unit tested.

    Returns:
      The path of the first candidate that exists, or None.
    """
    for path_str in local_license_paths(ctx, lv):
        if path_exists(ctx, path_str):
            return path_str
    return None

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
    version = ctx.attr.version
    ctx.download_and_extract(
        url = "https://dl.cocotec.io/popili/{download_prefix}/coco-c-runtime.zip".format(
            download_prefix = download_prefix(version),
        ),
        sha256 = FILE_KEY_TO_SHA.get("{version}/coco-c-runtime.zip".format(version = version)),
    )

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

def _empty_filegroup(name):
    return """
filegroup(
    name = "{name}",
    srcs = [],
    visibility = ["//visibility:public"],
)
""".format(name = name)

def render_fetch_license_build(representatives, has_local, host, has_token):
    """Renders the BUILD file of the licence fetch repository.

    Args:
      representatives: Dict from licence version (int) to the mangled suffix of the popili
        version whose licensing server acquires it.
      has_local: Whether a local toolchain is registered. It acquires its own licence.
      host: The host as an (os, arch) pair, as returned by `host_platform`, or None.
      has_token: Whether COCOTEC_AUTH_TOKEN is set. Without it nothing can be acquired, so
        every target is an empty filegroup.

    Returns:
      The BUILD file content.
    """
    names = ["licenses_%d" % lv for lv in sorted(representatives)]
    if has_local:
        names.append("licenses_local")
    if not has_token:
        return "".join([_empty_filegroup(name) for name in ["licenses"] + names])

    # Without a host (popili isn't published for it) only a local toolchain can acquire, and
    # its target is then left unconstrained: nothing else can run on that host anyway.
    exec_compatible_with = []
    if host:
        exec_compatible_with = ["@platforms//os:%s" % host[0], "@platforms//cpu:%s" % host[1]]

    content = """load("@rules_coco//coco/private:licensing.bzl", "fetch_license")

# For toolchains registered outside rules_coco: acquired with whichever Coco toolchain the
# consuming rule resolves. The acquisition runs on this machine (fetch_license tags it
# no-remote-exec), so its execution platform, and with it the licensing server, is the host's.
fetch_license(
    name = "licenses",
    auth_token = "auth_token.secret",
    exec_compatible_with = {exec_compatible_with},
    tags = ["manual"],
    visibility = ["//visibility:public"],
)
""".format(exec_compatible_with = repr(exec_compatible_with))
    servers = {}
    if host:
        for lv, suffix in representatives.items():
            servers["licenses_%d" % lv] = "@%s//:cocotec_licensing_server" % toolchain_repo_name(host[0], host[1], suffix)
    if has_local:
        servers["licenses_local"] = "@io_cocotec_coco_local//:cocotec_licensing_server"

    for name in names:
        if name not in servers:
            # popili isn't published for the host, so there is no licensing server to use.
            content += _empty_filegroup(name)
            continue
        content += """
fetch_license(
    name = "{name}",
    auth_token = "auth_token.secret",
    exec_compatible_with = {exec_compatible_with},
    licensing_server = "{server}",
    tags = ["manual"],
    visibility = ["//visibility:public"],
)
""".format(name = name, exec_compatible_with = repr(exec_compatible_with), server = servers[name])
    return content

def _coco_fetch_license_repository_impl(ctx):
    """Creates the repository that acquires licences with COCOTEC_AUTH_TOKEN (local_acquire).

    There is one target per licence version, acquired with the host's licensing server of that
    licence version's representative, plus one for a local toolchain, acquired with its own.
    Every toolchain of a licence version depends on the same target, so each licence is
    acquired at most once per build.
    """
    ctx.file("WORKSPACE", "")
    auth_token = ctx.os.environ.get("COCOTEC_AUTH_TOKEN", "")
    if auth_token:
        ctx.file("auth_token.secret", auth_token)
    ctx.file("BUILD", render_fetch_license_build(
        representatives = {int(lv): suffix for lv, suffix in ctx.attr.representatives.items()},
        has_local = ctx.attr.has_local,
        host = host_platform(ctx),
        has_token = bool(auth_token),
    ))

_coco_fetch_license_repository = repository_rule(
    attrs = {
        "has_local": attr.bool(
            doc = "Whether a local toolchain is registered.",
        ),
        "representatives": attr.string_dict(
            doc = "Map of licence version to the mangled suffix of the popili version that acquires it.",
        ),
    },
    implementation = _coco_fetch_license_repository_impl,
    environ = ["COCOTEC_AUTH_TOKEN"],
    local = True,
)

def render_local_license_build(found):
    """Renders the BUILD file of the local licence repository.

    Args:
      found: Dict from licence version (int) to the file name of its licence in the
        repository, or None when the user has none.

    Returns:
      The BUILD file content.
    """
    content = ""
    for lv in sorted(found):
        if found[lv] == None:
            content += _empty_filegroup("licenses_%d" % lv)
        else:
            content += """
filegroup(
    name = "licenses_{lv}",
    srcs = ["{file}"],
    visibility = ["//visibility:public"],
)
""".format(lv = lv, file = found[lv])

    # For toolchains registered outside rules_coco, whose licence version isn't known: the
    # newest licence the user has.
    available = [lv for lv in found if found[lv] != None]
    if available:
        content += """
alias(
    name = "licenses",
    actual = ":licenses_{lv}",
    visibility = ["//visibility:public"],
)
""".format(lv = max(available))
    else:
        content += _empty_filegroup("licenses")
    return content

def _coco_symlink_license_repository_impl(ctx):
    """Creates the repository exposing the local user's licences (local_user).

    There is one target per licence version in use, each the licence popili itself would
    read for that version. Fetched by every build, so it depends on no toolchain repository.
    """
    ctx.file("WORKSPACE", "")

    found = {}
    for lv in [int(lv) for lv in ctx.attr.license_versions]:
        path = find_local_license(ctx, lv)
        if path == None:
            found[lv] = None
            continue
        name = "licenses_%d.lic" % lv
        ctx.symlink(ctx.path(path), name)
        found[lv] = name

    ctx.file("BUILD", render_local_license_build(found))

_coco_symlink_license_repository = repository_rule(
    attrs = {
        "license_versions": attr.string_list(
            doc = "The licence versions to provide: those of the registered popili versions, " +
                  "plus every known one when a local toolchain is registered.",
        ),
    },
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
