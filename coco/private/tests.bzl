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
    "STYLES_RULES_COCO_UNSUPPORTED",
)
load(":cc_runtime_deps.bzl", "collect_cc_runtime_extra_deps")
load(":coco.bzl", "compute_output_paths", "mangle_name", "module_path_for", "package_relative_dir")
load(":common_repositories.bzl", "find_local_license_path")
load(":known_shas.bzl", "FILE_KEY_TO_SHA")
load(":repositories.bzl", "coco_toolchain_download")
load(":version_aliases.bzl", "VERSION_ALIASES")

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
cc_runtime_deps_non_root_rejected_test = unittest.make(_cc_runtime_deps_non_root_rejected_test)
cc_runtime_deps_non_root_rejected_even_when_root_also_present_test = unittest.make(_cc_runtime_deps_non_root_rejected_even_when_root_also_present_test)
cc_runtime_deps_unknown_version_test = unittest.make(_cc_runtime_deps_unknown_version_test)

# Corpus-driven tests for name mangling
#
# The expected values live in //testdata:name_mangling_corpus.bzl, which popili
# loads too: it depends on rules_coco as a Bazel module and asserts against the
# same cases. One shared file, loaded by both, is what stops the two
# implementations drifting; see testdata/README.md for the semantics and the
# update procedure.
#
# Cases are not written inline here on purpose: an expectation that lives only
# in this repo is exactly how the divergences these tests were written for went
# unnoticed.

# Styles the corpus carries that rules_coco deliberately does not implement.
# Listing one here is a decision, not an omission; _corpus_styles_test fails if
# a corpus style is neither implemented nor listed.
_UNIMPLEMENTED_STYLE_REASONS = {
    "LowerCamelCasePrefixUnderscore": "popili-only; no coco_generate attribute maps to it",
    "UnalteredButValid": "popili sanitises without re-casing; no coco_generate attribute maps to it",
}

def supported_corpus_styles():
    """Corpus styles that rules_coco implements and therefore tests.

    Returns:
        A sorted list of style names.
    """
    return [s for s in CORPUS_STYLES if s not in _UNIMPLEMENTED_STYLE_REASONS]

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
        if case["style"] in _UNIMPLEMENTED_STYLE_REASONS:
            continue

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
    # someone implements or allowlists it, and a style popili removes leaves a
    # stale allowlist entry behind.
    asserts.equals(
        env,
        sorted(CORPUS_STYLES),
        sorted(supported_corpus_styles() + _UNIMPLEMENTED_STYLE_REASONS.keys()),
        "every corpus style must be implemented by mangle_name or listed in " +
        "_UNIMPLEMENTED_STYLE_REASONS",
    )

    asserts.equals(
        env,
        sorted(STYLES_RULES_COCO_UNSUPPORTED),
        sorted(_UNIMPLEMENTED_STYLE_REASONS.keys()),
        "the corpus and this file disagree about which styles rules_coco implements",
    )

    # Every supported style must actually be exercised by at least one case, so
    # that a style cannot be "covered" by an empty loop.
    styles_in_corpus = {case["style"]: True for case in MANGLE_CASES}
    for style in supported_corpus_styles():
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

# The supported platforms, and the archive each one downloads.
_TOOLCHAIN_PLATFORMS = [
    ("osx", "aarch64", "popili_darwin_arm64.zip"),
    ("linux", "aarch64", "popili_linux_arm64.zip"),
    ("linux", "x86_64", "popili_linux_amd64.zip"),
    ("windows", "x86_64", "popili_windows_amd64.zip"),
]

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
    """No released platform is downloaded without a checksum."""
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
    for style in supported_corpus_styles():
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
    )

    native.test_suite(
        name = name,
        tests = [":" + name + "_unit"] + corpus_tests,
    )
