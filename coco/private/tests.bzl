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

"""Unit tests for coco.bzl functions."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "//testdata:name_mangling_corpus.bzl",
    "CORPUS_STYLES",
    "MANGLE_CASES",
    "PATH_CASES",
    "PATH_CASE_DEFAULTS",
)
load(":cc_runtime_deps.bzl", "collect_cc_runtime_extra_deps", "normalize_cc_runtime_extra_deps")
load(":coco.bzl", "FILE_NAME_MANGLER_STYLES", "compute_output_paths", "mangle_name", "module_path_for", "package_relative_dir")
load(":common_repositories.bzl", "download_prefix", "find_local_license_path")
load(":known_shas.bzl", "FILE_KEY_TO_SHA")
load(":platforms.bzl", "COCO_TOOLCHAIN_PLATFORMS", "archive_platform", "platform_binary_ext")
load(
    ":toolchain_hub.bzl",
    "merge_toolchain_tags",
    "render_toolchain_hub_build",
    "resolve_versions",
    "toolchain_hub_entries",
)
load(":toolchain_repositories.bzl", "coco_toolchain_download")
load(":version_aliases.bzl", "VERSION_ALIASES")
load(":version_resolution.bzl", "resolve_version_alias", "version_tuple")

# Tests for collect_cc_runtime_extra_deps

def _entry(module_name, is_root, version, deps):
    return struct(
        module_name = module_name,
        is_root = is_root,
        version = version,
        deps = deps,
    )

def _fake_resolve(v):
    if v == "stable":
        return "1.5.1"
    return v

def _cc_runtime_deps_root_single_version_test(ctx):
    env = unittest.begin(ctx)

    # buildifier: disable=canonical-repository
    result, err = collect_cc_runtime_extra_deps(
        [_entry("root", True, "1.5.1", ["@@boost+//:optional", "@@boost+//:shared_ptr"])],
        {"1.5.1": True},
        _fake_resolve,
    )

    asserts.equals(env, None, err)

    # buildifier: disable=canonical-repository
    asserts.equals(env, {"1.5.1": ["@@boost+//:optional", "@@boost+//:shared_ptr"]}, result)

    return unittest.end(env)

def _cc_runtime_deps_root_alias_collapses_to_resolved_version_test(ctx):
    env = unittest.begin(ctx)

    # buildifier: disable=canonical-repository
    result, err = collect_cc_runtime_extra_deps(
        [_entry("root", True, "stable", ["@@boost+//:optional"])],
        {"1.5.1": True},
        _fake_resolve,
    )

    asserts.equals(env, None, err)

    # buildifier: disable=canonical-repository
    asserts.equals(env, {"1.5.1": ["@@boost+//:optional"]}, result)

    return unittest.end(env)

def _cc_runtime_deps_local_version_test(ctx):
    """The "local" version targets the coco.local_toolchain runtime once registered."""
    env = unittest.begin(ctx)

    # buildifier: disable=canonical-repository
    result, err = collect_cc_runtime_extra_deps(
        [_entry("root", True, "local", ["@@boost+//:optional"])],
        {"1.5.1": True, "local": True},
        _fake_resolve,
    )

    asserts.equals(env, None, err)

    # buildifier: disable=canonical-repository
    asserts.equals(env, {"local": ["@@boost+//:optional"]}, result)

    return unittest.end(env)

def _cc_runtime_deps_root_dedups_across_tags_test(ctx):
    env = unittest.begin(ctx)

    # buildifier: disable=canonical-repository
    result, err = collect_cc_runtime_extra_deps(
        [
            _entry("root", True, "1.5.1", ["@@boost+//:optional"]),
            _entry("root", True, "1.5.1", ["@@boost+//:optional", "@@boost+//:shared_ptr"]),
            _entry("root", True, "stable", ["@@boost+//:shared_ptr"]),
        ],
        {"1.5.1": True},
        _fake_resolve,
    )

    asserts.equals(env, None, err)

    # buildifier: disable=canonical-repository
    asserts.equals(env, {"1.5.1": ["@@boost+//:optional", "@@boost+//:shared_ptr"]}, result)

    return unittest.end(env)

def _cc_runtime_deps_non_root_rejected_test(ctx):
    env = unittest.begin(ctx)

    # buildifier: disable=canonical-repository
    result, err = collect_cc_runtime_extra_deps(
        [_entry("some_transitive_dep", False, "1.5.1", ["@@boost+//:optional"])],
        {"1.5.1": True},
        _fake_resolve,
    )

    asserts.equals(env, {}, result)
    asserts.true(env, err != None, "expected an error message, got None")
    asserts.true(env, "some_transitive_dep" in err, "error should name the offending module: %s" % err)
    asserts.true(env, "root module" in err, "error should explain the root-only rule: %s" % err)

    return unittest.end(env)

def _cc_runtime_deps_non_root_rejected_even_when_root_also_present_test(ctx):
    env = unittest.begin(ctx)

    # buildifier: disable=canonical-repository
    result, err = collect_cc_runtime_extra_deps(
        [
            _entry("root", True, "1.5.1", ["@@boost+//:optional"]),
            _entry("some_transitive_dep", False, "1.5.1", ["@@boost+//:optional"]),
        ],
        {"1.5.1": True},
        _fake_resolve,
    )

    asserts.equals(env, {}, result)
    asserts.true(env, err != None, "expected an error even when root also provided the dep")
    asserts.true(env, "some_transitive_dep" in err, "error should name the offending module: %s" % err)

    return unittest.end(env)

def _cc_runtime_deps_unknown_version_test(ctx):
    env = unittest.begin(ctx)

    # buildifier: disable=canonical-repository
    result, err = collect_cc_runtime_extra_deps(
        [_entry("root", True, "9.9.9", ["@@boost+//:optional"])],
        {"1.5.1": True},
        _fake_resolve,
    )

    asserts.equals(env, {}, result)
    asserts.true(env, err != None, "expected an error for unknown version")
    asserts.true(env, "9.9.9" in err, "error should name the bad version: %s" % err)

    return unittest.end(env)

cc_runtime_deps_root_single_version_test = unittest.make(_cc_runtime_deps_root_single_version_test)
cc_runtime_deps_root_alias_collapses_to_resolved_version_test = unittest.make(_cc_runtime_deps_root_alias_collapses_to_resolved_version_test)
cc_runtime_deps_root_dedups_across_tags_test = unittest.make(_cc_runtime_deps_root_dedups_across_tags_test)
cc_runtime_deps_local_version_test = unittest.make(_cc_runtime_deps_local_version_test)
cc_runtime_deps_non_root_rejected_test = unittest.make(_cc_runtime_deps_non_root_rejected_test)
cc_runtime_deps_non_root_rejected_even_when_root_also_present_test = unittest.make(_cc_runtime_deps_non_root_rejected_even_when_root_also_present_test)
cc_runtime_deps_unknown_version_test = unittest.make(_cc_runtime_deps_unknown_version_test)

# Corpus-driven tests for name mangling
#
# The expected values live in //testdata:name_mangling_corpus.bzl, which popili
# loads too: it depends on rules_coco as a Bazel module and asserts against the
# same cases. One shared file, loaded by both, is what stops the two
# implementations drifting.
#
# Cases are not written inline here on purpose: an expectation that lives only
# in this repo is exactly how the divergences these tests were written for went
# unnoticed.

def _mangle_corpus_test_impl(ctx):
    env = unittest.begin(ctx)

    style = ctx.attr.style
    for case in MANGLE_CASES:
        if case["style"] != style:
            continue
        asserts.equals(
            env,
            case["expected"],
            mangle_name(case["input"], style),
            "corpus: mangle_name(%r, %r)" % (case["input"], style),
        )

    return unittest.end(env)

mangle_corpus_test = unittest.make(
    _mangle_corpus_test_impl,
    attrs = {"style": attr.string(mandatory = True)},
)

def _path_corpus_test_impl(ctx):
    env = unittest.begin(ctx)

    for case in PATH_CASES:
        # A case carries only the fields that differ from PATH_CASE_DEFAULTS,
        # so most rows are just a module path, a style and the expectation.
        config = struct(
            file_name_mangler = case["style"],
            header_prefix = case.get("header_prefix", PATH_CASE_DEFAULTS["header_prefix"]),
            header_extension = case.get("header_extension", PATH_CASE_DEFAULTS["header_extension"]),
            impl_prefix = case.get("impl_prefix", PATH_CASE_DEFAULTS["impl_prefix"]),
            impl_extension = case.get("impl_extension", PATH_CASE_DEFAULTS["impl_extension"]),
            mocks = case.get("mocks", PATH_CASE_DEFAULTS["mocks"]),
            flat_hierarchy = case.get("flat_hierarchy", PATH_CASE_DEFAULTS["flat_hierarchy"]),
        )
        result = compute_output_paths(case["module_path"], config)
        expected = case["expected"]
        label = "corpus: %s under %s" % ("/".join(case["module_path"]), case["style"])

        asserts.equals(env, expected["header"], result.header, label + " (header)")
        asserts.equals(env, expected["impl"], result.impl, label + " (impl)")
        asserts.equals(env, expected.get("mock_header"), result.mock_header, label + " (mock header)")
        asserts.equals(env, expected.get("mock_impl"), result.mock_impl, label + " (mock impl)")

    return unittest.end(env)

path_corpus_test = unittest.make(_path_corpus_test_impl)

def _corpus_styles_test_impl(ctx):
    """Guards the corpus contract itself rather than any single case."""
    env = unittest.begin(ctx)

    # Fails in both directions: a style popili adds is unaccounted for until
    # someone implements it, and a style popili removes leaves a stale
    # implementation behind.
    asserts.equals(
        env,
        sorted(CORPUS_STYLES),
        sorted(FILE_NAME_MANGLER_STYLES),
        "the corpus and mangle_name disagree about which styles exist",
    )

    # Every style must actually be exercised by at least one case, so that a
    # style cannot be "covered" by an empty loop.
    styles_in_corpus = {case["style"]: True for case in MANGLE_CASES}
    for style in CORPUS_STYLES:
        asserts.true(
            env,
            style in styles_in_corpus,
            "no corpus case exercises style %s" % style,
        )

    return unittest.end(env)

corpus_styles_test = unittest.make(_corpus_styles_test_impl)

# Tests for the source-path plumbing that feeds the corpus path cases.
# These cover rules_coco-only concepts that popili has no equivalent for, so
# they cannot live in the shared corpus.

def _module_path_for_test_impl(ctx):
    env = unittest.begin(ctx)

    # A source directly in the source root.
    asserts.equals(
        env,
        ["ExampleName"],
        module_path_for(struct(path = "pkg/src/ExampleName.coco"), "pkg", "src"),
    )

    # A source in a subdirectory: the subdirectory is part of the module path,
    # which is why it gets mangled too.
    asserts.equals(
        env,
        ["Geometry", "Dims"],
        module_path_for(struct(path = "pkg/src/Geometry/Dims.coco"), "pkg", "src"),
    )

    # No source root, i.e. sources sit directly beside Coco.toml.
    asserts.equals(
        env,
        ["Runnable"],
        module_path_for(struct(path = "pkg/Runnable.coco"), "pkg", ""),
    )

    return unittest.end(env)

def _package_relative_dir_test_impl(ctx):
    env = unittest.begin(ctx)

    # Coco.toml beside the BUILD file: paths.relativize would return the path
    # unchanged here, so this is the case the helper exists for.
    asserts.equals(env, "", package_relative_dir("test/pkg", "test/pkg"))

    # Coco.toml in a subdirectory of the BUILD file's package.
    asserts.equals(env, "app", package_relative_dir("test/pkg/app", "test/pkg"))

    # BUILD file at the repository root.
    asserts.equals(env, "test/pkg", package_relative_dir("test/pkg", ""))

    return unittest.end(env)

module_path_for_test = unittest.make(_module_path_for_test_impl)
package_relative_dir_test = unittest.make(_package_relative_dir_test_impl)

# Tests for find_local_license_path

_LINUX_HOME = "/home/dev"
_MAC_HOME = "/Users/dev"
_WINDOWS_APPDATA = "C:\\Users\\dev\\AppData\\Roaming"

def _fake_repository_ctx(os_name, existing, home = _LINUX_HOME, appdata = _WINDOWS_APPDATA):
    """Builds a stand-in for a repository ctx that only knows about `existing` paths.

    Passing None for `home` or `appdata` leaves that variable out of the
    environment entirely, modelling an unset variable rather than an empty one.
    """
    environ = {}
    if appdata != None:
        environ["APPDATA"] = appdata
    if home != None:
        environ["HOME"] = home

    return struct(
        os = struct(
            name = os_name,
            environ = environ,
        ),
        existing = existing,
    )

def _fake_path_exists(ctx, path_str):
    return path_str in ctx.existing

def _local_license_suffixed_linux_test(ctx):
    """The default local_user case: a suffixed Popili license under $HOME is found."""
    env = unittest.begin(ctx)

    license = "%s/.local/share/popili/licenses_6.lic" % _LINUX_HOME
    fake = _fake_repository_ctx("linux", [license])

    asserts.equals(env, license, find_local_license_path(fake, _fake_path_exists))

    return unittest.end(env)

def _local_license_suffixed_mac_test(ctx):
    env = unittest.begin(ctx)

    license = "%s/Library/Application Support/Popili/licenses_6.lic" % _MAC_HOME
    fake = _fake_repository_ctx("mac os x", [license], home = _MAC_HOME)

    asserts.equals(env, license, find_local_license_path(fake, _fake_path_exists))

    return unittest.end(env)

def _local_license_suffixed_windows_test(ctx):
    env = unittest.begin(ctx)

    license = "%s\\..\\LocalLow\\Popili\\licenses_6.lic" % _WINDOWS_APPDATA
    fake = _fake_repository_ctx("windows 10", [license])

    asserts.equals(env, license, find_local_license_path(fake, _fake_path_exists))

    return unittest.end(env)

def _local_license_unsuffixed_test(ctx):
    """A license with no version suffix is found once the suffixed candidates miss."""
    env = unittest.begin(ctx)

    license = "%s/.local/share/popili/licenses.lic" % _LINUX_HOME
    fake = _fake_repository_ctx("linux", [license])

    asserts.equals(env, license, find_local_license_path(fake, _fake_path_exists))

    return unittest.end(env)

def _local_license_legacy_fallback_test(ctx):
    """With no Popili license installed, the legacy Coco Platform path is used."""
    env = unittest.begin(ctx)

    license = "%s/.local/share/coco_platform/licenses_6.lic" % _LINUX_HOME
    fake = _fake_repository_ctx("linux", [license])

    asserts.equals(env, license, find_local_license_path(fake, _fake_path_exists))

    return unittest.end(env)

def _local_license_prefers_popili_over_legacy_test(ctx):
    env = unittest.begin(ctx)

    popili = "%s/.local/share/popili/licenses_6.lic" % _LINUX_HOME
    legacy = "%s/.local/share/coco_platform/licenses_6.lic" % _LINUX_HOME
    fake = _fake_repository_ctx("linux", [legacy, popili])

    asserts.equals(env, popili, find_local_license_path(fake, _fake_path_exists))

    return unittest.end(env)

def _local_license_prefers_suffixed_over_unsuffixed_test(ctx):
    """Suffix order wins over product order: a legacy _6 beats an unsuffixed Popili."""
    env = unittest.begin(ctx)

    legacy_suffixed = "%s/.local/share/coco_platform/licenses_6.lic" % _LINUX_HOME
    popili_unsuffixed = "%s/.local/share/popili/licenses.lic" % _LINUX_HOME
    fake = _fake_repository_ctx("linux", [popili_unsuffixed, legacy_suffixed])

    asserts.equals(env, legacy_suffixed, find_local_license_path(fake, _fake_path_exists))

    return unittest.end(env)

def _local_license_absent_test(ctx):
    """With nothing installed the caller gets None, and emits the empty stub."""
    env = unittest.begin(ctx)

    fake = _fake_repository_ctx("linux", [])

    asserts.equals(env, None, find_local_license_path(fake, _fake_path_exists))

    return unittest.end(env)

def _local_license_unset_home_test(ctx):
    """An unset $HOME must probe nothing, not a path anchored at literal "None".

    "%s" % None yields "None/...", a relative path, and ctx.path() resolves a
    relative path inside the generated repository directory - a location that
    also moves depending on whether rules_coco is the root module or a
    dependency of someone else's.
    """
    env = unittest.begin(ctx)

    degenerate = "None/.local/share/popili/licenses_6.lic"
    fake = _fake_repository_ctx("linux", [degenerate], home = None)

    asserts.equals(env, None, find_local_license_path(fake, _fake_path_exists))

    return unittest.end(env)

def _local_license_empty_home_test(ctx):
    """An empty $HOME is treated as unset rather than as the filesystem root."""
    env = unittest.begin(ctx)

    degenerate = "/.local/share/popili/licenses_6.lic"
    fake = _fake_repository_ctx("linux", [degenerate], home = "")

    asserts.equals(env, None, find_local_license_path(fake, _fake_path_exists))

    return unittest.end(env)

def _local_license_unset_appdata_windows_test(ctx):
    """On Windows the anchor is %APPDATA%, so a set $HOME must not rescue it."""
    env = unittest.begin(ctx)

    degenerate = "None\\..\\LocalLow\\Popili\\licenses_6.lic"
    fake = _fake_repository_ctx("windows 10", [degenerate], appdata = None)

    asserts.equals(env, None, find_local_license_path(fake, _fake_path_exists))

    return unittest.end(env)

def _local_license_unset_appdata_ignored_off_windows_test(ctx):
    """Off Windows %APPDATA% is irrelevant, so an unset one must not block the probe."""
    env = unittest.begin(ctx)

    license = "%s/.local/share/popili/licenses_6.lic" % _LINUX_HOME
    fake = _fake_repository_ctx("linux", [license], appdata = None)

    asserts.equals(env, license, find_local_license_path(fake, _fake_path_exists))

    return unittest.end(env)

local_license_suffixed_linux_test = unittest.make(_local_license_suffixed_linux_test)
local_license_suffixed_mac_test = unittest.make(_local_license_suffixed_mac_test)
local_license_suffixed_windows_test = unittest.make(_local_license_suffixed_windows_test)
local_license_unsuffixed_test = unittest.make(_local_license_unsuffixed_test)
local_license_legacy_fallback_test = unittest.make(_local_license_legacy_fallback_test)
local_license_prefers_popili_over_legacy_test = unittest.make(_local_license_prefers_popili_over_legacy_test)
local_license_prefers_suffixed_over_unsuffixed_test = unittest.make(_local_license_prefers_suffixed_over_unsuffixed_test)
local_license_absent_test = unittest.make(_local_license_absent_test)
local_license_unset_home_test = unittest.make(_local_license_unset_home_test)
local_license_empty_home_test = unittest.make(_local_license_empty_home_test)
local_license_unset_appdata_windows_test = unittest.make(_local_license_unset_appdata_windows_test)
local_license_unset_appdata_ignored_off_windows_test = unittest.make(_local_license_unset_appdata_ignored_off_windows_test)

# Tests for coco_toolchain_download

# The supported platforms, and the archive each one downloads. Spelled out rather than
# derived, so the tests below pin the actual archive names; kept in step with the
# platforms the rules register by _coco_toolchain_download_covers_every_platform_test.
_TOOLCHAIN_PLATFORMS = [
    ("osx", "aarch64", "popili_darwin_arm64.zip"),
    ("linux", "aarch64", "popili_linux_arm64.zip"),
    ("linux", "x86_64", "popili_linux_amd64.zip"),
    ("windows", "x86_64", "popili_windows_amd64.zip"),
]

def _coco_toolchain_download_covers_every_platform_test(ctx):
    """Every platform the rules register has download tests covering it."""
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        [(os, arch) for (os, arch) in COCO_TOOLCHAIN_PLATFORMS],
        [(os, arch) for (os, arch, _archive) in _TOOLCHAIN_PLATFORMS],
        "_TOOLCHAIN_PLATFORMS has drifted from COCO_TOOLCHAIN_PLATFORMS",
    )

    return unittest.end(env)

def _coco_toolchain_download_url_test(ctx):
    """The download URL keeps the archive/ prefix and the platform-mangled file name."""
    env = unittest.begin(ctx)

    for (os, arch, archive) in _TOOLCHAIN_PLATFORMS:
        asserts.equals(
            env,
            "https://dl.cocotec.io/popili/archive/1.5.7/" + archive,
            coco_toolchain_download("1.5.7", os, arch).url,
        )

    return unittest.end(env)

def _coco_toolchain_download_sha_matches_known_shas_test(ctx):
    """The checksum handed to download_and_extract is the one recorded in known_shas.bzl."""
    env = unittest.begin(ctx)

    for (os, arch, archive) in _TOOLCHAIN_PLATFORMS:
        key = "1.5.7/" + archive
        asserts.equals(
            env,
            FILE_KEY_TO_SHA.get(key, "<no known_shas.bzl entry for %s>" % key),
            coco_toolchain_download("1.5.7", os, arch).sha256,
            "wrong checksum for %s (known_shas.bzl key %r)" % (archive, key),
        )

    return unittest.end(env)

def _coco_toolchain_download_all_platforms_verified_test(ctx):
    """No platform is downloaded without a checksum."""
    env = unittest.begin(ctx)

    for (os, arch, archive) in _TOOLCHAIN_PLATFORMS:
        sha256 = coco_toolchain_download("1.5.7", os, arch).sha256
        asserts.true(
            env,
            sha256 != "",
            "1.5.7 %s/%s (%s) would be downloaded unverified" % (os, arch, archive),
        )
        asserts.equals(env, 64, len(sha256), "not a sha256 for %s: %r" % (archive, sha256))

    return unittest.end(env)

def _coco_toolchain_download_version_aliases_verified_test(ctx):
    """Every version an alias resolves to is checksummed on every platform."""
    env = unittest.begin(ctx)

    for (alias, version) in VERSION_ALIASES.items():
        for (os, arch, _archive) in _TOOLCHAIN_PLATFORMS:
            asserts.true(
                env,
                coco_toolchain_download(version, os, arch).sha256 != "",
                "alias %r (%s) %s/%s would be downloaded unverified" % (alias, version, os, arch),
            )

    return unittest.end(env)

def _coco_toolchain_download_prerelease_test(ctx):
    """Pre-release versions are checksummed too, and keep their URL shape."""
    env = unittest.begin(ctx)

    download = coco_toolchain_download("1.5.0-rc.1", "osx", "aarch64")

    asserts.equals(
        env,
        "https://dl.cocotec.io/popili/archive/1.5.0-rc.1/popili_darwin_arm64.zip",
        download.url,
    )
    asserts.equals(
        env,
        FILE_KEY_TO_SHA.get("1.5.0-rc.1/popili_darwin_arm64.zip"),
        download.sha256,
    )

    return unittest.end(env)

def _coco_toolchain_download_unknown_version_test(ctx):
    """A popili release newer than this rules_coco still downloads, just unverified.

    rules_coco must stay forward compatible: a version with no known_shas.bzl entry
    yields an empty checksum rather than failing, so the download still goes ahead.
    """
    env = unittest.begin(ctx)

    download = coco_toolchain_download("9.9.9", "linux", "x86_64")

    asserts.equals(
        env,
        "https://dl.cocotec.io/popili/archive/9.9.9/popili_linux_amd64.zip",
        download.url,
    )
    asserts.equals(env, "", download.sha256)

    return unittest.end(env)

coco_toolchain_download_url_test = unittest.make(_coco_toolchain_download_url_test)
coco_toolchain_download_sha_matches_known_shas_test = unittest.make(_coco_toolchain_download_sha_matches_known_shas_test)
coco_toolchain_download_all_platforms_verified_test = unittest.make(_coco_toolchain_download_all_platforms_verified_test)
coco_toolchain_download_version_aliases_verified_test = unittest.make(_coco_toolchain_download_version_aliases_verified_test)
coco_toolchain_download_prerelease_test = unittest.make(_coco_toolchain_download_prerelease_test)
coco_toolchain_download_unknown_version_test = unittest.make(_coco_toolchain_download_unknown_version_test)
coco_toolchain_download_covers_every_platform_test = unittest.make(_coco_toolchain_download_covers_every_platform_test)

# Tests for resolve_version_alias

def _resolve_version_alias_known_alias_test(ctx):
    """Every alias in version_aliases.bzl resolves to the version it maps to."""
    env = unittest.begin(ctx)

    for (alias, version) in VERSION_ALIASES.items():
        asserts.equals(env, version, resolve_version_alias(alias))

    return unittest.end(env)

def _resolve_version_alias_passthrough_test(ctx):
    """Anything that is not an alias comes back unchanged, including 'local' and ''."""
    env = unittest.begin(ctx)

    for version in ["1.5.1", "1.6.0-rc.1", "local", ""]:
        asserts.equals(env, version, resolve_version_alias(version))

    return unittest.end(env)

def _resolve_versions_default_resolver_test(ctx):
    """Without an explicit resolver, resolve_versions uses the real aliases."""
    env = unittest.begin(ctx)

    versions, err = resolve_versions(["stable"])

    asserts.equals(env, None, err)
    asserts.equals(env, [VERSION_ALIASES["stable"]], versions)

    return unittest.end(env)

def _normalize_extra_deps_default_resolver_test(ctx):
    """Without an explicit resolver, cc_runtime_extra_deps dict keys resolve via the real aliases."""
    env = unittest.begin(ctx)

    stable = VERSION_ALIASES["stable"]
    result, err = normalize_cc_runtime_extra_deps({"stable": ["@boost//:a"]}, {stable: True})

    asserts.equals(env, None, err)
    asserts.equals(env, {stable: ["@boost//:a"]}, result)

    return unittest.end(env)

resolve_version_alias_known_alias_test = unittest.make(_resolve_version_alias_known_alias_test)
resolve_version_alias_passthrough_test = unittest.make(_resolve_version_alias_passthrough_test)
resolve_versions_default_resolver_test = unittest.make(_resolve_versions_default_resolver_test)
normalize_extra_deps_default_resolver_test = unittest.make(_normalize_extra_deps_default_resolver_test)

def _version_tuple_test(ctx):
    """Release parts parse to ints; a pre-release suffix is ignored; anything else is None."""
    env = unittest.begin(ctx)

    asserts.equals(env, (1, 5, 0), version_tuple("1.5.0"))
    asserts.equals(env, (1, 6, 0), version_tuple("1.6.0-alpha.15899"))
    for not_a_version in ["stable", "local", "", "1.x", "1..0"]:
        asserts.equals(env, None, version_tuple(not_a_version))

    return unittest.end(env)

def _download_prefix_test(ctx):
    """Released versions download from archive/; anything else is used as the path as is."""
    env = unittest.begin(ctx)

    asserts.equals(env, "archive/1.5.1", download_prefix("1.5.1"))
    asserts.equals(env, "archive/1.6.0-rc.1", download_prefix("1.6.0-rc.1"))
    asserts.equals(env, "stable", download_prefix("stable"))
    asserts.equals(env, "1", download_prefix("1"))

    return unittest.end(env)

def _archive_platform_test(ctx):
    """Archive names spell every toolchain platform the way popili's releases do."""
    env = unittest.begin(ctx)

    asserts.equals(env, ("darwin", "arm64"), archive_platform("osx", "aarch64"))
    asserts.equals(env, ("linux", "arm64"), archive_platform("linux", "aarch64"))
    asserts.equals(env, ("linux", "amd64"), archive_platform("linux", "x86_64"))
    asserts.equals(env, ("windows", "amd64"), archive_platform("windows", "x86_64"))
    asserts.equals(env, ".exe", platform_binary_ext("windows"))
    asserts.equals(env, "", platform_binary_ext("linux"))
    asserts.equals(env, "", platform_binary_ext("osx"))

    return unittest.end(env)

version_tuple_test = unittest.make(_version_tuple_test)
download_prefix_test = unittest.make(_download_prefix_test)
archive_platform_test = unittest.make(_archive_platform_test)

# Tests for resolve_versions

def _resolve_versions_alias_test(ctx):
    """Aliases resolve to the version they point at."""
    env = unittest.begin(ctx)

    versions, err = resolve_versions(["stable"], _fake_resolve)

    asserts.equals(env, None, err)
    asserts.equals(env, ["1.5.1"], versions)

    return unittest.end(env)

def _resolve_versions_dedups_preserving_order_test(ctx):
    """An alias and the version it resolves to collapse to one entry, keeping first-seen order."""
    env = unittest.begin(ctx)

    versions, err = resolve_versions(["1.5.1", "stable", "1.5.0", "1.5.1"], _fake_resolve)

    asserts.equals(env, None, err)
    asserts.equals(env, ["1.5.1", "1.5.0"], versions)

    return unittest.end(env)

def _resolve_versions_order_is_significant_test(ctx):
    """Order is preserved, because the first version becomes the default toolchain."""
    env = unittest.begin(ctx)

    versions, err = resolve_versions(["1.5.0", "1.5.1"], _fake_resolve)
    asserts.equals(env, None, err)
    asserts.equals(env, ["1.5.0", "1.5.1"], versions)

    versions, err = resolve_versions(["1.5.1", "1.5.0"], _fake_resolve)
    asserts.equals(env, None, err)
    asserts.equals(env, ["1.5.1", "1.5.0"], versions)

    return unittest.end(env)

def _resolve_versions_empty_test(ctx):
    """No versions is not an error: a local-only toolchain registers none."""
    env = unittest.begin(ctx)

    versions, err = resolve_versions([], _fake_resolve)

    asserts.equals(env, None, err)
    asserts.equals(env, [], versions)

    return unittest.end(env)

def _resolve_versions_below_minimum_rejected_test(ctx):
    """A version older than the supported minimum is rejected."""
    env = unittest.begin(ctx)

    versions, err = resolve_versions(["1.4.9"], _fake_resolve)

    asserts.equals(env, [], versions)
    asserts.true(env, err != None, "1.4.9 should be rejected")
    asserts.true(env, "1.5.0" in err, "error should name the minimum version: %s" % err)

    return unittest.end(env)

def _resolve_versions_reserved_rejected_test(ctx):
    """'local' and 'default' name the hub's own config_settings, so they cannot be versions."""
    env = unittest.begin(ctx)

    for reserved in ["local", "default"]:
        versions, err = resolve_versions([reserved], _fake_resolve)
        asserts.equals(env, [], versions)
        asserts.true(env, err != None, "%r should be rejected" % reserved)
        asserts.true(
            env,
            reserved in err,
            "error should name the offending version: %s" % err,
        )

    return unittest.end(env)

def _resolve_versions_suffix_collision_rejected_test(ctx):
    """Two versions that mangle to the same repository suffix cannot coexist."""
    env = unittest.begin(ctx)

    versions, err = resolve_versions(["1.5.0-rc.1", "1.5.0-rc-1"], _fake_resolve)

    asserts.equals(env, [], versions)
    asserts.true(env, err != None, "colliding suffixes should be rejected")
    asserts.true(env, "1_5_0_rc_1" in err, "error should name the suffix: %s" % err)

    return unittest.end(env)

resolve_versions_alias_test = unittest.make(_resolve_versions_alias_test)
resolve_versions_dedups_preserving_order_test = unittest.make(_resolve_versions_dedups_preserving_order_test)
resolve_versions_order_is_significant_test = unittest.make(_resolve_versions_order_is_significant_test)
resolve_versions_empty_test = unittest.make(_resolve_versions_empty_test)
resolve_versions_below_minimum_rejected_test = unittest.make(_resolve_versions_below_minimum_rejected_test)
resolve_versions_reserved_rejected_test = unittest.make(_resolve_versions_reserved_rejected_test)
resolve_versions_suffix_collision_rejected_test = unittest.make(_resolve_versions_suffix_collision_rejected_test)

# Tests for toolchain_hub_entries

def _hub_entries_single_version_test(ctx):
    """One version yields a per-platform toolchain plus a per-platform default."""
    env = unittest.begin(ctx)

    entries = toolchain_hub_entries(["1.5.7"])

    asserts.equals(
        env,
        2 * len(COCO_TOOLCHAIN_PLATFORMS),
        len(entries.toolchain_names),
    )
    asserts.equals(env, {"1.5.7": "1_5_7"}, entries.version_suffixes)

    # Both the version-gated and the default toolchain point at the same repository.
    label = "@io_cocotec_coco_linux_x86_64__1_5_7//:toolchain_impl"
    asserts.equals(env, label, entries.toolchain_labels["linux_x86_64__1_5_7"])
    asserts.equals(env, label, entries.toolchain_labels["linux_x86_64__default"])

    asserts.equals(
        env,
        ["@coco_toolchains//:version_1_5_7"],
        entries.target_settings["linux_x86_64__1_5_7"],
    )
    asserts.equals(
        env,
        ["@coco_toolchains//:version_default"],
        entries.target_settings["linux_x86_64__default"],
    )

    constraints = ["@platforms//os:linux", "@platforms//cpu:x86_64"]
    asserts.equals(env, constraints, entries.exec_compatible_with["linux_x86_64__1_5_7"])

    return unittest.end(env)

def _hub_entries_default_is_first_version_only_test(ctx):
    """Only the first version gets the default toolchains."""
    env = unittest.begin(ctx)

    entries = toolchain_hub_entries(["1.5.0", "1.5.1"])

    asserts.equals(
        env,
        3 * len(COCO_TOOLCHAIN_PLATFORMS),
        len(entries.toolchain_names),
    )
    asserts.equals(env, {"1.5.0": "1_5_0", "1.5.1": "1_5_1"}, entries.version_suffixes)

    asserts.equals(
        env,
        "@io_cocotec_coco_linux_x86_64__1_5_0//:toolchain_impl",
        entries.toolchain_labels["linux_x86_64__default"],
    )
    asserts.true(
        env,
        "linux_x86_64__1_5_1" in entries.toolchain_names,
        "the non-default version still gets a gated toolchain",
    )

    return unittest.end(env)

def _hub_entries_local_only_test(ctx):
    """A local-only setup registers exactly one toolchain, gated on --version=local.

    Matching bzlmod: local never becomes the default, so a build that does not set the
    flag resolves no Coco toolchain at all.
    """
    env = unittest.begin(ctx)

    entries = toolchain_hub_entries([], has_local = True)

    asserts.equals(env, ["local"], entries.toolchain_names)
    asserts.equals(env, {"local": "local"}, entries.version_suffixes)
    asserts.equals(
        env,
        "@io_cocotec_coco_local//:toolchain_impl",
        entries.toolchain_labels["local"],
    )
    asserts.equals(env, ["@coco_toolchains//:version_local"], entries.target_settings["local"])

    # Host-only: the local binaries only exist on the machine that staged them.
    asserts.equals(env, [], entries.exec_compatible_with["local"])

    return unittest.end(env)

def _hub_entries_local_alongside_versions_test(ctx):
    """A local toolchain does not displace the downloaded default."""
    env = unittest.begin(ctx)

    entries = toolchain_hub_entries(["1.5.7"], has_local = True)

    asserts.equals(
        env,
        2 * len(COCO_TOOLCHAIN_PLATFORMS) + 1,
        len(entries.toolchain_names),
    )
    asserts.equals(
        env,
        "@io_cocotec_coco_linux_x86_64__1_5_7//:toolchain_impl",
        entries.toolchain_labels["linux_x86_64__default"],
    )
    asserts.equals(env, ["@coco_toolchains//:version_local"], entries.target_settings["local"])

    return unittest.end(env)

hub_entries_single_version_test = unittest.make(_hub_entries_single_version_test)
hub_entries_default_is_first_version_only_test = unittest.make(_hub_entries_default_is_first_version_only_test)
hub_entries_local_only_test = unittest.make(_hub_entries_local_only_test)
hub_entries_local_alongside_versions_test = unittest.make(_hub_entries_local_alongside_versions_test)

# Tests for render_toolchain_hub_build

def _hub_build_labels_test(ctx):
    """The rendered BUILD wires the version flag and toolchain type by absolute label.

    Those labels have to resolve from a generated repository in both WORKSPACE mode
    (global repository namespace) and bzlmod (the extension's repo mapping), so they are
    pinned here.
    """
    env = unittest.begin(ctx)

    build = render_toolchain_hub_build(toolchain_hub_entries(["1.5.7"]))

    asserts.true(
        env,
        '"@rules_coco//:version": "1.5.7"' in build,
        "version config_setting missing: %s" % build,
    )
    asserts.true(
        env,
        '"@rules_coco//:version": ""' in build,
        "default config_setting missing: %s" % build,
    )
    asserts.true(
        env,
        'toolchain_type = "@rules_coco//coco:toolchain_type"' in build,
        "toolchain_type missing: %s" % build,
    )
    asserts.true(
        env,
        'target_settings = ["@coco_toolchains//:version_1_5_7"]' in build,
        "target_settings missing: %s" % build,
    )

    return unittest.end(env)

def _hub_build_has_no_loads_test(ctx):
    """The hub uses only native rules, so it stays loadable before skylib is fetched."""
    env = unittest.begin(ctx)

    build = render_toolchain_hub_build(toolchain_hub_entries(["1.5.7"], has_local = True))

    asserts.true(env, "load(" not in build, "hub BUILD must not load anything: %s" % build)

    return unittest.end(env)

def _hub_build_constrains_exec_only_test(ctx):
    """Toolchains constrain the exec platform only, so cross-compiling still resolves one."""
    env = unittest.begin(ctx)

    build = render_toolchain_hub_build(toolchain_hub_entries(["1.5.7"], has_local = True))

    asserts.true(env, "exec_compatible_with" in build, "exec constraint missing: %s" % build)
    asserts.true(
        env,
        "target_compatible_with" not in build,
        "hub BUILD must not constrain the target platform: %s" % build,
    )

    return unittest.end(env)

hub_build_labels_test = unittest.make(_hub_build_labels_test)
hub_build_has_no_loads_test = unittest.make(_hub_build_has_no_loads_test)
hub_build_constrains_exec_only_test = unittest.make(_hub_build_constrains_exec_only_test)

# Tests for normalize_cc_runtime_extra_deps

def _normalize_extra_deps_list_applies_to_all_test(ctx):
    """A flat list is the pre-multi-version spelling: it applies to every version."""
    env = unittest.begin(ctx)

    # buildifier: disable=canonical-repository
    result, err = normalize_cc_runtime_extra_deps(
        ["@@boost+//:optional"],
        {"1.5.0": True, "1.5.1": True},
        _fake_resolve,
    )

    asserts.equals(env, None, err)

    # buildifier: disable=canonical-repository
    asserts.equals(
        env,
        {"1.5.0": ["@@boost+//:optional"], "1.5.1": ["@@boost+//:optional"]},
        result,
    )

    return unittest.end(env)

def _normalize_extra_deps_dict_is_per_version_test(ctx):
    """A dict targets one version; versions it omits get nothing."""
    env = unittest.begin(ctx)

    # buildifier: disable=canonical-repository
    result, err = normalize_cc_runtime_extra_deps(
        {"1.5.0": ["@@boost+//:optional"]},
        {"1.5.0": True, "1.5.1": True},
        _fake_resolve,
    )

    asserts.equals(env, None, err)

    # buildifier: disable=canonical-repository
    asserts.equals(env, {"1.5.0": ["@@boost+//:optional"]}, result)

    return unittest.end(env)

def _normalize_extra_deps_dict_alias_key_test(ctx):
    """An alias key collapses onto the version it resolves to."""
    env = unittest.begin(ctx)

    # buildifier: disable=canonical-repository
    result, err = normalize_cc_runtime_extra_deps(
        {"stable": ["@@boost+//:optional"]},
        {"1.5.1": True},
        _fake_resolve,
    )

    asserts.equals(env, None, err)

    # buildifier: disable=canonical-repository
    asserts.equals(env, {"1.5.1": ["@@boost+//:optional"]}, result)

    return unittest.end(env)

def _normalize_extra_deps_unknown_version_test(ctx):
    """Deps for a version that was never registered are an error, as under bzlmod."""
    env = unittest.begin(ctx)

    # buildifier: disable=canonical-repository
    result, err = normalize_cc_runtime_extra_deps(
        {"1.4.0": ["@@boost+//:optional"]},
        {"1.5.1": True},
        _fake_resolve,
    )

    asserts.equals(env, {}, result)
    asserts.true(env, err != None, "unknown version should be rejected")
    asserts.true(env, "1.4.0" in err, "error should name the bad version: %s" % err)

    return unittest.end(env)

def _normalize_extra_deps_list_includes_local_test(ctx):
    """A flat list also reaches the local runtime once "local" is registered."""
    env = unittest.begin(ctx)

    result, err = normalize_cc_runtime_extra_deps(
        ["@my_ws//:shim"],
        {"1.5.1": True, "local": True},
        _fake_resolve,
    )

    asserts.equals(env, None, err)
    asserts.equals(env, {"1.5.1": ["@my_ws//:shim"], "local": ["@my_ws//:shim"]}, result)

    return unittest.end(env)

def _normalize_extra_deps_dict_local_key_test(ctx):
    """The "local" key targets the local runtime alone."""
    env = unittest.begin(ctx)

    result, err = normalize_cc_runtime_extra_deps(
        {"local": ["@my_ws//:shim"]},
        {"1.5.1": True, "local": True},
        _fake_resolve,
    )

    asserts.equals(env, None, err)
    asserts.equals(env, {"local": ["@my_ws//:shim"]}, result)

    return unittest.end(env)

def _normalize_extra_deps_list_dedupes_test(ctx):
    """Repeated labels in a flat list are written once, as with the bzlmod tag."""
    env = unittest.begin(ctx)

    result, err = normalize_cc_runtime_extra_deps(
        ["@my_ws//:shim", "@my_ws//:shim"],
        {"1.5.1": True},
        _fake_resolve,
    )

    asserts.equals(env, None, err)
    asserts.equals(env, {"1.5.1": ["@my_ws//:shim"]}, result)

    return unittest.end(env)

def _normalize_extra_deps_empty_test(ctx):
    """Neither empty form, nor None, registers anything."""
    env = unittest.begin(ctx)

    result, err = normalize_cc_runtime_extra_deps([], {"1.5.1": True}, _fake_resolve)
    asserts.equals(env, None, err)
    asserts.equals(env, {}, result)

    result, err = normalize_cc_runtime_extra_deps({}, {"1.5.1": True}, _fake_resolve)
    asserts.equals(env, None, err)
    asserts.equals(env, {}, result)

    result, err = normalize_cc_runtime_extra_deps(None, {"1.5.1": True}, _fake_resolve)
    asserts.equals(env, None, err)
    asserts.equals(env, {}, result)

    return unittest.end(env)

normalize_extra_deps_list_applies_to_all_test = unittest.make(_normalize_extra_deps_list_applies_to_all_test)
normalize_extra_deps_dict_is_per_version_test = unittest.make(_normalize_extra_deps_dict_is_per_version_test)
normalize_extra_deps_dict_alias_key_test = unittest.make(_normalize_extra_deps_dict_alias_key_test)
normalize_extra_deps_unknown_version_test = unittest.make(_normalize_extra_deps_unknown_version_test)
normalize_extra_deps_empty_test = unittest.make(_normalize_extra_deps_empty_test)
normalize_extra_deps_list_includes_local_test = unittest.make(_normalize_extra_deps_list_includes_local_test)
normalize_extra_deps_dict_local_key_test = unittest.make(_normalize_extra_deps_dict_local_key_test)
normalize_extra_deps_list_dedupes_test = unittest.make(_normalize_extra_deps_list_dedupes_test)

# Tests for merge_toolchain_tags

def _toolchain_tag(versions = ["stable"], c = False, cc = False, license_source = "", license_token = "", auth_token_path = ""):
    return struct(
        versions = versions,
        c = c,
        cc = cc,
        license_source = license_source,
        license_token = license_token,
        auth_token_path = auth_token_path,
    )

def _module(name, toolchain_tags):
    return struct(name = name, tags = struct(toolchain = toolchain_tags))

def _merge_toolchain_tags_default_test(ctx):
    """No module declaring coco.toolchain gets stable with both runtimes."""
    env = unittest.begin(ctx)

    config = merge_toolchain_tags([_module("my_project", []), _module("some_dep", [])])

    asserts.equals(env, ["stable"], config.versions)
    asserts.true(env, config.c)
    asserts.true(env, config.cc)
    asserts.equals(env, "", config.license_source)
    asserts.false(env, config.declared)

    return unittest.end(env)

def _merge_toolchain_tags_root_declaration_is_exact_test(ctx):
    """A root declaring coco.toolchain gets exactly its own: no stable, no unasked runtime."""
    env = unittest.begin(ctx)

    config = merge_toolchain_tags([_module("my_project", [_toolchain_tag(["1.5.1"], cc = True)])])

    asserts.equals(env, ["1.5.1"], config.versions)
    asserts.false(env, config.c)
    asserts.true(env, config.cc)
    asserts.true(env, config.declared)

    return unittest.end(env)

def _merge_toolchain_tags_merges_modules_in_order_test(ctx):
    """Dependencies contribute after the root, so the root's first version stays the default."""
    env = unittest.begin(ctx)

    config = merge_toolchain_tags([
        _module("my_project", [_toolchain_tag(["1.5.1"])]),
        _module("some_dep", [_toolchain_tag(["1.5.0"], c = True), _toolchain_tag(["1.5.1"])]),
    ])

    asserts.equals(env, ["1.5.1", "1.5.0", "1.5.1"], config.versions)
    asserts.true(env, config.c)
    asserts.false(env, config.cc)

    return unittest.end(env)

def _merge_toolchain_tags_dependency_only_test(ctx):
    """A dependency's declaration is used as-is; the default does not get added on top."""
    env = unittest.begin(ctx)

    config = merge_toolchain_tags([
        _module("my_project", []),
        _module("some_dep", [_toolchain_tag(["1.5.0"])]),
    ])

    asserts.equals(env, ["1.5.0"], config.versions)
    asserts.false(env, config.c)
    asserts.false(env, config.cc)
    asserts.true(env, config.declared)

    return unittest.end(env)

def _merge_toolchain_tags_first_license_setting_wins_test(ctx):
    """The first non-empty licence setting, in module order, is taken."""
    env = unittest.begin(ctx)

    config = merge_toolchain_tags([
        _module("my_project", [_toolchain_tag(), _toolchain_tag(license_source = "token", license_token = "root")]),
        _module("some_dep", [_toolchain_tag(license_source = "local_user", license_token = "dep", auth_token_path = "/dep")]),
    ])

    asserts.equals(env, "token", config.license_source)
    asserts.equals(env, "root", config.license_token)
    asserts.equals(env, "/dep", config.auth_token_path)

    return unittest.end(env)

merge_toolchain_tags_default_test = unittest.make(_merge_toolchain_tags_default_test)
merge_toolchain_tags_root_declaration_is_exact_test = unittest.make(_merge_toolchain_tags_root_declaration_is_exact_test)
merge_toolchain_tags_merges_modules_in_order_test = unittest.make(_merge_toolchain_tags_merges_modules_in_order_test)
merge_toolchain_tags_dependency_only_test = unittest.make(_merge_toolchain_tags_dependency_only_test)
merge_toolchain_tags_first_license_setting_wins_test = unittest.make(_merge_toolchain_tags_first_license_setting_wins_test)

def coco_test_suite(name):
    """Create test suite for coco functions.

    Args:
        name: The name of the test suite.
    """

    # The corpus tests are instantiated by name rather than through
    # unittest.suite, which numbers its targets ("%s_test_%d"). A CI failure
    # should say which style broke, and adding a case should not renumber
    # every other target.
    corpus_tests = []
    for style in CORPUS_STYLES:
        target = "mangle_corpus_%s_test" % style
        mangle_corpus_test(name = target, style = style)
        corpus_tests.append(":" + target)

    path_corpus_test(name = "path_corpus_test")
    corpus_styles_test(name = "corpus_styles_test")
    corpus_tests += [":path_corpus_test", ":corpus_styles_test"]

    unittest.suite(
        name + "_unit",
        module_path_for_test,
        package_relative_dir_test,

        # collect_cc_runtime_extra_deps tests
        cc_runtime_deps_root_single_version_test,
        cc_runtime_deps_root_alias_collapses_to_resolved_version_test,
        cc_runtime_deps_root_dedups_across_tags_test,
        cc_runtime_deps_local_version_test,
        cc_runtime_deps_non_root_rejected_test,
        cc_runtime_deps_non_root_rejected_even_when_root_also_present_test,
        cc_runtime_deps_unknown_version_test,

        # find_local_license_path tests
        local_license_suffixed_linux_test,
        local_license_suffixed_mac_test,
        local_license_suffixed_windows_test,
        local_license_unsuffixed_test,
        local_license_legacy_fallback_test,
        local_license_prefers_popili_over_legacy_test,
        local_license_prefers_suffixed_over_unsuffixed_test,
        local_license_absent_test,
        local_license_unset_home_test,
        local_license_empty_home_test,
        local_license_unset_appdata_windows_test,
        local_license_unset_appdata_ignored_off_windows_test,

        # coco_toolchain_download tests
        coco_toolchain_download_url_test,
        coco_toolchain_download_sha_matches_known_shas_test,
        coco_toolchain_download_all_platforms_verified_test,
        coco_toolchain_download_version_aliases_verified_test,
        coco_toolchain_download_prerelease_test,
        coco_toolchain_download_unknown_version_test,
        coco_toolchain_download_covers_every_platform_test,

        # resolve_version_alias tests
        resolve_version_alias_known_alias_test,
        resolve_version_alias_passthrough_test,
        resolve_versions_default_resolver_test,
        normalize_extra_deps_default_resolver_test,
        version_tuple_test,
        download_prefix_test,
        archive_platform_test,

        # resolve_versions tests
        resolve_versions_alias_test,
        resolve_versions_dedups_preserving_order_test,
        resolve_versions_order_is_significant_test,
        resolve_versions_empty_test,
        resolve_versions_below_minimum_rejected_test,
        resolve_versions_reserved_rejected_test,
        resolve_versions_suffix_collision_rejected_test,

        # toolchain_hub_entries tests
        hub_entries_single_version_test,
        hub_entries_default_is_first_version_only_test,
        hub_entries_local_only_test,
        hub_entries_local_alongside_versions_test,

        # render_toolchain_hub_build tests
        hub_build_labels_test,
        hub_build_has_no_loads_test,
        hub_build_constrains_exec_only_test,

        # normalize_cc_runtime_extra_deps tests
        normalize_extra_deps_list_applies_to_all_test,
        normalize_extra_deps_dict_is_per_version_test,
        normalize_extra_deps_dict_alias_key_test,
        normalize_extra_deps_unknown_version_test,
        normalize_extra_deps_empty_test,
        normalize_extra_deps_list_includes_local_test,
        normalize_extra_deps_dict_local_key_test,
        normalize_extra_deps_list_dedupes_test,

        # merge_toolchain_tags tests
        merge_toolchain_tags_default_test,
        merge_toolchain_tags_root_declaration_is_exact_test,
        merge_toolchain_tags_merges_modules_in_order_test,
        merge_toolchain_tags_dependency_only_test,
        merge_toolchain_tags_first_license_setting_wins_test,
    )

    native.test_suite(
        name = name,
        tests = [":" + name + "_unit"] + corpus_tests,
    )
