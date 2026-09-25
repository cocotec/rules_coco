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
load(":cc_runtime_deps.bzl", "collect_cc_runtime_extra_deps", "normalize_cc_runtime_extra_deps")
load(":coco.bzl", "compute_output_filenames", "mangle_name", "pin_warnings", "pinned_version")
load(":common_repositories.bzl", "find_local_license_path")
load(":known_shas.bzl", "FILE_KEY_TO_SHA")
load(
    ":toolchain_hub.bzl",
    "COCO_TOOLCHAIN_PLATFORMS",
    "render_toolchain_hub_build",
    "render_version_registry_build",
    "resolve_versions",
    "toolchain_hub_entries",
)
load(":toolchain_repositories.bzl", "BUILD_for_coco_toolchain", "coco_toolchain_download")
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

# Tests for _mangle_name function

def _mangle_name_unaltered_test(ctx):
    """Test that Unaltered style returns the original name."""
    env = unittest.begin(ctx)

    asserts.equals(env, "ExampleName", mangle_name("ExampleName", "Unaltered"))
    asserts.equals(env, "example_name", mangle_name("example_name", "Unaltered"))
    asserts.equals(env, "EXAMPLE", mangle_name("EXAMPLE", "Unaltered"))
    asserts.equals(env, "", mangle_name("", "Unaltered"))

    return unittest.end(env)

def _mangle_name_lower_camel_test(ctx):
    """Test LowerCamelCase style."""
    env = unittest.begin(ctx)

    asserts.equals(env, "exampleName", mangle_name("ExampleName", "LowerCamelCase"))
    asserts.equals(env, "exampleName", mangle_name("exampleName", "LowerCamelCase"))
    asserts.equals(env, "aBCDef", mangle_name("ABCDef", "LowerCamelCase"))
    asserts.equals(env, "example", mangle_name("Example", "LowerCamelCase"))
    asserts.equals(env, "a", mangle_name("A", "LowerCamelCase"))
    asserts.equals(env, "example", mangle_name("example", "LowerCamelCase"))

    return unittest.end(env)

def _mangle_name_upper_camel_test(ctx):
    """Test UpperCamelCase style."""
    env = unittest.begin(ctx)

    asserts.equals(env, "ExampleName", mangle_name("ExampleName", "UpperCamelCase"))
    asserts.equals(env, "ExampleName", mangle_name("exampleName", "UpperCamelCase"))
    asserts.equals(env, "Example", mangle_name("example", "UpperCamelCase"))
    asserts.equals(env, "ABCDef", mangle_name("ABCDef", "UpperCamelCase"))
    asserts.equals(env, "A", mangle_name("a", "UpperCamelCase"))

    return unittest.end(env)

def _mangle_name_lower_underscore_test(ctx):
    """Test LowerUnderscore (snake_case) style."""
    env = unittest.begin(ctx)

    asserts.equals(env, "example_name", mangle_name("ExampleName", "LowerUnderscore"))
    asserts.equals(env, "a_b_c_def", mangle_name("ABCDef", "LowerUnderscore"))
    asserts.equals(env, "example", mangle_name("Example", "LowerUnderscore"))
    asserts.equals(env, "example", mangle_name("example", "LowerUnderscore"))
    asserts.equals(env, "a", mangle_name("A", "LowerUnderscore"))
    asserts.equals(env, "my_example_name", mangle_name("MyExampleName", "LowerUnderscore"))
    asserts.equals(env, "example_name", mangle_name("exampleName", "LowerUnderscore"))

    return unittest.end(env)

def _mangle_name_upper_underscore_test(ctx):
    """Test UpperUnderscore (UPPER_SNAKE_CASE) style."""
    env = unittest.begin(ctx)

    asserts.equals(env, "EXAMPLE_NAME", mangle_name("ExampleName", "UpperUnderscore"))
    asserts.equals(env, "A_B_C_DEF", mangle_name("ABCDef", "UpperUnderscore"))
    asserts.equals(env, "EXAMPLE", mangle_name("Example", "UpperUnderscore"))
    asserts.equals(env, "EXAMPLE", mangle_name("example", "UpperUnderscore"))
    asserts.equals(env, "A", mangle_name("A", "UpperUnderscore"))

    return unittest.end(env)

def _mangle_name_caps_upper_underscore_test(ctx):
    """Test CapsUpperUnderscore style (should be same as UpperUnderscore)."""
    env = unittest.begin(ctx)

    asserts.equals(env, "EXAMPLE_NAME", mangle_name("ExampleName", "CapsUpperUnderscore"))
    asserts.equals(env, "A_B_C_DEF", mangle_name("ABCDef", "CapsUpperUnderscore"))
    asserts.equals(env, "EXAMPLE", mangle_name("Example", "CapsUpperUnderscore"))

    return unittest.end(env)

def _mangle_name_edge_cases_test(ctx):
    """Test edge cases for name mangling."""
    env = unittest.begin(ctx)

    # All uppercase
    asserts.equals(env, "a_b_c", mangle_name("ABC", "LowerUnderscore"))

    # Numbers (should be treated as part of word)
    asserts.equals(env, "example123_name", mangle_name("Example123Name", "LowerUnderscore"))

    return unittest.end(env)

mangle_name_unaltered_test = unittest.make(_mangle_name_unaltered_test)
mangle_name_lower_camel_test = unittest.make(_mangle_name_lower_camel_test)
mangle_name_upper_camel_test = unittest.make(_mangle_name_upper_camel_test)
mangle_name_lower_underscore_test = unittest.make(_mangle_name_lower_underscore_test)
mangle_name_upper_underscore_test = unittest.make(_mangle_name_upper_underscore_test)
mangle_name_caps_upper_underscore_test = unittest.make(_mangle_name_caps_upper_underscore_test)
mangle_name_edge_cases_test = unittest.make(_mangle_name_edge_cases_test)

# Tests for _compute_output_filenames function

def _compute_output_filenames_basic_test(ctx):
    """Test basic output filename computation."""
    env = unittest.begin(ctx)

    config = struct(
        file_name_mangler = "Unaltered",
        header_prefix = "",
        header_extension = ".h",
        impl_prefix = "",
        impl_extension = ".cc",
        mocks = False,
        flat_hierarchy = False,
        root_output_dir = None,
    )

    result = compute_output_filenames("Example.coco", config)

    asserts.equals(env, "Example.h", result.header)
    asserts.equals(env, "Example.cc", result.impl)
    asserts.equals(env, None, result.mock_header)
    asserts.equals(env, None, result.mock_impl)

    return unittest.end(env)

def _compute_output_filenames_with_prefixes_test(ctx):
    """Test output filename computation with prefixes."""
    env = unittest.begin(ctx)

    config = struct(
        file_name_mangler = "Unaltered",
        header_prefix = "api_",
        header_extension = ".h",
        impl_prefix = "impl_",
        impl_extension = ".cc",
        mocks = False,
        flat_hierarchy = False,
        root_output_dir = None,
    )

    result = compute_output_filenames("Example.coco", config)

    asserts.equals(env, "api_Example.h", result.header)
    asserts.equals(env, "impl_Example.cc", result.impl)

    return unittest.end(env)

def _compute_output_filenames_with_extensions_test(ctx):
    """Test output filename computation with custom extensions."""
    env = unittest.begin(ctx)

    config = struct(
        file_name_mangler = "Unaltered",
        header_prefix = "",
        header_extension = ".hpp",
        impl_prefix = "",
        impl_extension = ".cpp",
        mocks = False,
        flat_hierarchy = False,
        root_output_dir = None,
    )

    result = compute_output_filenames("Example.coco", config)

    asserts.equals(env, "Example.hpp", result.header)
    asserts.equals(env, "Example.cpp", result.impl)

    return unittest.end(env)

def _compute_output_filenames_with_mangling_test(ctx):
    """Test output filename computation with name mangling."""
    env = unittest.begin(ctx)

    config = struct(
        file_name_mangler = "LowerUnderscore",
        header_prefix = "",
        header_extension = ".h",
        impl_prefix = "",
        impl_extension = ".cc",
        mocks = False,
        flat_hierarchy = False,
        root_output_dir = None,
    )

    result = compute_output_filenames("ExampleName.coco", config)

    asserts.equals(env, "example_name.h", result.header)
    asserts.equals(env, "example_name.cc", result.impl)

    return unittest.end(env)

def _compute_output_filenames_with_mocks_test(ctx):
    """Test output filename computation with mocks enabled."""
    env = unittest.begin(ctx)

    config = struct(
        file_name_mangler = "Unaltered",
        header_prefix = "",
        header_extension = ".h",
        impl_prefix = "",
        impl_extension = ".cc",
        mocks = True,
        flat_hierarchy = False,
        root_output_dir = None,
    )

    result = compute_output_filenames("Example.coco", config)

    asserts.equals(env, "Example.h", result.header)
    asserts.equals(env, "Example.cc", result.impl)
    asserts.equals(env, "ExampleMock.h", result.mock_header)
    asserts.equals(env, "ExampleMock.cc", result.mock_impl)

    return unittest.end(env)

def _compute_output_filenames_flat_hierarchy_test(ctx):
    """Test output filename computation with flat hierarchy."""
    env = unittest.begin(ctx)

    config = struct(
        file_name_mangler = "Unaltered",
        header_prefix = "",
        header_extension = ".h",
        impl_prefix = "",
        impl_extension = ".cc",
        mocks = False,
        flat_hierarchy = True,
        root_output_dir = "src",
    )

    result = compute_output_filenames("Example.coco", config)

    asserts.equals(env, "src/Example.h", result.header)
    asserts.equals(env, "src/Example.cc", result.impl)

    return unittest.end(env)

def _compute_output_filenames_flat_hierarchy_no_root_test(ctx):
    """Test flat hierarchy with no root output directory."""
    env = unittest.begin(ctx)

    config = struct(
        file_name_mangler = "Unaltered",
        header_prefix = "",
        header_extension = ".h",
        impl_prefix = "",
        impl_extension = ".cc",
        mocks = False,
        flat_hierarchy = True,
        root_output_dir = None,
    )

    result = compute_output_filenames("Example.coco", config)

    asserts.equals(env, "Example.h", result.header)
    asserts.equals(env, "Example.cc", result.impl)

    return unittest.end(env)

def _compute_output_filenames_combined_test(ctx):
    """Test output filename computation with all options combined."""
    env = unittest.begin(ctx)

    config = struct(
        file_name_mangler = "LowerUnderscore",
        header_prefix = "api_",
        header_extension = ".hpp",
        impl_prefix = "impl_",
        impl_extension = ".cpp",
        mocks = True,
        flat_hierarchy = True,
        root_output_dir = "generated",
    )

    result = compute_output_filenames("ExampleName.coco", config)

    asserts.equals(env, "generated/api_example_name.hpp", result.header)
    asserts.equals(env, "generated/impl_example_name.cpp", result.impl)
    asserts.equals(env, "generated/api_example_nameMock.hpp", result.mock_header)
    asserts.equals(env, "generated/impl_example_nameMock.cpp", result.mock_impl)

    return unittest.end(env)

# Tests for C language output filename computation

def _compute_output_filenames_c_basic_test(ctx):
    """Test basic C output filename computation."""
    env = unittest.begin(ctx)

    config = struct(
        file_name_mangler = "Unaltered",
        header_prefix = "",
        header_extension = ".h",
        impl_prefix = "",
        impl_extension = ".c",
        mocks = False,
        flat_hierarchy = False,
        root_output_dir = None,
    )

    result = compute_output_filenames("Example.coco", config)

    asserts.equals(env, "Example.h", result.header)
    asserts.equals(env, "Example.c", result.impl)
    asserts.equals(env, None, result.mock_header)
    asserts.equals(env, None, result.mock_impl)

    return unittest.end(env)

def _compute_output_filenames_c_with_prefixes_test(ctx):
    """Test C output filename computation with prefixes."""
    env = unittest.begin(ctx)

    config = struct(
        file_name_mangler = "Unaltered",
        header_prefix = "api_",
        header_extension = ".h",
        impl_prefix = "impl_",
        impl_extension = ".c",
        mocks = False,
        flat_hierarchy = False,
        root_output_dir = None,
    )

    result = compute_output_filenames("Example.coco", config)

    asserts.equals(env, "api_Example.h", result.header)
    asserts.equals(env, "impl_Example.c", result.impl)

    return unittest.end(env)

def _compute_output_filenames_c_with_mangling_test(ctx):
    """Test C output filename computation with name mangling."""
    env = unittest.begin(ctx)

    config = struct(
        file_name_mangler = "LowerUnderscore",
        header_prefix = "",
        header_extension = ".h",
        impl_prefix = "",
        impl_extension = ".c",
        mocks = False,
        flat_hierarchy = False,
        root_output_dir = None,
    )

    result = compute_output_filenames("ExampleName.coco", config)

    asserts.equals(env, "example_name.h", result.header)
    asserts.equals(env, "example_name.c", result.impl)

    return unittest.end(env)

def _compute_output_filenames_c_flat_hierarchy_test(ctx):
    """Test C output filename computation with flat hierarchy."""
    env = unittest.begin(ctx)

    config = struct(
        file_name_mangler = "Unaltered",
        header_prefix = "",
        header_extension = ".h",
        impl_prefix = "",
        impl_extension = ".c",
        mocks = False,
        flat_hierarchy = True,
        root_output_dir = "src",
    )

    result = compute_output_filenames("Example.coco", config)

    asserts.equals(env, "src/Example.h", result.header)
    asserts.equals(env, "src/Example.c", result.impl)

    return unittest.end(env)

def _compute_output_filenames_c_combined_test(ctx):
    """Test C output filename computation with all options combined."""
    env = unittest.begin(ctx)

    config = struct(
        file_name_mangler = "LowerUnderscore",
        header_prefix = "api_",
        header_extension = ".h",
        impl_prefix = "impl_",
        impl_extension = ".c",
        mocks = True,
        flat_hierarchy = True,
        root_output_dir = "generated",
    )

    result = compute_output_filenames("ExampleName.coco", config)

    asserts.equals(env, "generated/api_example_name.h", result.header)
    asserts.equals(env, "generated/impl_example_name.c", result.impl)
    asserts.equals(env, "generated/api_example_nameMock.h", result.mock_header)
    asserts.equals(env, "generated/impl_example_nameMock.c", result.mock_impl)

    return unittest.end(env)

# Create test rules for compute_output_filenames
compute_output_filenames_basic_test = unittest.make(_compute_output_filenames_basic_test)
compute_output_filenames_with_prefixes_test = unittest.make(_compute_output_filenames_with_prefixes_test)
compute_output_filenames_with_extensions_test = unittest.make(_compute_output_filenames_with_extensions_test)
compute_output_filenames_with_mangling_test = unittest.make(_compute_output_filenames_with_mangling_test)
compute_output_filenames_with_mocks_test = unittest.make(_compute_output_filenames_with_mocks_test)
compute_output_filenames_flat_hierarchy_test = unittest.make(_compute_output_filenames_flat_hierarchy_test)
compute_output_filenames_flat_hierarchy_no_root_test = unittest.make(_compute_output_filenames_flat_hierarchy_no_root_test)
compute_output_filenames_combined_test = unittest.make(_compute_output_filenames_combined_test)

# Create test rules for C language compute_output_filenames
compute_output_filenames_c_basic_test = unittest.make(_compute_output_filenames_c_basic_test)
compute_output_filenames_c_with_prefixes_test = unittest.make(_compute_output_filenames_c_with_prefixes_test)
compute_output_filenames_c_with_mangling_test = unittest.make(_compute_output_filenames_c_with_mangling_test)
compute_output_filenames_c_flat_hierarchy_test = unittest.make(_compute_output_filenames_c_flat_hierarchy_test)
compute_output_filenames_c_combined_test = unittest.make(_compute_output_filenames_c_combined_test)

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
    ("osx", "x86_64", "popili_darwin_amd64.zip"),
    ("linux", "aarch64", "popili_linux_arm64.zip"),
    ("linux", "x86_64", "popili_linux_amd64.zip"),
    ("windows", "x86_64", "popili_windows_amd64.zip"),
]

# Platforms rules_coco registers a toolchain for, but for which no archive has been
# published since 1.5.0-beta.7, so there is no checksum to assert. Selecting one of these
# fails at download rather than at toolchain resolution, and the missing checksum means the
# download would be unverified.
_UNPUBLISHED_PLATFORMS = [
    ("osx", "x86_64"),
]

def _is_published(os, arch):
    return not (os, arch) in _UNPUBLISHED_PLATFORMS

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
        if not _is_published(os, arch):
            continue
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
        if not _is_published(os, arch):
            continue
        sha256 = coco_toolchain_download("1.5.7", os, arch).sha256
        asserts.true(
            env,
            sha256 != "",
            "1.5.7 %s/%s (%s) would be downloaded unverified" % (os, arch, archive),
        )
        asserts.equals(env, 64, len(sha256), "not a sha256 for %s: %r" % (archive, sha256))

    return unittest.end(env)

def _coco_toolchain_download_version_aliases_verified_test(ctx):
    """Every version an alias resolves to is checksummed on every published platform."""
    env = unittest.begin(ctx)

    for (alias, version) in VERSION_ALIASES.items():
        for (os, arch, _archive) in _TOOLCHAIN_PLATFORMS:
            if not _is_published(os, arch):
                continue
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
    asserts.equals(env, constraints, entries.target_compatible_with["linux_x86_64__1_5_7"])

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
    asserts.equals(env, [], entries.target_compatible_with["local"])

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

hub_build_labels_test = unittest.make(_hub_build_labels_test)
hub_build_has_no_loads_test = unittest.make(_hub_build_has_no_loads_test)

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

def _normalize_extra_deps_empty_test(ctx):
    """Neither empty form registers anything."""
    env = unittest.begin(ctx)

    result, err = normalize_cc_runtime_extra_deps([], {"1.5.1": True}, _fake_resolve)
    asserts.equals(env, None, err)
    asserts.equals(env, {}, result)

    result, err = normalize_cc_runtime_extra_deps({}, {"1.5.1": True}, _fake_resolve)
    asserts.equals(env, None, err)
    asserts.equals(env, {}, result)

    return unittest.end(env)

normalize_extra_deps_list_applies_to_all_test = unittest.make(_normalize_extra_deps_list_applies_to_all_test)
normalize_extra_deps_dict_is_per_version_test = unittest.make(_normalize_extra_deps_dict_is_per_version_test)
normalize_extra_deps_dict_alias_key_test = unittest.make(_normalize_extra_deps_dict_alias_key_test)
normalize_extra_deps_unknown_version_test = unittest.make(_normalize_extra_deps_unknown_version_test)
normalize_extra_deps_empty_test = unittest.make(_normalize_extra_deps_empty_test)

# Tests for render_version_registry_build

def _version_registry_build_test(ctx):
    """The registry records every version, the default and each runtime's version."""
    env = unittest.begin(ctx)

    build = render_version_registry_build(
        versions = ["1.5.0", "1.5.1", "local"],
        default = "1.5.0",
        cc_runtimes = {
            "@io_cocotec_coco_cc_runtime__1_5_0//:runtime": "1.5.0",
            "@io_cocotec_coco_cc_runtime__local//:runtime": "local",
        },
        c_runtimes = {"@io_cocotec_coco_c_runtime__1_5_1//:runtime": "1.5.1"},
    )

    asserts.true(env, 'load("@rules_coco//coco/private:version_registry.bzl", "coco_version_registry")' in build, build)
    asserts.true(env, 'versions = ["1.5.0", "1.5.1", "local"],' in build, build)
    asserts.true(env, 'default = "1.5.0",' in build, build)
    asserts.true(env, '"@io_cocotec_coco_cc_runtime__1_5_0//:runtime": "1.5.0"' in build, build)
    asserts.true(env, '"@io_cocotec_coco_cc_runtime__local//:runtime": "local"' in build, build)
    asserts.true(env, 'c_runtimes = {"@io_cocotec_coco_c_runtime__1_5_1//:runtime": "1.5.1"},' in build, build)

    # The :versions target every coco_package depends on must not pull in any runtime.
    versions_target = build[build.index('name = "versions"'):build.index('name = "runtimes"')]
    asserts.true(env, "runtime__" not in versions_target, versions_target)

    return unittest.end(env)

def _version_registry_build_without_runtimes_test(ctx):
    """With cc and c disabled the runtime maps are empty, not missing."""
    env = unittest.begin(ctx)

    build = render_version_registry_build(versions = ["1.5.7"], default = "1.5.7")

    asserts.true(env, "cc_runtimes = {}," in build, build)
    asserts.true(env, "c_runtimes = {}," in build, build)

    return unittest.end(env)

version_registry_build_test = unittest.make(_version_registry_build_test)
version_registry_build_without_runtimes_test = unittest.make(_version_registry_build_without_runtimes_test)

# Tests for BUILD_for_coco_toolchain

def _toolchain_build_records_version_test(ctx):
    """The generated coco_toolchain declares the version it provides."""
    env = unittest.begin(ctx)

    asserts.true(env, 'version = "1.5.1",' in BUILD_for_coco_toolchain(name = "toolchain", version = "1.5.1"))
    asserts.true(env, "version =" not in BUILD_for_coco_toolchain(name = "toolchain"))

    return unittest.end(env)

toolchain_build_records_version_test = unittest.make(_toolchain_build_records_version_test)

# Tests for pinned_version

def _pinned_version_uses_pin_test(ctx):
    """A pin overrides the configuration's version."""
    env = unittest.begin(ctx)

    asserts.equals(env, "1.5.1", pinned_version("1.5.1", False, ""))
    asserts.equals(env, "1.5.1", pinned_version("1.5.1", False, "1.5.0"))

    return unittest.end(env)

def _pinned_version_resolves_alias_test(ctx):
    """Aliases are resolved, so a "stable" pin matches the concrete version's toolchain."""
    env = unittest.begin(ctx)

    asserts.equals(env, VERSION_ALIASES["stable"], pinned_version("stable", False, ""))

    return unittest.end(env)

def _pinned_version_unpinned_keeps_current_test(ctx):
    """Without a pin the configuration is left alone, so no new configuration is created."""
    env = unittest.begin(ctx)

    asserts.equals(env, "", pinned_version("", False, ""))
    asserts.equals(env, "1.5.0", pinned_version("", False, "1.5.0"))

    return unittest.end(env)

def _pinned_version_force_beats_pin_test(ctx):
    """--@rules_coco//:force_version makes the configuration's version win over any pin."""
    env = unittest.begin(ctx)

    asserts.equals(env, "1.5.0", pinned_version("1.5.1", True, "1.5.0"))
    asserts.equals(env, "", pinned_version("1.5.1", True, ""))

    return unittest.end(env)

pinned_version_uses_pin_test = unittest.make(_pinned_version_uses_pin_test)
pinned_version_resolves_alias_test = unittest.make(_pinned_version_resolves_alias_test)
pinned_version_unpinned_keeps_current_test = unittest.make(_pinned_version_unpinned_keeps_current_test)
pinned_version_force_beats_pin_test = unittest.make(_pinned_version_force_beats_pin_test)

# Tests for pin_warnings

def _pin(label, version, pinned_by = None):
    return struct(label = Label(label), pinned_by = Label(pinned_by or label), version = version)

def _pin_warnings_differing_pin_test(ctx):
    """A pinned dependency on another version is reported, naming both packages and versions."""
    env = unittest.begin(ctx)

    warnings = pin_warnings(Label("//:p1"), "1.5.0", [_pin("//:l", "1.5.1")])

    asserts.equals(env, 1, len(warnings))
    asserts.true(env, "//:l pins popili_version \"1.5.1\"" in warnings[0], warnings[0])
    asserts.true(env, "//:p1 depends on it and uses popili \"1.5.0\"" in warnings[0], warnings[0])

    return unittest.end(env)

def _pin_warnings_matching_pin_test(ctx):
    """A pinned dependency on the same version is not worth a warning."""
    env = unittest.begin(ctx)

    asserts.equals(env, [], pin_warnings(Label("//:p1"), "1.5.1", [_pin("//:l", "1.5.1")]))

    return unittest.end(env)

def _pin_warnings_names_workspace_test(ctx):
    """A dependency pinned through its workspace says so."""
    env = unittest.begin(ctx)

    warnings = pin_warnings(Label("//:p1"), "1.5.0", [_pin("//:l", "1.5.1", pinned_by = "//:ws")])

    asserts.equals(env, 1, len(warnings))
    asserts.true(env, "(through //:ws)" in warnings[0], warnings[0])

    return unittest.end(env)

def _pin_warnings_sorted_test(ctx):
    """Warnings are sorted by label, so their order doesn't depend on depset traversal."""
    env = unittest.begin(ctx)

    warnings = pin_warnings(Label("//:p1"), "1.5.0", [_pin("//:b", "1.5.1"), _pin("//:a", "1.5.1")])

    asserts.equals(env, 2, len(warnings))
    asserts.true(env, warnings[0].startswith("//:a "), warnings[0])

    return unittest.end(env)

pin_warnings_differing_pin_test = unittest.make(_pin_warnings_differing_pin_test)
pin_warnings_matching_pin_test = unittest.make(_pin_warnings_matching_pin_test)
pin_warnings_names_workspace_test = unittest.make(_pin_warnings_names_workspace_test)
pin_warnings_sorted_test = unittest.make(_pin_warnings_sorted_test)

def coco_test_suite(name):
    """Create test suite for coco functions.

    Args:
        name: The name of the test suite.
    """
    unittest.suite(
        name,

        # _mangle_name tests
        mangle_name_unaltered_test,
        mangle_name_lower_camel_test,
        mangle_name_upper_camel_test,
        mangle_name_lower_underscore_test,
        mangle_name_upper_underscore_test,
        mangle_name_caps_upper_underscore_test,
        mangle_name_edge_cases_test,

        # _compute_output_filenames tests (C++)
        compute_output_filenames_basic_test,
        compute_output_filenames_with_prefixes_test,
        compute_output_filenames_with_extensions_test,
        compute_output_filenames_with_mangling_test,
        compute_output_filenames_with_mocks_test,
        compute_output_filenames_flat_hierarchy_test,
        compute_output_filenames_flat_hierarchy_no_root_test,
        compute_output_filenames_combined_test,

        # _compute_output_filenames tests (C)
        compute_output_filenames_c_basic_test,
        compute_output_filenames_c_with_prefixes_test,
        compute_output_filenames_c_with_mangling_test,
        compute_output_filenames_c_flat_hierarchy_test,
        compute_output_filenames_c_combined_test,

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
        coco_toolchain_download_covers_every_platform_test,

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

        # normalize_cc_runtime_extra_deps tests
        normalize_extra_deps_list_applies_to_all_test,
        normalize_extra_deps_dict_is_per_version_test,
        normalize_extra_deps_dict_alias_key_test,
        normalize_extra_deps_unknown_version_test,
        normalize_extra_deps_empty_test,

        # render_version_registry_build tests
        version_registry_build_test,
        version_registry_build_without_runtimes_test,

        # BUILD_for_coco_toolchain tests
        toolchain_build_records_version_test,

        # pinned_version tests
        pinned_version_uses_pin_test,
        pinned_version_resolves_alias_test,
        pinned_version_unpinned_keeps_current_test,
        pinned_version_force_beats_pin_test,

        # pin_warnings tests
        pin_warnings_differing_pin_test,
        pin_warnings_matching_pin_test,
        pin_warnings_names_workspace_test,
        pin_warnings_sorted_test,
    )
