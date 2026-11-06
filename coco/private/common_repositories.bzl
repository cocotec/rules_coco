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
load(":platforms.bzl", "host_toolchain_platform")
load(":version_resolution.bzl", "stable_versions", "version_tuple")

# Every stable popili version (1.5.0 onwards, no betas or release candidates) this
# rules_coco knows the downloads of, newest first.
AVAILABLE_STABLE_VERSIONS = stable_versions(FILE_KEY_TO_SHA.keys())

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

def auth_token_source(environ):
    """Where `local_acquire` takes the machine auth token from.

    A non-empty `COCOTEC_AUTH_TOKEN_FILE` wins over `COCOTEC_AUTH_TOKEN`. Only the file's path is
    used: the file is never read, so its contents do not affect the build. The path must be
    absolute: the licensing server runs in a repository's directory, where a relative path would
    not resolve against where it was set.

    Args:
        environ: The repository environment, a dict from variable name to value.

    Returns:
        `struct(file = path)`, `struct(value = token)`, `struct(error = message)` for a path that
        is not absolute, or None when neither variable is set.
    """
    path = environ.get("COCOTEC_AUTH_TOKEN_FILE", "")
    if path:
        if not _is_absolute(path):
            return struct(error = "COCOTEC_AUTH_TOKEN_FILE must be an absolute path, not %r" % path)
        return struct(file = path)
    token = environ.get("COCOTEC_AUTH_TOKEN", "")
    if token:
        return struct(value = token)
    return None

_BUILD_FOR_LICENSE_PATHS = """
load("@rules_coco//coco/private:license_paths.bzl", "license_paths")

license_paths(
    name = "licenses",
    error = {error},
    error_path = {error_path},
    paths = {paths},
    visibility = ["//visibility:public"],
)
"""

def _licensing_server(ctx):
    """The host's cocotec-licensing-server for the repository's protocol version, or (None, error)."""
    if ctx.attr.local_popili:
        # Already on disk, unlike a registered version's, which would be downloaded for it.
        dist_dir = resolve_local_path(ctx, ctx.attr.local_popili)
        for binary in ["cocotec-licensing-server", "cocotec-licensing-server.exe"]:
            if dist_dir.get_child(binary).exists:
                return dist_dir.get_child(binary), None
    platform = host_toolchain_platform(ctx.os.name, ctx.os.arch)
    if platform:
        label = ctx.attr.licensing_servers.get("%s_%s" % platform)
        if label:
            return ctx.path(label), None
    if not platform:
        return None, "popili is not published for this machine (%s, %s)" % (ctx.os.name, ctx.os.arch)
    return None, "no registered popili reads licence protocol version %d" % ctx.attr.protocol_version

# The control characters, below 0x20 and DEL: json.encode writes most as `\u00XX`, an escape
# Starlark rejects, so a BUILD file holding one would not load.
_CONTROL_CHARACTERS = "".join([
    "\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017",
    "\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037\177",
])

def one_line(text, limit = 500):
    """`text` as one line for a generated BUILD file: control characters become spaces, runs of spaces one.

    Args:
        text: Any string, such as a program's output.
        limit: The length past which the line is cut, ending in "...".

    Returns:
        The line, at most `limit` characters plus "...".
    """
    text = "".join([" " if c in _CONTROL_CHARACTERS else c for c in text[:4 * limit].elems()])
    text = " ".join([word for word in text.split(" ") if word])
    return text[:limit] + "..." if len(text) > limit else text

def _acquire_license(ctx, source, path):
    """Runs the host's cocotec-licensing-server to acquire a licence into `path`.

    Returns:
        (error, retryable): None when acquired, else why not and whether trying again may help.
    """
    server, error = _licensing_server(ctx)
    if error:
        return error, False
    if hasattr(source, "file"):
        token = source.file
    else:
        ctx.file("auth_token.secret", source.value)
        token = str(ctx.path("auth_token.secret"))
    result = ctx.execute([
        server,
        "--no-crash-reporter",
        "--machine-auth-token",
        token,
        "--license-file",
        str(path),
        "--acquire",
        "popili",
    ], timeout = 300)
    if not hasattr(source, "file"):
        ctx.delete("auth_token.secret")
    if result.return_code == 0 and path.exists:
        return None, False
    output = one_line(result.stderr + " " + result.stdout) or "no output"
    return "cocotec-licensing-server exited with code %d: %s" % (result.return_code, output), True

def _coco_fetch_license_repository_impl(ctx):
    """Acquires the licence of one licence protocol version for `local_acquire`, at fetch time.

    `:licenses` gives its absolute path, so the licence's contents never become an action input:
    every acquisition writes a new file, which would otherwise give every popili action a new key.
    Acquisition never fails the fetch, which would fail builds that are all cache hits, and the path
    is the same whether it succeeds or not, so those cache hits survive a failure too. Without a
    licence the file is missing and `:licenses` carries the reason, which the rules show when popili
    runs: in an action's progress message, or read from `licenses_<n>.error` by a test as it runs.
    """
    ctx.file("WORKSPACE", "")
    source = auth_token_source(ctx.os.environ)

    file_name = "licenses_%d.lic" % ctx.attr.protocol_version
    path = ctx.path(file_name)

    # Bazel refetches into an empty directory; this makes sure no earlier licence outlives a failure.
    ctx.delete(path)
    if hasattr(source, "error"):
        error, retryable = source.error, False
    elif not source:
        error, retryable = "neither COCOTEC_AUTH_TOKEN_FILE nor COCOTEC_AUTH_TOKEN is set in the repository environment (see --repo_env)", False
    else:
        error, retryable = _acquire_license(ctx, source, path)
    if error:
        ctx.delete(path)
        error = "local_acquire acquired no licence for licence protocol version %d: %s." % (ctx.attr.protocol_version, error)
        if retryable:
            error += " Bazel tries again when its server restarts (bazel shutdown)."

    # Tests read the error from this file as they run; it has the same path whether it is empty or not.
    error_path = ctx.path("licenses_%d.error" % ctx.attr.protocol_version)
    ctx.file(error_path, error + "\n" if error else "", executable = False)

    ctx.file("BUILD", _BUILD_FOR_LICENSE_PATHS.format(
        error = json.encode(error or ""),
        error_path = json.encode(str(error_path)),
        paths = json.encode({file_name: str(path)}),
    ))

_coco_fetch_license_repository = repository_rule(
    implementation = _coco_fetch_license_repository_impl,
    attrs = {
        "licensing_servers": attr.string_keyed_label_dict(
            doc = (
                "`<os>_<arch>` to the cocotec-licensing-server of the newest registered popili of the " +
                "protocol version on that platform. Only the host's is fetched."
            ),
        ),
        "local_popili": attr.string(
            doc = "The local popili distribution's directory, when it reads this protocol version. Its server is preferred: it needs no download.",
        ),
        "protocol_version": attr.int(mandatory = True),
    },
    # Only the variables' values: the token file is never read here, so its contents do not affect the build.
    environ = ["COCOTEC_AUTH_TOKEN", "COCOTEC_AUTH_TOKEN_FILE"],
    # Acquires again once per Bazel server.
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

def _coco_local_licenses_repository_impl(ctx):
    """Creates a repository naming the locally installed licenses.

    `:licenses` gives the absolute path of every `licenses_<n>.lic` found in popili's data
    directory, and is empty when there is none. The rules pick the one of their popili's licence
    protocol version (see license_versions.bzl) and pass its path to popili; the files are not
    linked into the repository, so their contents never become action inputs.
    """
    ctx.file("WORKSPACE", "")
    paths = {
        basename: str(ctx.path(path_str))
        for basename, path_str in find_local_license_paths(ctx).items()
    }

    ctx.file("BUILD", _BUILD_FOR_LICENSE_PATHS.format(error = json.encode(""), error_path = json.encode(""), paths = json.encode(paths)))

_coco_local_licenses_repository = repository_rule(
    attrs = {},
    implementation = _coco_local_licenses_repository_impl,
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
coco_local_licenses_repository = _coco_local_licenses_repository
