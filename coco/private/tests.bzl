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
load(":coco.bzl", "FILE_NAME_MANGLER_STYLES", "common_version", "compute_output_paths", "effective_version", "inherited_versions_conflict", "library_version_conflict", "library_version_mismatch_message", "mangle_name", "missing_popili_message", "module_path_for", "own_package_versions_message", "package_transition_settings", "package_versions_conflict", "pin_transition_settings", "popili_rule_reserved_attribute", "toolchain_version_mismatch_message", "unpin_transition_settings", "version_source")
load(":common_repositories.bzl", "coco_download", "download_prefix", "find_local_license_paths", "is_license_file_name")
load(":known_shas.bzl", "FILE_KEY_TO_SHA")
load(":license_versions.bzl", "LICENSE_PROTOCOL_VERSIONS")
load(":platforms.bzl", "COCO_TOOLCHAIN_PLATFORMS", "archive_platform", "platform_binary_ext")
load(":source_roots.bzl", "infer_source_root", "leaves_directory", "normalize_root", "relative_path", "resolve_source_roots", "source_root_for")
load(
    ":toolchain_hub.bzl",
    "merge_toolchain_tags",
    "render_toolchain_hub_build",
    "resolve_versions",
    "toolchain_hub_entries",
)
load(":toolchain_repositories.bzl", "BUILD_for_coco_toolchain", "coco_toolchain_download")
load(":version_aliases.bzl", "VERSION_ALIASES")
load(
    ":version_resolution.bzl",
    "VERSION_FLAG",
    "license_protocol_version",
    "resolve_version_alias",
    "version_key",
    "version_tuple",
)

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

    # A source root outside the package: sources = ["src_root", "../external_sources"].
    asserts.equals(
        env,
        ["MyPort"],
        module_path_for(struct(path = "external_sources/MyPort.coco"), "Main", "../external_sources"),
    )
    asserts.equals(
        env,
        ["Sub", "X"],
        module_path_for(struct(path = "external_sources/Sub/X.coco"), "Main", "../external_sources"),
    )

    # Coco.toml at the workspace root.
    asserts.equals(env, ["Comp"], module_path_for(struct(path = "src/Comp.coco"), "", "src"))

    return unittest.end(env)

module_path_for_test = unittest.make(_module_path_for_test_impl)

# Tests for source_roots.bzl. Paths here are relative to the Coco.toml directory.

def _infer_source_root_single_root_test(ctx):
    env = unittest.begin(ctx)

    # sources = ["src"], glob(["src/*.coco"])
    asserts.equals(env, "src", infer_source_root(["src/Comp.coco", "src/Runnable.coco"]))

    return unittest.end(env)

def _infer_source_root_nested_order_independent_test(ctx):
    env = unittest.begin(ctx)

    # sources = ["src"], glob(["src/**/*.coco"]). glob() sorts, so the nested file comes first whenever
    # its directory sorts before the top-level file ("Api" < "Main.coco").
    asserts.equals(env, "src", infer_source_root(["src/Main.coco", "src/types/Dimension.coco"]))
    asserts.equals(env, "src", infer_source_root(["src/Api/Foo.coco", "src/Main.coco"]))

    return unittest.end(env)

def _infer_source_root_nested_siblings_test(ctx):
    env = unittest.begin(ctx)

    # Files only in two sibling subdirectories: the root is their parent, not either sibling.
    asserts.equals(env, "src", infer_source_root(["src/a/X.coco", "src/b/Y.coco"]))
    asserts.equals(env, "src", infer_source_root(["src/b/Y.coco", "src/a/X.coco"]))

    return unittest.end(env)

def _infer_source_root_mixed_depths_test(ctx):
    env = unittest.begin(ctx)

    for order in [
        ["src/Top.coco", "src/a/Mid.coco", "src/a/b/Deep.coco"],
        ["src/a/Mid.coco", "src/Top.coco", "src/a/b/Deep.coco"],
        ["src/a/b/Deep.coco", "src/Top.coco", "src/a/Mid.coco"],
        ["src/a/b/Deep.coco", "src/a/Mid.coco", "src/Top.coco"],
    ]:
        asserts.equals(env, "src", infer_source_root(order), "order %s" % order)

    return unittest.end(env)

def _infer_source_root_beside_manifest_test(ctx):
    env = unittest.begin(ctx)

    # sources = ["."]: everything next to Coco.toml (test/package_directory), or one file next to it and
    # one in a subdirectory, in either order.
    asserts.equals(env, "", infer_source_root(["Comp.coco", "Runnable.coco"]))
    asserts.equals(env, "", infer_source_root(["Top.coco", "sub/Nested.coco"]))
    asserts.equals(env, "", infer_source_root(["sub/Nested.coco", "Top.coco"]))

    return unittest.end(env)

def _infer_source_root_nested_only_test(ctx):
    env = unittest.begin(ctx)

    # sources = ["src"], but every file lives in src/a: inference gives "src/a" (see infer_source_root).
    asserts.equals(env, "src/a", infer_source_root(["src/a/X.coco", "src/a/Y.coco"]))
    asserts.equals(env, "src", source_root_for("src/a/X.coco", ["src"]))

    return unittest.end(env)

def _infer_source_root_empty_test(ctx):
    env = unittest.begin(ctx)

    # glob() may match nothing.
    asserts.equals(env, "", infer_source_root([]))

    return unittest.end(env)

def _source_root_for_multiple_roots_test(ctx):
    env = unittest.begin(ctx)

    # sources = ["src", "generated"]: each file's module path is relative to its own root.
    roots = ["src", "generated"]
    asserts.equals(env, "src", source_root_for("src/Comp.coco", roots))
    asserts.equals(env, "generated", source_root_for("generated/Runnable.coco", roots))
    asserts.equals(env, "generated", source_root_for("generated/deep/Runnable.coco", roots))

    return unittest.end(env)

def _source_root_for_root_matching_test(ctx):
    env = unittest.begin(ctx)

    # "" (the Coco.toml directory) contains everything.
    asserts.equals(env, "", source_root_for("sub/X.coco", [""]))

    # Nested roots: the longest containing root wins.
    asserts.equals(env, "src/gen", source_root_for("src/gen/X.coco", ["src", "src/gen"]))
    asserts.equals(env, "src", source_root_for("src/X.coco", ["src/gen", "src"]))

    # A root must be a directory prefix, not just a string prefix.
    asserts.equals(env, "", source_root_for("srcs/X.coco", ["src", ""]))

    # Roots outside the Coco.toml directory.
    asserts.equals(env, "../ext", source_root_for("../ext/MyPort.coco", ["src", "../ext"]))
    asserts.equals(env, "..", source_root_for("../ext2/X.coco", ["src", "../ext", ".."]))

    return unittest.end(env)

def _relative_path_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(env, "src/A.coco", relative_path("pkg/src/A.coco", "pkg"))
    asserts.equals(env, "../external_sources/MyPort.coco", relative_path("external_sources/MyPort.coco", "Main"))
    asserts.equals(env, "../../b/X.coco", relative_path("a/b/X.coco", "a/c/d"))
    asserts.equals(env, "", relative_path("pkg", "pkg"))

    # "" is the workspace root, where Coco.toml may sit.
    asserts.equals(env, "src/X.coco", relative_path("src/X.coco", ""))

    # Directories are compared by segment, not by string prefix.
    asserts.equals(env, "../pkg2/X.coco", relative_path("pkg2/X.coco", "pkg"))

    # Paths that already leave their directory, as module paths do relative to a root outside the package.
    asserts.equals(env, "MyPort.coco", relative_path("../ext/MyPort.coco", "../ext"))

    return unittest.end(env)

def _leaves_directory_test(ctx):
    env = unittest.begin(ctx)

    asserts.true(env, leaves_directory(".."))
    asserts.true(env, leaves_directory("../ext/X.coco"))
    asserts.false(env, leaves_directory("..ext/X.coco"))
    asserts.false(env, leaves_directory("src/X.coco"))

    return unittest.end(env)

def _normalize_root_test(ctx):
    env = unittest.begin(ctx)

    asserts.equals(env, "", normalize_root(""))
    asserts.equals(env, "", normalize_root("."))
    asserts.equals(env, "", normalize_root("./"))
    asserts.equals(env, "src", normalize_root("src/"))
    asserts.equals(env, "src", normalize_root("./src"))
    asserts.equals(env, "src/a", normalize_root("src/./a/"))

    # Roots outside the Coco.toml directory.
    asserts.equals(env, "..", normalize_root(".."))
    asserts.equals(env, "../x", normalize_root("../x"))
    asserts.equals(env, "../x", normalize_root("../x/"))
    asserts.equals(env, "../x", normalize_root("./../x"))
    asserts.equals(env, "../x", normalize_root("src/../../x"))

    return unittest.end(env)

def _resolve_source_roots_test(ctx):
    env = unittest.begin(ctx)

    # resolve_source_roots only reads `.path`, so structs with a `path` field stand in for Files.
    files = [struct(path = "pkg/src/Comp.coco"), struct(path = "pkg/src/api/Runnable.coco")]
    asserts.equals(env, ["src"], resolve_source_roots("pkg", files, []))
    asserts.equals(env, ["src"], resolve_source_roots("pkg", files, ["src/"]))
    asserts.equals(env, ["src", "generated"], resolve_source_roots("pkg", files, ["src", "generated"]))

    # sources = ["src_root", "../external_sources"]
    asserts.equals(
        env,
        ["src_root", "../external_sources"],
        resolve_source_roots(
            "Main",
            [struct(path = "Main/src_root/MainComponent.coco"), struct(path = "external_sources/MyPort.coco")],
            ["src_root", "../external_sources/"],
        ),
    )

    # Coco.toml at the workspace root: package_file.dirname is "".
    asserts.equals(env, ["src"], resolve_source_roots("", [struct(path = "src/Comp.coco")], []))

    return unittest.end(env)

# Create test rules for source_roots.bzl
infer_source_root_single_root_test = unittest.make(_infer_source_root_single_root_test)
relative_path_test = unittest.make(_relative_path_test)
leaves_directory_test = unittest.make(_leaves_directory_test)
infer_source_root_nested_order_independent_test = unittest.make(_infer_source_root_nested_order_independent_test)
infer_source_root_nested_siblings_test = unittest.make(_infer_source_root_nested_siblings_test)
infer_source_root_mixed_depths_test = unittest.make(_infer_source_root_mixed_depths_test)
infer_source_root_beside_manifest_test = unittest.make(_infer_source_root_beside_manifest_test)
infer_source_root_nested_only_test = unittest.make(_infer_source_root_nested_only_test)
infer_source_root_empty_test = unittest.make(_infer_source_root_empty_test)
source_root_for_multiple_roots_test = unittest.make(_source_root_for_multiple_roots_test)
source_root_for_root_matching_test = unittest.make(_source_root_for_root_matching_test)
normalize_root_test = unittest.make(_normalize_root_test)
resolve_source_roots_test = unittest.make(_resolve_source_roots_test)

# Tests for find_local_license_paths, through the licence of protocol version 6

_LINUX_HOME = "/home/dev"
_MAC_HOME = "/Users/dev"
_WINDOWS_APPDATA = "C:\\Users\\dev\\AppData\\Roaming"
_WINDOWS_LOCALAPPDATA = "C:\\Users\\dev\\AppData\\Local"

def _fake_repository_ctx(os_name, existing, home = _LINUX_HOME, appdata = _WINDOWS_APPDATA, **extra_environ):
    """Builds a stand-in for a repository ctx that only knows about `existing` paths.

    Passing None for `home` or `appdata` leaves that variable out of the
    environment entirely, modelling an unset variable rather than an empty one.
    """
    environ = {}
    if appdata != None:
        environ["APPDATA"] = appdata
    if home != None:
        environ["HOME"] = home
    environ.update(extra_environ)

    return struct(
        os = struct(
            name = os_name,
            environ = environ,
        ),
        existing = existing,
    )

def _fake_list_directory(ctx, directory):
    """The names of the `existing` paths directly inside `directory`."""
    names = []
    for path in ctx.existing:
        if path.startswith(directory) and path[len(directory):len(directory) + 1] in ["/", "\\"]:
            name = path[len(directory) + 1:]
            if "/" not in name and "\\" not in name:
                names.append(name)
    return names

def _find_license_6(fake):
    return find_local_license_paths(fake, _fake_list_directory).get("licenses_6.lic")

def _local_license_suffixed_linux_test(ctx):
    """The default local_user case: a Popili license under $HOME is found."""
    env = unittest.begin(ctx)

    license = "%s/.local/share/popili/licenses_6.lic" % _LINUX_HOME
    fake = _fake_repository_ctx("linux", [license])

    asserts.equals(env, license, _find_license_6(fake))

    return unittest.end(env)

def _local_license_suffixed_mac_test(ctx):
    env = unittest.begin(ctx)

    license = "%s/Library/Application Support/Popili/licenses_6.lic" % _MAC_HOME
    fake = _fake_repository_ctx("mac os x", [license], home = _MAC_HOME)

    asserts.equals(env, license, _find_license_6(fake))

    return unittest.end(env)

def _local_license_suffixed_windows_test(ctx):
    env = unittest.begin(ctx)

    license = "%s\\..\\Local\\Popili\\licenses_6.lic" % _WINDOWS_APPDATA
    fake = _fake_repository_ctx("windows 10", [license])

    asserts.equals(env, license, _find_license_6(fake))

    return unittest.end(env)

def _local_license_legacy_fallback_test(ctx):
    """With no Popili license installed, the legacy Coco Platform path is used."""
    env = unittest.begin(ctx)

    license = "%s/.local/share/coco_platform/licenses_6.lic" % _LINUX_HOME
    fake = _fake_repository_ctx("linux", [license])

    asserts.equals(env, license, _find_license_6(fake))

    return unittest.end(env)

def _local_license_prefers_popili_over_legacy_test(ctx):
    env = unittest.begin(ctx)

    popili = "%s/.local/share/popili/licenses_6.lic" % _LINUX_HOME
    legacy = "%s/.local/share/coco_platform/licenses_6.lic" % _LINUX_HOME
    fake = _fake_repository_ctx("linux", [legacy, popili])

    asserts.equals(env, popili, _find_license_6(fake))

    return unittest.end(env)

def _local_license_absent_test(ctx):
    """With nothing installed the caller gets None, and emits the empty stub."""
    env = unittest.begin(ctx)

    fake = _fake_repository_ctx("linux", [])

    asserts.equals(env, None, _find_license_6(fake))

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

    asserts.equals(env, None, _find_license_6(fake))

    return unittest.end(env)

def _local_license_empty_home_test(ctx):
    """An empty $HOME is treated as unset rather than as the filesystem root."""
    env = unittest.begin(ctx)

    degenerate = "/.local/share/popili/licenses_6.lic"
    fake = _fake_repository_ctx("linux", [degenerate], home = "")

    asserts.equals(env, None, _find_license_6(fake))

    return unittest.end(env)

def _local_license_unset_appdata_windows_test(ctx):
    """On Windows the anchor is %APPDATA%, so a set $HOME must not rescue it."""
    env = unittest.begin(ctx)

    degenerate = "None\\..\\Local\\Popili\\licenses_6.lic"
    fake = _fake_repository_ctx("windows 10", [degenerate], appdata = None)

    asserts.equals(env, None, _find_license_6(fake))

    return unittest.end(env)

def _local_license_unset_appdata_ignored_off_windows_test(ctx):
    """Off Windows %APPDATA% is irrelevant, so an unset one must not block the probe."""
    env = unittest.begin(ctx)

    license = "%s/.local/share/popili/licenses_6.lic" % _LINUX_HOME
    fake = _fake_repository_ctx("linux", [license], appdata = None)

    asserts.equals(env, license, _find_license_6(fake))

    return unittest.end(env)

def _local_license_windows_localappdata_test(ctx):
    """On Windows popili uses %LOCALAPPDATA%."""
    env = unittest.begin(ctx)

    license = "%s\\Popili\\licenses_6.lic" % _WINDOWS_LOCALAPPDATA
    fake = _fake_repository_ctx("windows 10", [license], LOCALAPPDATA = _WINDOWS_LOCALAPPDATA)

    asserts.equals(env, license, _find_license_6(fake))

    return unittest.end(env)

def _local_license_xdg_data_home_test(ctx):
    """$XDG_DATA_HOME is honoured on Linux."""
    env = unittest.begin(ctx)

    license = "/xdg/popili/licenses_6.lic"
    shadowed = "%s/.local/share/popili/licenses_6.lic" % _LINUX_HOME
    fake = _fake_repository_ctx("linux", [shadowed, license], XDG_DATA_HOME = "/xdg")

    asserts.equals(env, license, _find_license_6(fake))

    return unittest.end(env)

def _local_license_popili_data_test(ctx):
    """$POPILI_DATA replaces the per-user directories."""
    env = unittest.begin(ctx)

    license = "/data/licenses_6.lic"
    shadowed = "%s/.local/share/popili/licenses_6.lic" % _LINUX_HOME
    fake = _fake_repository_ctx("linux", [shadowed, license], POPILI_DATA = "/data")

    asserts.equals(env, license, _find_license_6(fake))

    return unittest.end(env)

def _local_license_coco_platform_data_test(ctx):
    """$COCO_PLATFORM_DATA is honoured too, below $POPILI_DATA."""
    env = unittest.begin(ctx)

    license = "/legacy/licenses_6.lic"
    fake = _fake_repository_ctx("linux", [license], COCO_PLATFORM_DATA = "/legacy")

    asserts.equals(env, license, _find_license_6(fake))

    preferred = "/data/licenses_6.lic"
    fake = _fake_repository_ctx("linux", [license, preferred], COCO_PLATFORM_DATA = "/legacy", POPILI_DATA = "/data")

    asserts.equals(env, preferred, _find_license_6(fake))

    return unittest.end(env)

def _local_license_popili_data_windows_test(ctx):
    """On Windows the override is joined with a backslash."""
    env = unittest.begin(ctx)

    license = "D:\\data\\licenses_6.lic"
    fake = _fake_repository_ctx("windows 10", [license], POPILI_DATA = "D:\\data")

    asserts.equals(env, license, _find_license_6(fake))

    return unittest.end(env)

def _local_license_unset_home_mac_test(ctx):
    """An unset $HOME on macOS probes nothing either."""
    env = unittest.begin(ctx)

    degenerate = "None/Library/Application Support/Popili/licenses_6.lic"
    fake = _fake_repository_ctx("mac os x", [degenerate], home = None)

    asserts.equals(env, None, _find_license_6(fake))

    return unittest.end(env)

local_license_suffixed_linux_test = unittest.make(_local_license_suffixed_linux_test)
local_license_suffixed_mac_test = unittest.make(_local_license_suffixed_mac_test)
local_license_suffixed_windows_test = unittest.make(_local_license_suffixed_windows_test)
local_license_legacy_fallback_test = unittest.make(_local_license_legacy_fallback_test)
local_license_prefers_popili_over_legacy_test = unittest.make(_local_license_prefers_popili_over_legacy_test)
local_license_absent_test = unittest.make(_local_license_absent_test)
local_license_unset_home_test = unittest.make(_local_license_unset_home_test)
local_license_empty_home_test = unittest.make(_local_license_empty_home_test)
local_license_unset_appdata_windows_test = unittest.make(_local_license_unset_appdata_windows_test)
local_license_unset_appdata_ignored_off_windows_test = unittest.make(_local_license_unset_appdata_ignored_off_windows_test)
local_license_windows_localappdata_test = unittest.make(_local_license_windows_localappdata_test)
local_license_xdg_data_home_test = unittest.make(_local_license_xdg_data_home_test)
local_license_popili_data_test = unittest.make(_local_license_popili_data_test)
local_license_coco_platform_data_test = unittest.make(_local_license_coco_platform_data_test)
local_license_popili_data_windows_test = unittest.make(_local_license_popili_data_windows_test)
local_license_unset_home_mac_test = unittest.make(_local_license_unset_home_mac_test)

# Tests for license_protocol_version

def _license_protocol_known_versions_test(ctx):
    """1.5 reads protocol version 6, the first two 1.6.0 betas 8, beta.3 9."""
    env = unittest.begin(ctx)

    for version, expected in [
        ("1.5.0-beta.1", 6),
        ("1.5.0-rc.1", 6),
        ("1.5.0", 6),
        ("1.5.8", 6),
        ("1.6.0-beta.1", 8),
        ("1.6.0-beta.2", 8),
        ("1.6.0-beta.3", 9),
    ]:
        asserts.equals(env, expected, license_protocol_version(version), version)

    return unittest.end(env)

def _license_protocol_newer_than_known_test(ctx):
    """Versions newer than every entry get the newest protocol version."""
    env = unittest.begin(ctx)

    for version in ["1.6.0-beta.4", "1.6.0-beta.10", "1.6.0-rc.1", "1.6.0", "1.6.1", "1.7.0", "1.99.0", "2.0"]:
        asserts.equals(env, 9, license_protocol_version(version), version)

    return unittest.end(env)

def _license_protocol_unknown_test(ctx):
    """The local toolchain gets the newest protocol version; older versions the oldest."""
    env = unittest.begin(ctx)

    asserts.equals(env, 9, license_protocol_version("local"))
    for version in ["1.4.9", "1.5.0-alpha.1"]:
        asserts.equals(env, 6, license_protocol_version(version), version)

    return unittest.end(env)

def _license_protocol_custom_table_test(ctx):
    """The lookup follows the table it is given."""
    env = unittest.begin(ctx)

    table = {"1.5.0": 6, "1.6.0": 11, "1.6.1": 10}
    asserts.equals(env, 11, license_protocol_version("1.6.0", table))
    asserts.equals(env, 10, license_protocol_version("1.7.0", table))
    asserts.equals(env, 10, license_protocol_version("local", table))
    asserts.equals(env, 6, license_protocol_version("1.6.0-beta.3", table))

    return unittest.end(env)

def _license_protocol_table_sorted_test(ctx):
    """LICENSE_PROTOCOL_VERSIONS lists its versions in ascending order, as the lookup requires."""
    env = unittest.begin(ctx)

    versions = LICENSE_PROTOCOL_VERSIONS.keys()
    for version in versions:
        asserts.true(env, version_key(version) != None, "%s is not a version" % version)
    asserts.equals(env, sorted(versions, key = version_key), versions)

    return unittest.end(env)

def _local_license_paths_by_protocol_test(ctx):
    """Every licenses_<n>.lic is found, whatever n, Popili paths before legacy ones."""
    env = unittest.begin(ctx)

    popili = "%s/.local/share/popili/" % _LINUX_HOME
    legacy = "%s/.local/share/coco_platform/" % _LINUX_HOME
    fake = _fake_repository_ctx("linux", [
        legacy + "licenses_8.lic",
        popili + "licenses_8.lic",
        legacy + "licenses_6.lic",
        popili + "licenses_10.lic",
        popili + "licenses.lic",
        popili + "licenses_x.lic",
        popili + "preferences.toml",
    ])

    asserts.equals(
        env,
        {
            "licenses_10.lic": popili + "licenses_10.lic",
            "licenses_6.lic": legacy + "licenses_6.lic",
            "licenses_8.lic": popili + "licenses_8.lic",
        },
        find_local_license_paths(fake, _fake_list_directory),
    )

    return unittest.end(env)

def _local_license_paths_mac_test(ctx):
    """macOS, Coco Platform directory, files of protocol versions 6, 8 and 9."""
    env = unittest.begin(ctx)

    files = {
        "licenses_%d.lic" % protocol: "%s/Library/Application Support/Coco Platform/licenses_%d.lic" % (_MAC_HOME, protocol)
        for protocol in [6, 8, 9]
    }
    fake = _fake_repository_ctx("mac os x", files.values(), home = _MAC_HOME)

    asserts.equals(env, files, find_local_license_paths(fake, _fake_list_directory))

    return unittest.end(env)

def _local_license_paths_data_dir_test(ctx):
    """$POPILI_DATA replaces the per-user directories for every protocol version."""
    env = unittest.begin(ctx)

    shadowed = "%s/.local/share/popili/licenses_9.lic" % _LINUX_HOME
    fake = _fake_repository_ctx("linux", [shadowed, "/data/licenses_9.lic"], POPILI_DATA = "/data")

    asserts.equals(env, {"licenses_9.lic": "/data/licenses_9.lic"}, find_local_license_paths(fake, _fake_list_directory))

    return unittest.end(env)

def _local_license_paths_absent_test(ctx):
    env = unittest.begin(ctx)

    fake = _fake_repository_ctx("linux", ["%s/.local/share/popili/licenses.lic" % _LINUX_HOME])

    asserts.equals(env, {}, find_local_license_paths(fake, _fake_list_directory))

    return unittest.end(env)

def _license_file_name_test(ctx):
    """Only licenses_<n>.lic, n a positive number without leading zeros, is a license file."""
    env = unittest.begin(ctx)

    for name in ["licenses_6.lic", "licenses_10.lic", "licenses_123.lic"]:
        asserts.true(env, is_license_file_name(name), name)
    for name in ["licenses.lic", "licenses_.lic", "licenses_0.lic", "licenses_07.lic", "licenses_x.lic", "licenses_6.lic.bak", "license_6.lic"]:
        asserts.false(env, is_license_file_name(name), name)

    return unittest.end(env)

license_protocol_known_versions_test = unittest.make(_license_protocol_known_versions_test)
license_protocol_newer_than_known_test = unittest.make(_license_protocol_newer_than_known_test)
license_protocol_unknown_test = unittest.make(_license_protocol_unknown_test)
license_protocol_custom_table_test = unittest.make(_license_protocol_custom_table_test)
license_protocol_table_sorted_test = unittest.make(_license_protocol_table_sorted_test)
local_license_paths_by_protocol_test = unittest.make(_local_license_paths_by_protocol_test)
local_license_paths_mac_test = unittest.make(_local_license_paths_mac_test)
local_license_paths_data_dir_test = unittest.make(_local_license_paths_data_dir_test)
local_license_paths_absent_test = unittest.make(_local_license_paths_absent_test)
license_file_name_test = unittest.make(_license_file_name_test)

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

def _coco_download_runtime_test(ctx):
    """Runtime archives are verified against known_shas.bzl, and unknown versions go unverified."""
    env = unittest.begin(ctx)

    for archive in ["coco-cpp-runtime.zip", "coco-c-runtime.zip"]:
        download = coco_download("1.5.7", archive)
        asserts.equals(env, "https://dl.cocotec.io/popili/archive/1.5.7/" + archive, download.url)
        asserts.equals(env, FILE_KEY_TO_SHA["1.5.7/" + archive], download.sha256)

        download = coco_download("9.9.9", archive)
        asserts.equals(env, "https://dl.cocotec.io/popili/archive/9.9.9/" + archive, download.url)
        asserts.equals(env, "", download.sha256)

    return unittest.end(env)

coco_toolchain_download_url_test = unittest.make(_coco_toolchain_download_url_test)
coco_toolchain_download_sha_matches_known_shas_test = unittest.make(_coco_toolchain_download_sha_matches_known_shas_test)
coco_toolchain_download_all_platforms_verified_test = unittest.make(_coco_toolchain_download_all_platforms_verified_test)
coco_toolchain_download_version_aliases_verified_test = unittest.make(_coco_toolchain_download_version_aliases_verified_test)
coco_toolchain_download_prerelease_test = unittest.make(_coco_toolchain_download_prerelease_test)
coco_toolchain_download_unknown_version_test = unittest.make(_coco_toolchain_download_unknown_version_test)
coco_toolchain_download_covers_every_platform_test = unittest.make(_coco_toolchain_download_covers_every_platform_test)
coco_download_runtime_test = unittest.make(_coco_download_runtime_test)

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

def _version_key_test(ctx):
    """Versions sort by semantic versioning precedence; anything else has no key."""
    env = unittest.begin(ctx)

    ascending = [
        "1.5.0-alpha.1",
        "1.5.0-beta.2",
        "1.5.0-beta.10",
        "1.5.0-beta.rc",
        "1.5.0-rc.1",
        "1.5.0",
        "1.5.8",
        "1.6.0-beta.1",
        "1.6.0",
        "2.0.0",
    ]
    for older, newer in zip(ascending, ascending[1:]):
        asserts.true(env, version_key(older) < version_key(newer), "%s < %s" % (older, newer))
    asserts.equals(env, version_key("1.6.0-beta.3"), version_key("1.6.0-beta.3"))
    for not_a_version in ["stable", "local", "", "1.x"]:
        asserts.equals(env, None, version_key(not_a_version))

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
version_key_test = unittest.make(_version_key_test)
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

# Tests for missing_popili_message

_REGISTRY = struct(versions = ["1.5.0", "1.5.1"])
_REGISTRY_WITH_LOCAL = struct(versions = ["1.5.0", "1.5.1", "local"])
_REGISTRY_LOCAL_ONLY = struct(versions = ["local"])

def _assert_mentions(env, message, fragments, absent = []):
    for fragment in fragments:
        asserts.true(env, fragment in message, "expected %r in message: %s" % (fragment, message))
    for fragment in absent:
        asserts.false(env, fragment in message, "did not expect %r in message: %s" % (fragment, message))

def _missing_popili_unregistered_version_test(ctx):
    """A version nobody registered: lists the registered versions, the default and how to register more."""
    env = unittest.begin(ctx)
    message = missing_popili_message("//a:gen", "1.99.0", _REGISTRY)
    _assert_mentions(
        env,
        message,
        [
            "//a:gen needs popili 1.99.0 (set by --@rules_coco//:version)",
            "no registered Coco toolchain provides it",
            "Registered popili versions: 1.5.0 (the default), 1.5.1.",
            "coco.toolchain(versions = [...])",
            "coco_repositories(versions = [...])",
        ],
        absent = ["execution platform", "target_settings"],
    )
    return unittest.end(env)

def _missing_popili_local_unregistered_test(ctx):
    """`local` without a local toolchain: says how to register one."""
    env = unittest.begin(ctx)
    message = missing_popili_message("//a:gen", "local", _REGISTRY)
    _assert_mentions(
        env,
        message,
        [
            "//a:gen needs the local popili (set by --@rules_coco//:version)",
            "no local Coco toolchain is registered",
            "Registered popili versions: 1.5.0 (the default), 1.5.1.",
            "coco.local_toolchain(popili = ...)",
            "coco_local_repositories(path = ...)",
            "coco_repositories(local_popili = ...)",
        ],
        absent = ["target_settings", "execution platform"],
    )
    return unittest.end(env)

def _missing_popili_no_execution_platform_test(ctx):
    """A registered version with no popili for any execution platform: says to register one popili is available for."""
    env = unittest.begin(ctx)
    message = missing_popili_message("//a:gen", "1.5.1", _REGISTRY)
    _assert_mentions(
        env,
        message,
        [
            "//a:gen needs popili 1.5.1 (set by --@rules_coco//:version), which is registered",
            "none of the registered execution platforms can run it",
            "Register an execution platform popili is available for (--extra_execution_platforms)",
            "Registered popili versions: 1.5.0 (the default), 1.5.1.",
        ],
        absent = ["target_settings", "coco.toolchain(versions"],
    )

    # The default is worded as the version it stands for.
    message = missing_popili_message("//a:gen", "", _REGISTRY)
    _assert_mentions(env, message, ["//a:gen needs popili 1.5.0 (the default), which is registered"])
    return unittest.end(env)

def _missing_popili_local_off_host_test(ctx):
    """`local` is registered but only for the host, which is not an execution platform."""
    env = unittest.begin(ctx)
    message = missing_popili_message("//a:gen", "local", _REGISTRY_WITH_LOCAL)
    _assert_mentions(
        env,
        message,
        [
            "//a:gen needs the local popili (set by --@rules_coco//:version)",
            "only runs on the host and no registered execution platform is the host",
            "--extra_execution_platforms=@platforms//host",
            "Registered popili versions: 1.5.0 (the default), 1.5.1, local.",
        ],
        absent = ["no local Coco toolchain is registered", "coco.local_toolchain"],
    )
    return unittest.end(env)

def _missing_popili_local_only_test(ctx):
    """A local-only registration has no default, and `local` is never called the default."""
    env = unittest.begin(ctx)
    message = missing_popili_message("//a:gen", "", _REGISTRY_LOCAL_ONLY)
    _assert_mentions(
        env,
        message,
        [
            "//a:gen needs the default popili version, but none is registered",
            "--@rules_coco//:version=local",
            "Registered popili versions: local.",
            "coco.toolchain(versions = [...])",
        ],
        absent = ["(the default)"],
    )

    message = missing_popili_message("//a:gen", "1.5.0", _REGISTRY_LOCAL_ONLY)
    _assert_mentions(
        env,
        message,
        ["//a:gen needs popili 1.5.0 (set by --@rules_coco//:version), but no registered Coco toolchain provides it", "Registered popili versions: local."],
        absent = ["(the default)"],
    )
    return unittest.end(env)

def _missing_popili_empty_registry_test(ctx):
    """Nothing registered at all still words a message rather than failing on an empty list."""
    env = unittest.begin(ctx)
    registry = struct(versions = [])
    message = missing_popili_message("//a:gen", "", registry)
    _assert_mentions(env, message, ["none is registered", "Registered popili versions: none."])
    message = missing_popili_message("//a:gen", "1.5.0", registry)
    _assert_mentions(env, message, ["no registered Coco toolchain provides it", "Registered popili versions: none."])
    return unittest.end(env)

def _missing_popili_alias_test(ctx):
    """An alias on the flag: says to pass the version it stands for, which the flag matches."""
    env = unittest.begin(ctx)
    stable = VERSION_ALIASES["stable"]
    registry = struct(versions = [stable])
    message = missing_popili_message("//a:gen", "stable", registry)
    _assert_mentions(
        env,
        message,
        [
            "//a:gen needs popili stable (set by --@rules_coco//:version), but stable is an alias",
            "set it to %s" % stable,
            "Registered popili versions: %s (the default)." % stable,
        ],
        absent = ["no registered Coco toolchain provides it", "coco.toolchain(versions"],
    )

    # When the version it stands for is not registered either, say how to register it.
    message = missing_popili_message("//a:gen", "stable", _REGISTRY)
    _assert_mentions(env, message, ["set it to %s" % stable, "Register %s with coco.toolchain(versions = [...])" % stable])
    return unittest.end(env)

def _missing_popili_pinned_version_test(ctx):
    """A pin names the attribute as the source, and an alias pin is named as written."""
    env = unittest.begin(ctx)
    message = missing_popili_message("//a:gen", "1.99.0", _REGISTRY, source = version_source("1.99.0", "1.99.0"))
    _assert_mentions(
        env,
        message,
        ["//a:gen needs popili 1.99.0 (pinned by popili_version), but no registered Coco toolchain provides it"],
        absent = ["--@rules_coco//:version"],
    )
    stable = resolve_version_alias("stable")
    message = missing_popili_message("//a:gen", stable, _REGISTRY, source = version_source(stable, "stable"))
    _assert_mentions(env, message, ["//a:gen needs popili %s (pinned by popili_version = \"stable\"), but no registered" % stable])
    return unittest.end(env)

def _missing_popili_forced_test(ctx):
    """Forced, the flag is named whatever pin there is, and an empty flag is the forced default."""
    env = unittest.begin(ctx)
    message = missing_popili_message("//a:gen", "1.99.0", _REGISTRY, source = version_source("1.99.0", "1.5.0", [], forced = True))
    _assert_mentions(env, message, ["//a:gen needs popili 1.99.0 (forced by --@rules_coco//:force_version), but no registered"], absent = ["pinned"])
    message = missing_popili_message("//a:gen", "1.99.0", _REGISTRY, source = version_source("1.99.0", "", [], forced = True))
    _assert_mentions(env, message, ["//a:gen needs popili 1.99.0 (forced by --@rules_coco//:force_version), but no registered"])
    message = missing_popili_message("//a:gen", "", _REGISTRY, source = version_source("", "stable", [], forced = True))
    _assert_mentions(env, message, ["//a:gen needs popili 1.5.0 (the default, forced by --@rules_coco//:force_version)"])
    return unittest.end(env)

def _missing_popili_test_platform_test(ctx):
    """A test whose target platform no popili-capable execution platform matches says so."""
    env = unittest.begin(ctx)
    message = missing_popili_message("//a:verify", "1.5.1", _REGISTRY, test_target_platform = "//p:riscv64")
    _assert_mentions(
        env,
        message,
        [
            "//a:verify needs popili 1.5.1 (set by --@rules_coco//:version), which is registered",
            "matching the test's target platform (//p:riscv64)",
            "no registered execution platform both matches it and can run popili",
            "Build the test for a platform popili is available for",
            "Registered popili versions: 1.5.0 (the default), 1.5.1.",
        ],
        absent = ["none of the registered execution platforms can run it"],
    )

    message = missing_popili_message("//a:verify", "local", _REGISTRY_WITH_LOCAL, test_target_platform = "//p:rbe")
    _assert_mentions(
        env,
        message,
        [
            "//a:verify needs the local popili (set by --@rules_coco//:version), which only runs on the host,",
            "matching the test's target platform (//p:rbe)",
            "no registered execution platform both matches it and is the host",
            "--platforms=@platforms//host",
            "--extra_execution_platforms=@platforms//host",
        ],
        absent = ["no registered execution platform is the host"],
    )

    # The test's platform matters only once the version is known to be registered.
    message = missing_popili_message("//a:verify", "1.99.0", _REGISTRY, test_target_platform = "//p:riscv64")
    _assert_mentions(env, message, ["no registered Coco toolchain provides it"], absent = ["target platform"])
    message = missing_popili_message("//a:verify", "local", _REGISTRY, test_target_platform = "//p:riscv64")
    _assert_mentions(env, message, ["no local Coco toolchain is registered"], absent = ["target platform"])
    return unittest.end(env)

missing_popili_unregistered_version_test = unittest.make(_missing_popili_unregistered_version_test)
missing_popili_pinned_version_test = unittest.make(_missing_popili_pinned_version_test)
missing_popili_local_unregistered_test = unittest.make(_missing_popili_local_unregistered_test)
missing_popili_no_execution_platform_test = unittest.make(_missing_popili_no_execution_platform_test)
missing_popili_local_off_host_test = unittest.make(_missing_popili_local_off_host_test)
missing_popili_local_only_test = unittest.make(_missing_popili_local_only_test)
missing_popili_empty_registry_test = unittest.make(_missing_popili_empty_registry_test)
missing_popili_alias_test = unittest.make(_missing_popili_alias_test)
missing_popili_test_platform_test = unittest.make(_missing_popili_test_platform_test)
missing_popili_forced_test = unittest.make(_missing_popili_forced_test)

def _version_source_test(ctx):
    """pinned_from tells a pin above the target from the flag; a rule that cannot read it names both."""
    env = unittest.begin(ctx)
    asserts.equals(env, "pinned by popili_version", version_source("1.99.0", "1.99.0", [""]))
    asserts.equals(env, "pinned by popili_version = \"stable\"", version_source("1.5.1", "stable", []))
    asserts.equals(env, "pinned by a target above it", version_source("1.99.0", "", [""]))
    asserts.equals(env, "pinned by a target above it", version_source("1.99.0", "", ["1.5.0"]))
    asserts.equals(env, "pinned by its popili_versions or a target above it", version_source("1.99.0", "", ["1.5.0"], self_pin = True))
    asserts.equals(env, "set by --@rules_coco//:version", version_source("1.99.0", "", []))
    asserts.equals(env, "set by --@rules_coco//:version or a popili_version pin above it", version_source("1.99.0", ""))
    asserts.equals(env, "the default", version_source("", "", []))
    asserts.equals(env, "the default", version_source("", ""))
    return unittest.end(env)

version_source_test = unittest.make(_version_source_test)

def _popili_rule_reserved_attribute_test(ctx):
    """popili_rule keeps the pin, the private attributes it adds and, when it adds one, `package` for itself."""
    env = unittest.begin(ctx)
    asserts.equals(env, None, popili_rule_reserved_attribute({}, False))
    asserts.equals(env, None, popili_rule_reserved_attribute({"flags": None, "package": None, "_backend": None}, False))
    asserts.equals(env, "package", popili_rule_reserved_attribute({"flags": None, "package": None}, True))
    asserts.equals(env, "popili_version", popili_rule_reserved_attribute({"popili_version": None}, False))
    asserts.equals(env, "_version", popili_rule_reserved_attribute({"_backend": None, "_version": None}, True))
    return unittest.end(env)

popili_rule_reserved_attribute_test = unittest.make(_popili_rule_reserved_attribute_test)

# Tests for effective_version and pin_transition_settings

def _effective_version_test(ctx):
    """The flag when set, else the first registered version unless it is local, else nothing."""
    env = unittest.begin(ctx)
    asserts.equals(env, "1.5.1", effective_version("1.5.1", ["1.5.0", "1.5.1"]))
    asserts.equals(env, "local", effective_version("local", ["1.5.0", "local"]))
    asserts.equals(env, "1.5.0", effective_version("", ["1.5.0", "1.5.1"]))
    asserts.equals(env, "1.5.0", effective_version("", ["1.5.0", "local"]))
    asserts.equals(env, "", effective_version("", ["local"]))
    asserts.equals(env, "", effective_version("", []))
    return unittest.end(env)

_REGISTERED = ["1.5.0", "1.5.1"]

_PINNED_FROM = str(Label("//coco/private:pinned_from"))

def _pinned(version, outer):
    return {VERSION_FLAG: version, _PINNED_FROM: [outer]}

def _pin_transition_settings_unpinned_test(ctx):
    """Without a pin the transition is a no-op, whatever the flag says, even an alias."""
    env = unittest.begin(ctx)
    asserts.equals(env, {}, pin_transition_settings("", "", _REGISTERED))
    asserts.equals(env, {}, pin_transition_settings("", "1.5.1", _REGISTERED))
    asserts.equals(env, {}, pin_transition_settings("", "stable", _REGISTERED))
    return unittest.end(env)

def _pin_transition_settings_pinned_test(ctx):
    """A pin sets the version flag, over the default and over a flag naming another version."""
    env = unittest.begin(ctx)
    asserts.equals(env, _pinned("1.5.1", ""), pin_transition_settings("1.5.1", "", _REGISTERED))
    asserts.equals(env, _pinned("1.5.1", "1.5.0"), pin_transition_settings("1.5.1", "1.5.0", _REGISTERED))
    asserts.equals(env, _pinned("1.5.1", "local"), pin_transition_settings("1.5.1", "local", _REGISTERED + ["local"]))
    return unittest.end(env)

def _pin_transition_settings_alias_test(ctx):
    """Aliases in a pin are resolved, so the flag never carries one; an alias on the flag is not."""
    env = unittest.begin(ctx)
    stable = resolve_version_alias("stable")
    asserts.equals(env, _pinned(stable, ""), pin_transition_settings("stable", "", _REGISTERED))
    asserts.equals(env, _pinned(stable, "stable"), pin_transition_settings("stable", "stable", [stable]))
    asserts.equals(env, {}, pin_transition_settings("stable", "", [stable]))
    return unittest.end(env)

def _pin_transition_settings_already_pinned_test(ctx):
    """A pin equal to the incoming flag changes nothing, so the configuration is shared."""
    env = unittest.begin(ctx)
    asserts.equals(env, {}, pin_transition_settings("1.5.1", "1.5.1", _REGISTERED))
    asserts.equals(env, {}, pin_transition_settings("stable", resolve_version_alias("stable"), _REGISTERED))
    return unittest.end(env)

def _pin_transition_settings_default_test(ctx):
    """A pin to the default without a flag shares the configuration; with no default it sets the flag."""
    env = unittest.begin(ctx)
    asserts.equals(env, {}, pin_transition_settings("1.5.0", "", _REGISTERED))
    asserts.equals(env, _pinned("1.5.0", ""), pin_transition_settings("1.5.0", "", []))
    asserts.equals(env, _pinned("1.5.0", ""), pin_transition_settings("1.5.0", "", ["local", "1.5.0"]))

    # local is never the default, so a pin to it always sets the flag unless the flag says local.
    asserts.equals(env, _pinned("local", ""), pin_transition_settings("local", "", ["local"]))
    asserts.equals(env, {}, pin_transition_settings("local", "local", ["local"]))
    return unittest.end(env)

def _pin_transition_settings_nested_test(ctx):
    """A pin inside a pin keeps the outermost version; one back to it returns to that configuration."""
    env = unittest.begin(ctx)
    asserts.equals(env, {}, pin_transition_settings("1.5.1", "1.5.1", _REGISTERED, pinned_from = [""]))
    asserts.equals(env, _pinned("1.5.1", ""), pin_transition_settings("1.5.1", "local", _REGISTERED + ["local"], pinned_from = [""]))
    unpinned = {VERSION_FLAG: "", _PINNED_FROM: []}
    asserts.equals(env, unpinned, pin_transition_settings("1.5.0", "1.5.1", _REGISTERED, pinned_from = [""]))
    asserts.equals(env, {VERSION_FLAG: "1.5.0", _PINNED_FROM: []}, pin_transition_settings("1.5.0", "1.5.1", _REGISTERED, pinned_from = ["1.5.0"]))
    return unittest.end(env)

def _unpin_transition_settings_test(ctx):
    """Back to the version outside any pin; outside a pin, the configuration is left as it is."""
    env = unittest.begin(ctx)
    asserts.equals(env, {VERSION_FLAG: "", _PINNED_FROM: []}, unpin_transition_settings("1.5.1", [""]))
    asserts.equals(env, {VERSION_FLAG: "1.5.0", _PINNED_FROM: []}, unpin_transition_settings("1.5.1", ["1.5.0"]))
    asserts.equals(env, {VERSION_FLAG: "1.5.1", _PINNED_FROM: []}, unpin_transition_settings("1.5.1", []))
    return unittest.end(env)

def _pin_transition_settings_forced_test(ctx):
    """Forced, a pin changes nothing, whether the flag is set, empty, an alias or equal to the pin."""
    env = unittest.begin(ctx)
    asserts.equals(env, {}, pin_transition_settings("1.5.1", "", _REGISTERED, True))
    asserts.equals(env, {}, pin_transition_settings("1.5.1", "1.5.0", _REGISTERED, True))
    asserts.equals(env, {}, pin_transition_settings("1.5.1", "1.5.1", _REGISTERED, True))
    asserts.equals(env, {}, pin_transition_settings("stable", "1.5.0", _REGISTERED, True))
    asserts.equals(env, {}, pin_transition_settings("1.5.1", "stable", _REGISTERED, True))
    asserts.equals(env, {}, pin_transition_settings("", "1.5.0", _REGISTERED, True))
    return unittest.end(env)

# Tests for the package's own transition

def _package_transition_settings_test(ctx):
    """Nothing to do when the effective version satisfies the list, nothing is registered or forced; else the first registered entry."""
    env = unittest.begin(ctx)
    asserts.equals(env, {}, package_transition_settings([], "", _REGISTERED), "an empty list")
    asserts.equals(env, {}, package_transition_settings(["1.5.1", "1.5.0"], "", _REGISTERED), "the default is listed")
    asserts.equals(env, {}, package_transition_settings(["1.5.1"], "1.5.1", _REGISTERED), "the flag is listed")
    asserts.equals(env, {}, package_transition_settings(["1.5.1", "local"], "local", _REGISTERED + ["local"]), "local, listed")
    asserts.equals(env, _pinned("1.5.1", "local"), package_transition_settings(["1.5.1"], "local", _REGISTERED + ["local"]), "local, unlisted, like any version")
    asserts.equals(env, _pinned("1.5.1", "1.5.0"), package_transition_settings(["local", "1.5.1"], "1.5.0", _REGISTERED + ["local"]), "local is never picked, even listed first")
    asserts.equals(env, {}, package_transition_settings(["local"], "", _REGISTERED + ["local"]), "only local: the package says to select it")
    asserts.equals(env, {}, package_transition_settings(["1.99.0"], "", _REGISTERED), "none registered: the package says so")
    asserts.equals(env, {}, package_transition_settings(["1.5.1"], "", _REGISTERED, True), "forced")
    asserts.equals(env, {}, package_transition_settings(["1.5.1"], "stable", _REGISTERED), "an alias on the flag: the package fails like every target")
    asserts.equals(env, _pinned("1.5.1", ""), package_transition_settings(["1.99.0", "1.5.1"], "", _REGISTERED), "the first registered entry, aliases resolved")
    stable = resolve_version_alias("stable")
    asserts.equals(env, _pinned(stable, ""), package_transition_settings(["stable"], "", ["1.5.0", stable]), "an alias in the list")
    asserts.equals(env, {VERSION_FLAG: "", _PINNED_FROM: []}, package_transition_settings(["1.5.0"], "1.5.1", _REGISTERED, pinned_from = [""]), "beneath a pin to an unlisted version: back where the standalone build is")
    return unittest.end(env)

package_transition_settings_test = unittest.make(_package_transition_settings_test)

def _own_package_versions_message_test(ctx):
    """A listed version agrees; otherwise a bring-your-own toolchain or an unregistered list is named with its remedy, forced without one."""
    env = unittest.begin(ctx)
    own = own_package_versions_message
    asserts.equals(env, None, own("//a:pkg", "1.5.0", "the default", [], "1.5.0", "//tc", _REGISTRY), "an empty list is unconstrained")
    asserts.equals(env, None, own("//a:pkg", "1.5.0", "the default", ["1.5.0", "1.99.0"], "1.5.0", "//tc", _REGISTRY))
    asserts.equals(env, None, own("//a:pkg", "local", "set by --@rules_coco//:version", ["1.99.0", "local"], "local", "//tc", _REGISTRY), "local, listed")
    asserts.equals(
        env,
        "//a:pkg gets popili 1.5.0 (forced by --@rules_coco//:force_version), which its popili_versions do not list: 1.99.0.",
        own("//a:pkg", "1.5.0", "forced by --@rules_coco//:force_version", ["1.99.0"], "1.5.0", "//tc", _REGISTRY, forced = True),
        "forced, the package warns, so no remedy",
    )
    asserts.equals(
        env,
        "//a:pkg gets popili 1.6.0 from the bring-your-own coco_toolchain //tc, which serves every target, but its " +
        "popili_versions do not list it: 1.5.1. Add 1.6.0 to its popili_versions, or bring a toolchain of one of those versions.",
        own("//a:pkg", "1.6.0", "pinned by its popili_versions or a target above it", ["1.5.1"], "1.5.1", "//tc", _REGISTRY),
        "bring-your-own, also where its own transition pinned a registered version",
    )
    asserts.equals(
        env,
        "None of //a:pkg's popili_versions (1.99.0, 1.98.0) is registered, so it gets popili 1.5.0 (the default), which it does not list. " +
        "Registered popili versions: 1.5.0 (the default), 1.5.1. Add 1.5.0 to its popili_versions, or register one of 1.99.0, 1.98.0 " +
        "with coco.toolchain(versions = [...]) in MODULE.bazel or coco_repositories(versions = [...]) in WORKSPACE.",
        own("//a:pkg", "1.5.0", "the default", ["1.99.0", "1.98.0"], "1.5.0", "//tc", _REGISTRY),
    )
    asserts.equals(
        env,
        "No release among //a:pkg's popili_versions (local) is registered, and the local popili is only ever selected explicitly, " +
        "so it gets popili 1.5.0 (the default), which it does not list. Registered popili versions: 1.5.0 (the default), 1.5.1, local. " +
        "Select the local popili with --@rules_coco//:version=local or a popili_version pin above it, or add 1.5.0 to its popili_versions.",
        own("//a:pkg", "1.5.0", "the default", ["local"], "1.5.0", "//tc", _REGISTRY_WITH_LOCAL),
        "only local, registered",
    )
    _assert_mentions(
        env,
        own("//a:pkg", "1.5.0", "the default", ["local"], "1.5.0", "//tc", _REGISTRY),
        ["None of //a:pkg's popili_versions (local) is registered", "or register a popili distribution from the local filesystem with coco.local_toolchain"],
        absent = ["coco.toolchain(versions"],
    )
    _assert_mentions(
        env,
        own("//a:pkg", "1.5.8", "the default", ["1.6.0"], "", "//tc", struct(versions = [])),
        ["from the bring-your-own coco_toolchain //tc"],
        absent = ["register"],
    )
    asserts.equals(
        env,
        "//a:pkg gets popili 1.5.1 (the default), which the popili_versions it inherits from its workspace //a:ws do not list: 1.5.0. " +
        "Build it beneath a target pinned to one of those, set --@rules_coco//:version to one, or write the list " +
        "on the package itself, which then builds with the first registered one.",
        own("//a:pkg", "1.5.1", "the default", ["1.5.0"], "1.5.1", "//tc", _REGISTRY, inherited_from = "//a:ws"),
        "a list inherited from its workspace, which does not steer the build",
    )
    _assert_mentions(
        env,
        own("//a:pkg", "1.5.3", "the default", ["1.5.0"], "1.5.3", "//tc", _REGISTRY, inherited_from = "//a:ws"),
        ["Add 1.5.3 to the popili_versions it inherits from its workspace //a:ws, or bring"],
        absent = ["to its popili_versions"],
    )
    asserts.equals(
        env,
        "//a:pkg gets popili 1.5.1 (forced by --@rules_coco//:force_version), which the popili_versions it inherits from its workspace //a:ws do not list: 1.5.0.",
        own("//a:pkg", "1.5.1", "forced by --@rules_coco//:force_version", ["1.5.0"], "1.5.1", "//tc", _REGISTRY, forced = True, inherited_from = "//a:ws"),
        "forced, the warning names the workspace too",
    )
    return unittest.end(env)

own_package_versions_message_test = unittest.make(_own_package_versions_message_test)

# Tests for library_version_mismatch_message

def _library_version_mismatch_pinned_test(ctx):
    """A library pinned over a generator pinned elsewhere: both versions, and every way out."""
    env = unittest.begin(ctx)
    message = library_version_mismatch_message("//a:lib", "1.5.0", "pinned by popili_version", "//a:gen", "1.5.1")
    asserts.equals(
        env,
        "//a:lib links the Coco runtime of popili 1.5.0 (pinned by popili_version), but builds from //a:gen, " +
        "generated by popili 1.5.1. A library and the code it builds from must come from the same popili version: " +
        "give //a:lib popili_version = \"1.5.1\", or pin //a:gen to 1.5.0, or leave //a:gen unpinned so that it " +
        "follows the library.",
        message,
    )
    return unittest.end(env)

def _library_version_mismatch_unpinned_test(ctx):
    """An unpinned library says where its version came from and is told to take the generator's."""
    env = unittest.begin(ctx)
    message = library_version_mismatch_message("//a:lib", "1.5.0", "the default", "//a:gen", "1.5.1")
    asserts.true(env, "runtime of popili 1.5.0 (the default)" in message, message)
    asserts.true(env, "give //a:lib popili_version = \"1.5.1\"" in message, message)
    message = library_version_mismatch_message("//a:lib", "1.5.1", "set by --@rules_coco//:version or a popili_version pin above it", "//a:gen", "1.5.0")
    asserts.true(env, "runtime of popili 1.5.1 (set by --@rules_coco//:version or a popili_version pin above it)" in message, message)
    asserts.true(env, "pin //a:gen to 1.5.1" in message, message)
    return unittest.end(env)

def _library_version_conflict_agree_test(ctx):
    """Generators at the library's version agree with it."""
    env = unittest.begin(ctx)
    asserts.equals(env, None, library_version_conflict("//a:lib", "1.5.0", "the default", [("//a:g1", "1.5.0"), ("//a:g2", "1.5.0")]))
    asserts.equals(env, None, library_version_conflict("//a:lib", "local", "the default", [("//a:g1", "local")]))
    asserts.equals(env, None, library_version_conflict("//a:lib", "1.5.0", "the default", []))
    return unittest.end(env)

def _library_version_conflict_library_test(ctx):
    """With a library version, the first generator at another version is named against the library."""
    env = unittest.begin(ctx)
    message = library_version_conflict("//a:lib", "1.5.0", "the default", [("//a:g1", "1.5.0"), ("//a:g2", "1.5.1"), ("//a:g3", "1.5.2")])
    asserts.equals(env, library_version_mismatch_message("//a:lib", "1.5.0", "the default", "//a:g2", "1.5.1"), message)
    return unittest.end(env)

# Tests for the check of the popili a target runs against its package's popili_versions

def _package_versions_conflict_test(ctx):
    """An empty list or a listed version agree, local only when listed; anything else is named with a remedy, except forced."""
    env = unittest.begin(ctx)
    asserts.equals(env, None, package_versions_conflict("//a:gen", "1.5.1", "the default", "//a:pkg", []), "an empty list is unconstrained")
    asserts.equals(env, None, package_versions_conflict("//a:gen", "1.5.1", "the default", "//a:pkg", ["1.5.0", "1.5.1"]))
    asserts.equals(env, None, package_versions_conflict("//a:gen", "local", "set by --@rules_coco//:version", "//a:pkg", ["1.5.0", "local"]), "local, listed")
    asserts.equals(
        env,
        "//a:gen runs the local popili (set by --@rules_coco//:version) on //a:pkg, whose popili_versions do not list it: 1.5.0. " +
        "Pin //a:gen to one of those with popili_version, or add local to the popili_versions of //a:pkg.",
        package_versions_conflict("//a:gen", "local", "set by --@rules_coco//:version", "//a:pkg", ["1.5.0"]),
        "local, unlisted",
    )
    asserts.equals(
        env,
        "//a:gen runs popili 1.5.1 (pinned by popili_version) on //a:pkg, whose popili_versions do not list it: 1.5.0, 1.5.2. " +
        "Pin //a:gen to one of those with popili_version, or add 1.5.1 to the popili_versions of //a:pkg.",
        package_versions_conflict("//a:gen", "1.5.1", "pinned by popili_version", "//a:pkg", ["1.5.0", "1.5.2"]),
    )
    _assert_mentions(
        env,
        package_versions_conflict("//a:gen", "1.5.1", "pinned by a target above it", "//a:pkg", ["1.5.0"], pinned_above = True),
        ["Change the popili_version pin above //a:gen to one of those, or add 1.5.1"],
        absent = ["Pin //a:gen"],
    )
    asserts.equals(
        env,
        "//a:pkg gets popili 1.5.1 (the default), but the popili_versions of its dep //b:pkg do not list it: 1.5.0. " +
        "Make the popili_versions of //a:pkg list only versions //b:pkg lists too, or add 1.5.1 to the popili_versions of //b:pkg.",
        package_versions_conflict("//a:pkg", "1.5.1", "the default", "//b:pkg", ["1.5.0"], of_dep = True),
        "a dep's list",
    )
    _assert_mentions(
        env,
        package_versions_conflict("//a:pkg", "1.5.1", "pinned by its popili_versions or a target above it", "//b:pkg", ["1.5.8"], of_dep = True, common = "1.5.8"),
        ["Build //a:pkg with 1.5.8, which its popili_versions and those of its deps all list, by listing it first and leaving 1.5.1 out of its popili_versions, or by selecting it"],
    )
    asserts.equals(env, "1.5.0", common_version(["local", "1.99.0", "1.5.1", "1.5.0"], [["1.5.0"], []], _REGISTRY.versions), "the first registered release every dep lists, never local")
    asserts.equals(env, None, common_version(["1.5.1"], [["1.5.0"]], _REGISTRY.versions), "none in common")
    asserts.equals(
        env,
        "//a:gen runs popili 1.5.1 (forced by --@rules_coco//:force_version) on //a:pkg, whose popili_versions do not list it: 1.5.0.",
        package_versions_conflict("//a:gen", "1.5.1", "forced by --@rules_coco//:force_version", "//a:pkg", ["1.5.0"], forced = True),
        "forced, the caller warns, so no remedy",
    )
    return unittest.end(env)

package_versions_conflict_test = unittest.make(_package_versions_conflict_test)

def _inherited_versions_conflict_test(ctx):
    """An own list may add to the workspace's, never leave one of its versions out; an empty list inherits."""
    env = unittest.begin(ctx)
    asserts.equals(env, None, inherited_versions_conflict("//a:pkg", [], ["1.5.0"], "//a:ws", "workspace"), "inherits")
    asserts.equals(env, None, inherited_versions_conflict("//a:pkg", ["1.5.0"], [], "//a:ws", "workspace"), "an unconstrained workspace")
    asserts.equals(env, None, inherited_versions_conflict("//a:pkg", ["1.5.1", "1.5.0"], ["1.5.0"], "//a:ws", "workspace"), "more than the workspace")
    asserts.equals(
        env,
        "//a:inner's popili_versions (1.5.1) leave out 1.5.0, 1.4.0, which its parent //a:outer claims for every member package: 1.5.0, 1.5.1, 1.4.0. " +
        "A member may support more versions than its workspace, never fewer: add the missing ones, " +
        "sharing the list through a .bzl constant, or drop popili_versions to inherit them.",
        inherited_versions_conflict("//a:inner", ["1.5.1"], ["1.5.0", "1.5.1", "1.4.0"], "//a:outer", "parent"),
    )
    return unittest.end(env)

inherited_versions_conflict_test = unittest.make(_inherited_versions_conflict_test)

# Tests for the check of a bring-your-own toolchain's version against the version a target asks for

def _toolchain_version_mismatch_test(ctx):
    """Names the toolchain and both versions, and says which version pins and the flag may name."""
    env = unittest.begin(ctx)
    message = toolchain_version_mismatch_message("//a:gen", "1.5.1", version_source("1.5.1", "1.5.1", []), "//tools:byo_popili", "1.5.3")
    asserts.equals(
        env,
        "//a:gen needs popili 1.5.1 (pinned by popili_version), but the bring-your-own coco_toolchain " +
        "//tools:byo_popili, which serves every target, is popili 1.5.3. With a bring-your-own toolchain, " +
        "popili_version pins and --@rules_coco//:version must name 1.5.3 or be left out.",
        message,
    )
    return unittest.end(env)

toolchain_version_mismatch_test = unittest.make(_toolchain_version_mismatch_test)

library_version_conflict_agree_test = unittest.make(_library_version_conflict_agree_test)
library_version_conflict_library_test = unittest.make(_library_version_conflict_library_test)
library_version_mismatch_pinned_test = unittest.make(_library_version_mismatch_pinned_test)
library_version_mismatch_unpinned_test = unittest.make(_library_version_mismatch_unpinned_test)
effective_version_test = unittest.make(_effective_version_test)
pin_transition_settings_forced_test = unittest.make(_pin_transition_settings_forced_test)
pin_transition_settings_unpinned_test = unittest.make(_pin_transition_settings_unpinned_test)
pin_transition_settings_pinned_test = unittest.make(_pin_transition_settings_pinned_test)
pin_transition_settings_alias_test = unittest.make(_pin_transition_settings_alias_test)
pin_transition_settings_already_pinned_test = unittest.make(_pin_transition_settings_already_pinned_test)
pin_transition_settings_default_test = unittest.make(_pin_transition_settings_default_test)
pin_transition_settings_nested_test = unittest.make(_pin_transition_settings_nested_test)
unpin_transition_settings_test = unittest.make(_unpin_transition_settings_test)

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

    asserts.equals(env, "HOST_CONSTRAINTS", entries.exec_compatible_with["local"])

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

    asserts.equals(env, "HOST_CONSTRAINTS", entries.exec_compatible_with["local"])
    for (os, arch) in COCO_TOOLCHAIN_PLATFORMS:
        asserts.equals(
            env,
            ["@platforms//os:%s" % os, "@platforms//cpu:%s" % arch],
            entries.exec_compatible_with["%s_%s__1_5_7" % (os, arch)],
        )

    return unittest.end(env)

def _hub_unknown_version_test(ctx):
    """A version with no known_shas.bzl entry registers like any other (forward compatibility).

    Nothing on the way from the registration to the hub consults rules_coco's tables, so a
    release newer than this rules_coco gets its toolchains, default and config_setting.
    """
    env = unittest.begin(ctx)

    version = "1.99.0"
    asserts.false(
        env,
        any([key.startswith(version + "/") for key in FILE_KEY_TO_SHA]),
        "%s must be unknown to known_shas.bzl for this test to mean anything" % version,
    )

    versions, error = resolve_versions([version])
    asserts.equals(env, None, error)
    asserts.equals(env, [version], versions)

    entries = toolchain_hub_entries(versions)
    asserts.equals(env, 2 * len(COCO_TOOLCHAIN_PLATFORMS), len(entries.toolchain_names))
    asserts.equals(env, {version: "1_99_0"}, entries.version_suffixes)
    label = "@io_cocotec_coco_linux_x86_64__1_99_0//:toolchain_impl"
    asserts.equals(env, label, entries.toolchain_labels["linux_x86_64__1_99_0"])
    asserts.equals(env, label, entries.toolchain_labels["linux_x86_64__default"])
    asserts.equals(
        env,
        ["@coco_toolchains//:version_1_99_0"],
        entries.target_settings["linux_x86_64__1_99_0"],
    )

    asserts.equals(env, [version], entries.registered_versions)

    build = render_toolchain_hub_build(entries)
    asserts.true(
        env,
        '"@rules_coco//:version": "1.99.0"' in build,
        "version config_setting missing: %s" % build,
    )
    asserts.true(
        env,
        'toolchain = "%s"' % label in build,
        "toolchain for the unknown version missing: %s" % build,
    )
    asserts.true(
        env,
        'build_setting_default = ["1.99.0"]' in build,
        "registered_versions must list the unknown version: %s" % build,
    )

    return unittest.end(env)

def _hub_entries_registered_versions_test(ctx):
    """The registry lists the versions in registration order, then `local` when registered."""
    env = unittest.begin(ctx)

    entries = toolchain_hub_entries(["1.5.1", "1.5.0", "1.5.7"])
    asserts.equals(env, ["1.5.1", "1.5.0", "1.5.7"], entries.registered_versions)

    entries = toolchain_hub_entries(["1.5.1", "1.5.0"], has_local = True)
    asserts.equals(env, ["1.5.1", "1.5.0", "local"], entries.registered_versions)

    entries = toolchain_hub_entries([], has_local = True)
    asserts.equals(env, ["local"], entries.registered_versions)

    return unittest.end(env)

hub_entries_single_version_test = unittest.make(_hub_entries_single_version_test)
hub_entries_default_is_first_version_only_test = unittest.make(_hub_entries_default_is_first_version_only_test)
hub_entries_local_only_test = unittest.make(_hub_entries_local_only_test)
hub_entries_local_alongside_versions_test = unittest.make(_hub_entries_local_alongside_versions_test)
hub_unknown_version_test = unittest.make(_hub_unknown_version_test)
hub_entries_registered_versions_test = unittest.make(_hub_entries_registered_versions_test)

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

def _hub_build_loads_only_rules_coco_and_platforms_test(ctx):
    """The hub loads only rules_coco, and @platforms//host only for a local toolchain, so it stays loadable before skylib is fetched."""
    env = unittest.begin(ctx)

    for has_local in [False, True]:
        build = render_toolchain_hub_build(toolchain_hub_entries(["1.5.7"], has_local = has_local))

        loads = [line for line in build.splitlines() if line.startswith("load(")]
        asserts.true(env, len(loads) > 0, "hub BUILD must load the registry rules: %s" % build)
        for line in loads:
            asserts.true(
                env,
                line.startswith('load("@rules_coco//') or
                line == 'load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")',
                "hub BUILD may only load from rules_coco and @platforms//host: %s" % line,
            )
        asserts.true(env, "skylib" not in build, "hub BUILD must not depend on skylib: %s" % build)
        asserts.equals(
            env,
            has_local,
            "@platforms//host" in build,
            "hub BUILD must load @platforms//host only for a local toolchain: %s" % build,
        )

    return unittest.end(env)

def _hub_build_registry_test(ctx):
    """The rendered BUILD declares the registry and the registered_versions setting."""
    env = unittest.begin(ctx)

    build = render_toolchain_hub_build(toolchain_hub_entries(["1.5.1", "1.5.0"], has_local = True))

    asserts.true(
        env,
        'load("@rules_coco//coco/private:version_registry.bzl", "coco_registered_versions", "coco_version_registry")' in build,
        "registry load missing: %s" % build,
    )
    asserts.true(
        env,
        """coco_registered_versions(
    name = "registered_versions",
    build_setting_default = ["1.5.1", "1.5.0", "local"],
    visibility = ["//visibility:public"],
)""" in build,
        "registered_versions setting missing: %s" % build,
    )
    asserts.true(
        env,
        """coco_version_registry(
    name = "registry",
    registered_versions = ":registered_versions",
    visibility = ["//visibility:public"],
)""" in build,
        "registry target missing: %s" % build,
    )

    build = render_toolchain_hub_build(toolchain_hub_entries(["1.5.7"]))
    asserts.true(
        env,
        'build_setting_default = ["1.5.7"],' in build,
        "registered_versions must not list local when none is registered: %s" % build,
    )

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

def _hub_build_local_is_host_only_test(ctx):
    """The local toolchain() carries the host's constraints, as @platforms detects them."""
    env = unittest.begin(ctx)

    build = render_toolchain_hub_build(toolchain_hub_entries([], has_local = True))

    asserts.true(
        env,
        "exec_compatible_with = HOST_CONSTRAINTS," in build,
        "local toolchain must be constrained to the host: %s" % build,
    )

    return unittest.end(env)

hub_build_labels_test = unittest.make(_hub_build_labels_test)
hub_build_loads_only_rules_coco_and_platforms_test = unittest.make(_hub_build_loads_only_rules_coco_and_platforms_test)
hub_build_registry_test = unittest.make(_hub_build_registry_test)
hub_build_constrains_exec_only_test = unittest.make(_hub_build_constrains_exec_only_test)
hub_build_local_is_host_only_test = unittest.make(_hub_build_local_is_host_only_test)

# Tests for BUILD_for_coco_toolchain

def _toolchain_build_version_test(ctx):
    """A generated coco_toolchain records its version."""
    env = unittest.begin(ctx)

    # No line end after the attribute: the template's are the checkout's, CRLF on Windows.
    build = BUILD_for_coco_toolchain("toolchain", popili_version = "1.5.7")
    asserts.true(env, '\n    popili_version = "1.5.7",' in build, "version attribute missing: %s" % build)

    build = BUILD_for_coco_toolchain("toolchain", popili_version = "local")
    asserts.true(env, '\n    popili_version = "local",' in build, "local version missing: %s" % build)

    return unittest.end(env)

def _toolchain_build_license_protocol_version_test(ctx):
    """A coco_toolchain records a licence protocol version only when it is given one."""
    env = unittest.begin(ctx)

    build = BUILD_for_coco_toolchain("toolchain", popili_version = "local", license_protocol_version = 6)
    asserts.true(env, "\n    license_protocol_version = 6," in build, "protocol version missing: %s" % build)

    for unset in [None, 0]:
        build = BUILD_for_coco_toolchain("toolchain", popili_version = "local", license_protocol_version = unset)
        asserts.true(env, "license_protocol_version" not in build, "no protocol version expected: %s" % build)

    return unittest.end(env)

toolchain_build_version_test = unittest.make(_toolchain_build_version_test)
toolchain_build_license_protocol_version_test = unittest.make(_toolchain_build_license_protocol_version_test)

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

        # source_roots.bzl tests
        relative_path_test,
        leaves_directory_test,
        infer_source_root_single_root_test,
        infer_source_root_nested_order_independent_test,
        infer_source_root_nested_siblings_test,
        infer_source_root_mixed_depths_test,
        infer_source_root_beside_manifest_test,
        infer_source_root_nested_only_test,
        infer_source_root_empty_test,
        source_root_for_multiple_roots_test,
        source_root_for_root_matching_test,
        normalize_root_test,
        resolve_source_roots_test,

        # collect_cc_runtime_extra_deps tests
        cc_runtime_deps_root_single_version_test,
        cc_runtime_deps_root_alias_collapses_to_resolved_version_test,
        cc_runtime_deps_root_dedups_across_tags_test,
        cc_runtime_deps_local_version_test,
        cc_runtime_deps_non_root_rejected_test,
        cc_runtime_deps_non_root_rejected_even_when_root_also_present_test,
        cc_runtime_deps_unknown_version_test,

        # find_local_license_paths tests
        local_license_suffixed_linux_test,
        local_license_suffixed_mac_test,
        local_license_suffixed_windows_test,
        local_license_legacy_fallback_test,
        local_license_prefers_popili_over_legacy_test,
        local_license_absent_test,
        local_license_unset_home_test,
        local_license_empty_home_test,
        local_license_unset_appdata_windows_test,
        local_license_unset_appdata_ignored_off_windows_test,
        local_license_windows_localappdata_test,
        local_license_xdg_data_home_test,
        local_license_popili_data_test,
        local_license_coco_platform_data_test,
        local_license_popili_data_windows_test,
        local_license_unset_home_mac_test,

        # license_protocol_version tests
        license_protocol_known_versions_test,
        license_protocol_newer_than_known_test,
        license_protocol_unknown_test,
        license_protocol_custom_table_test,
        license_protocol_table_sorted_test,
        local_license_paths_by_protocol_test,
        local_license_paths_mac_test,
        local_license_paths_data_dir_test,
        local_license_paths_absent_test,
        license_file_name_test,

        # coco_toolchain_download tests
        coco_toolchain_download_url_test,
        coco_toolchain_download_sha_matches_known_shas_test,
        coco_toolchain_download_all_platforms_verified_test,
        coco_toolchain_download_version_aliases_verified_test,
        coco_toolchain_download_prerelease_test,
        coco_toolchain_download_unknown_version_test,
        coco_toolchain_download_covers_every_platform_test,
        coco_download_runtime_test,

        # resolve_version_alias tests
        resolve_version_alias_known_alias_test,
        resolve_version_alias_passthrough_test,
        resolve_versions_default_resolver_test,
        normalize_extra_deps_default_resolver_test,
        version_tuple_test,
        version_key_test,
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

        # missing_popili_message tests
        missing_popili_unregistered_version_test,
        missing_popili_pinned_version_test,
        missing_popili_local_unregistered_test,
        missing_popili_no_execution_platform_test,
        missing_popili_local_off_host_test,
        missing_popili_local_only_test,
        missing_popili_empty_registry_test,
        missing_popili_alias_test,
        missing_popili_test_platform_test,
        version_source_test,
        popili_rule_reserved_attribute_test,
        missing_popili_forced_test,

        # library_version_mismatch_message tests
        library_version_mismatch_pinned_test,
        library_version_mismatch_unpinned_test,
        library_version_conflict_agree_test,
        library_version_conflict_library_test,
        own_package_versions_message_test,
        package_versions_conflict_test,
        inherited_versions_conflict_test,

        # bring-your-own toolchain version check tests
        toolchain_version_mismatch_test,

        # effective_version and pin_transition_settings tests
        effective_version_test,
        pin_transition_settings_unpinned_test,
        pin_transition_settings_pinned_test,
        pin_transition_settings_alias_test,
        pin_transition_settings_already_pinned_test,
        pin_transition_settings_default_test,
        pin_transition_settings_nested_test,
        unpin_transition_settings_test,
        pin_transition_settings_forced_test,
        package_transition_settings_test,

        # toolchain_hub_entries tests
        hub_entries_single_version_test,
        hub_entries_default_is_first_version_only_test,
        hub_entries_local_only_test,
        hub_entries_local_alongside_versions_test,
        hub_unknown_version_test,
        hub_entries_registered_versions_test,

        # render_toolchain_hub_build tests
        hub_build_labels_test,
        hub_build_loads_only_rules_coco_and_platforms_test,
        hub_build_registry_test,
        hub_build_constrains_exec_only_test,
        hub_build_local_is_host_only_test,

        # BUILD_for_coco_toolchain tests
        toolchain_build_version_test,
        toolchain_build_license_protocol_version_test,

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
