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
load(":common_repositories.bzl", "download_prefix", "find_local_license", "local_license_paths", "render_fetch_license_build", "render_local_license_build")
load(":known_shas.bzl", "FILE_KEY_TO_SHA")
load(":license_versions.bzl", "is_newer_than_known", "known_license_versions", "license_representatives", "license_version", "parse_version_json")
load(":platforms.bzl", "COCO_TOOLCHAIN_PLATFORMS", "EXEC_PLATFORM_KEYS", "archive_platform", "host_platform", "platform_binary_ext", "platform_key")
load(
    ":toolchain_hub.bzl",
    "merge_toolchain_tags",
    "render_toolchain_hub_build",
    "render_version_registry_build",
    "resolve_versions",
    "toolchain_hub_entries",
)
load(":toolchain_repositories.bzl", "BUILD_for_coco_toolchain", "coco_toolchain_download")
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

# Tests for find_local_license

_LINUX_HOME = "/home/dev"
_MAC_HOME = "/Users/dev"
_WINDOWS_LOCALAPPDATA = "C:\\Users\\dev\\AppData\\Local"

def _fake_repository_ctx(os_name, existing, environ = None, arch = "aarch64"):
    """Builds a stand-in for a repository ctx that only knows about `existing` paths.

    `environ` defaults to a home directory, or %LOCALAPPDATA% on Windows. Leaving a variable
    out models it being unset, not empty.
    """
    if environ == None:
        if "windows" in os_name:
            environ = {"LOCALAPPDATA": _WINDOWS_LOCALAPPDATA}
        elif "mac" in os_name:
            environ = {"HOME": _MAC_HOME}
        else:
            environ = {"HOME": _LINUX_HOME}
    return struct(
        os = struct(name = os_name, arch = arch, environ = environ),
        existing = existing,
    )

def _fake_path_exists(ctx, path_str):
    return path_str in ctx.existing

def _local_license_linux_test(ctx):
    """popili 1.6.0's directory is preferred; 1.5.x's is the fallback."""
    env = unittest.begin(ctx)

    new = "%s/.local/share/popili/licenses_8.lic" % _LINUX_HOME
    old = "%s/.local/share/coco_platform/licenses_6.lic" % _LINUX_HOME
    fake = _fake_repository_ctx("linux", [new, old])

    asserts.equals(env, new, find_local_license(fake, 8, _fake_path_exists))
    asserts.equals(env, old, find_local_license(fake, 6, _fake_path_exists))

    return unittest.end(env)

def _local_license_picks_its_own_version_test(ctx):
    """Only the licence of the requested version counts, not the first licence found."""
    env = unittest.begin(ctx)

    fake = _fake_repository_ctx("linux", ["%s/.local/share/popili/licenses_8.lic" % _LINUX_HOME])

    asserts.equals(env, None, find_local_license(fake, 6, _fake_path_exists))

    return unittest.end(env)

def _local_license_xdg_data_home_test(ctx):
    """On Linux, popili honours $XDG_DATA_HOME, and so does the lookup."""
    env = unittest.begin(ctx)

    license = "/xdg/coco_platform/licenses_6.lic"
    fake = _fake_repository_ctx("linux", [license], environ = {"HOME": _LINUX_HOME, "XDG_DATA_HOME": "/xdg"})

    asserts.equals(env, license, find_local_license(fake, 6, _fake_path_exists))

    return unittest.end(env)

def _local_license_popili_data_test(ctx):
    """$POPILI_DATA replaces the per-user directories entirely, on every platform."""
    env = unittest.begin(ctx)

    license = "/data/licenses_6.lic"
    fake = _fake_repository_ctx("mac os x", [license, "%s/Library/Application Support/Coco Platform/licenses_6.lic" % _MAC_HOME], environ = {"HOME": _MAC_HOME, "POPILI_DATA": "/data"})

    asserts.equals(env, license, find_local_license(fake, 6, _fake_path_exists))

    return unittest.end(env)

def _local_license_mac_test(ctx):
    """On macOS the data directories live under ~/Library/Application Support."""
    env = unittest.begin(ctx)

    license = "%s/Library/Application Support/Coco Platform/licenses_6.lic" % _MAC_HOME
    fake = _fake_repository_ctx("mac os x", [license])

    asserts.equals(env, license, find_local_license(fake, 6, _fake_path_exists))

    return unittest.end(env)

def _local_license_windows_test(ctx):
    """On Windows popili uses %LOCALAPPDATA% (FOLDERID_LocalAppData), not LocalLow."""
    env = unittest.begin(ctx)

    license = "%s\\Coco Platform\\licenses_6.lic" % _WINDOWS_LOCALAPPDATA
    fake = _fake_repository_ctx("windows 11", [license])

    asserts.equals(env, license, find_local_license(fake, 6, _fake_path_exists))

    return unittest.end(env)

def _local_license_windows_appdata_fallback_test(ctx):
    """Without %LOCALAPPDATA%, the Local directory next to %APPDATA% is used, then LocalLow."""
    env = unittest.begin(ctx)

    fake = _fake_repository_ctx("windows 11", [], environ = {"APPDATA": "C:\\Users\\dev\\AppData\\Roaming"})

    asserts.equals(
        env,
        [
            "C:\\Users\\dev\\AppData\\Roaming\\..\\Local\\Popili\\licenses_6.lic",
            "C:\\Users\\dev\\AppData\\Roaming\\..\\Local\\Coco Platform\\licenses_6.lic",
            "C:\\Users\\dev\\AppData\\Roaming\\..\\LocalLow\\Popili\\licenses_6.lic",
            "C:\\Users\\dev\\AppData\\Roaming\\..\\LocalLow\\Coco Platform\\licenses_6.lic",
        ],
        local_license_paths(fake, 6),
    )

    return unittest.end(env)

def _local_license_windows_locallow_fallback_test(ctx):
    """A licence that only exists in LocalLow, where earlier rules_coco looked, is still found."""
    env = unittest.begin(ctx)

    license = "C:\\Users\\dev\\AppData\\Roaming\\..\\LocalLow\\Popili\\licenses_6.lic"
    fake = _fake_repository_ctx(
        "windows 11",
        [license],
        environ = {"APPDATA": "C:\\Users\\dev\\AppData\\Roaming", "LOCALAPPDATA": _WINDOWS_LOCALAPPDATA},
    )

    asserts.equals(env, license, find_local_license(fake, 6, _fake_path_exists))

    # %LOCALAPPDATA% wins when both have one.
    preferred = "%s\\Popili\\licenses_6.lic" % _WINDOWS_LOCALAPPDATA
    fake = _fake_repository_ctx(
        "windows 11",
        [license, preferred],
        environ = {"APPDATA": "C:\\Users\\dev\\AppData\\Roaming", "LOCALAPPDATA": _WINDOWS_LOCALAPPDATA},
    )

    asserts.equals(env, preferred, find_local_license(fake, 6, _fake_path_exists))

    return unittest.end(env)

def _host_platform_test(ctx):
    """The host maps to a toolchain platform, or None where no toolchain is published."""
    env = unittest.begin(ctx)

    asserts.equals(env, ("osx", "aarch64"), host_platform(_fake_repository_ctx("mac os x", [])))
    asserts.equals(env, ("linux", "x86_64"), host_platform(_fake_repository_ctx("linux", [], arch = "amd64")))
    asserts.equals(env, ("windows", "x86_64"), host_platform(_fake_repository_ctx("windows 11", [], arch = "x86_64")))
    asserts.equals(env, None, host_platform(_fake_repository_ctx("linux", [], arch = "s390x")))
    asserts.equals(env, None, host_platform(_fake_repository_ctx("sunos", [])))

    # Popili dropped Intel macOS with 1.5.0, so an Intel Mac has no toolchain to point at.
    asserts.equals(env, None, host_platform(_fake_repository_ctx("mac os x", [], arch = "x86_64")))

    return unittest.end(env)

def _local_license_unset_home_test(ctx):
    """With no home directory there is nowhere to look, rather than a path under "None"."""
    env = unittest.begin(ctx)

    fake = _fake_repository_ctx("linux", ["None/.local/share/coco_platform/licenses_6.lic"], environ = {})

    asserts.equals(env, [], local_license_paths(fake, 6))
    asserts.equals(env, None, find_local_license(fake, 6, _fake_path_exists))

    return unittest.end(env)

local_license_linux_test = unittest.make(_local_license_linux_test)
local_license_picks_its_own_version_test = unittest.make(_local_license_picks_its_own_version_test)
local_license_xdg_data_home_test = unittest.make(_local_license_xdg_data_home_test)
local_license_popili_data_test = unittest.make(_local_license_popili_data_test)
local_license_mac_test = unittest.make(_local_license_mac_test)
local_license_windows_test = unittest.make(_local_license_windows_test)
local_license_windows_appdata_fallback_test = unittest.make(_local_license_windows_appdata_fallback_test)
local_license_windows_locallow_fallback_test = unittest.make(_local_license_windows_locallow_fallback_test)
host_platform_test = unittest.make(_host_platform_test)
local_license_unset_home_test = unittest.make(_local_license_unset_home_test)

# Tests for license_versions.bzl

def _license_version_test(ctx):
    """1.5.x uses one licence version and 1.6.0 on another; newer versions get the newest."""
    env = unittest.begin(ctx)

    asserts.equals(env, license_version("1.5.0"), license_version("1.5.8"))
    asserts.equals(env, license_version("1.6.0"), license_version("1.6.0-alpha.15899"))
    asserts.equals(env, license_version("1.6.0"), license_version("1.7.3"))
    asserts.true(env, license_version("1.5.7") != license_version("1.6.0"))
    asserts.equals(env, None, license_version("local"))
    asserts.equals(env, None, license_version("1.4.9"))

    return unittest.end(env)

def _parse_version_json_test(ctx):
    """The version is read from `popili --version-format=json --version`."""
    env = unittest.begin(ctx)

    output = """{
     "command": "popili",
     "version": "1.6.0-alpha.15899",
     "revision": "ce35674655cd9462bd65fe88f73837cbfd0c884c",
     "csm_ast_version": "1606",
     "csm_results_version": "516"
    }
"""
    asserts.equals(env, "1.6.0-alpha.15899", parse_version_json(output))
    asserts.equals(env, "1.5.7", parse_version_json('{"version": "1.5.7"}'))
    asserts.equals(env, None, parse_version_json("popili 1.5.7"))
    asserts.equals(env, None, parse_version_json('{"version": "unknown"}'))
    asserts.equals(env, None, parse_version_json("{not json"))

    return unittest.end(env)

def _is_newer_than_known_test(ctx):
    """Only versions past everything rules_coco knows are unknown."""
    env = unittest.begin(ctx)

    known = ["1.5.0", "1.5.7"]
    asserts.false(env, is_newer_than_known("1.5.7", known))
    asserts.false(env, is_newer_than_known("1.5.2", known))

    # The licence table knows 1.6.0 before its checksums are known.
    asserts.false(env, is_newer_than_known("1.6.0", known))
    asserts.true(env, is_newer_than_known("1.6.1", known))
    asserts.false(env, is_newer_than_known("local", known))

    return unittest.end(env)

def _license_representatives_test(ctx):
    """The default version acquires its own licence version; others use their newest version."""
    env = unittest.begin(ctx)

    v15 = license_version("1.5.0")
    v16 = license_version("1.6.0")
    asserts.equals(env, {v15: "1.5.0"}, license_representatives(["1.5.0", "1.5.7", "1.5.3"]))
    asserts.equals(env, {v15: "1.5.3"}, license_representatives(["1.5.3", "1.5.7"]))
    asserts.equals(env, {v15: "1.5.7", v16: "1.6.0"}, license_representatives(["1.6.0", "1.5.3", "1.5.7"]))
    asserts.equals(env, {}, license_representatives([]))

    return unittest.end(env)

license_version_test = unittest.make(_license_version_test)
parse_version_json_test = unittest.make(_parse_version_json_test)
is_newer_than_known_test = unittest.make(_is_newer_than_known_test)
license_representatives_test = unittest.make(_license_representatives_test)

# Tests for the licence repositories' BUILD files

def _fetch_license_build_test(ctx):
    """Each licence version is acquired with the host's licensing server of its representative."""
    env = unittest.begin(ctx)

    build = render_fetch_license_build({6: "1_5_7"}, has_local = True, host = ("linux", "x86_64"), has_token = True)

    asserts.true(env, 'name = "licenses_6"' in build, build)
    asserts.true(env, '"@io_cocotec_coco_linux_x86_64__1_5_7//:cocotec_licensing_server"' in build, build)
    asserts.true(env, '["@platforms//os:linux", "@platforms//cpu:x86_64"]' in build, build)
    asserts.true(env, '"@io_cocotec_coco_local//:cocotec_licensing_server"' in build, build)

    # The toolchain-resolving fallback, for toolchains registered outside rules_coco.
    asserts.true(env, 'name = "licenses",\n    auth_token' in build, build)

    return unittest.end(env)

def _fetch_license_build_without_token_test(ctx):
    """Without a token every target exists, but is empty."""
    env = unittest.begin(ctx)

    build = render_fetch_license_build({6: "1_5_7"}, has_local = True, host = ("linux", "x86_64"), has_token = False)

    asserts.true(env, "fetch_license" not in build, build)
    for name in ["licenses", "licenses_6", "licenses_local"]:
        asserts.true(env, 'name = "%s",\n    srcs = [],' % name in build, build)

    return unittest.end(env)

def _local_license_build_test(ctx):
    """Each licence version gets its file, and the fallback is the newest one found."""
    env = unittest.begin(ctx)

    build = render_local_license_build({6: "licenses_6.lic", 8: None})

    asserts.true(env, 'name = "licenses_6",\n    srcs = ["licenses_6.lic"]' in build, build)
    asserts.true(env, 'name = "licenses_8",\n    srcs = [],' in build, build)
    asserts.true(env, 'actual = ":licenses_6"' in build, build)

    return unittest.end(env)

def _toolchain_build_declares_licenses_test(ctx):
    """A toolchain repository names the licences of its own licence version."""
    env = unittest.begin(ctx)

    build = BUILD_for_coco_toolchain(name = "toolchain", license_fetch = "@f//:l", license_local = "@l//:l")

    asserts.true(env, 'license_fetch = "@f//:l",' in build, build)
    asserts.true(env, 'license_local = "@l//:l",' in build, build)
    asserts.true(env, "license_" not in BUILD_for_coco_toolchain(name = "toolchain"))

    return unittest.end(env)

fetch_license_build_test = unittest.make(_fetch_license_build_test)
fetch_license_build_without_token_test = unittest.make(_fetch_license_build_without_token_test)
local_license_build_test = unittest.make(_local_license_build_test)

def _known_license_versions_test(ctx):
    """Every licence version of the table, once, ascending: what a local toolchain may need."""
    env = unittest.begin(ctx)

    asserts.equals(env, [6, 8], known_license_versions())

    return unittest.end(env)

known_license_versions_test = unittest.make(_known_license_versions_test)
toolchain_build_declares_licenses_test = unittest.make(_toolchain_build_declares_licenses_test)

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

def _platform_key_test(ctx):
    """Platform keys are "<os>_<arch>", one per published platform, in platform order."""
    env = unittest.begin(ctx)

    asserts.equals(env, "linux_x86_64", platform_key("linux", "x86_64"))
    asserts.equals(env, "osx_aarch64", platform_key("osx", "aarch64"))
    asserts.equals(env, ["osx_aarch64", "linux_aarch64", "linux_x86_64", "windows_x86_64"], EXEC_PLATFORM_KEYS)

    # _script_is_windows reads the OS off a key's prefix, so no OS may contain an underscore.
    for (os, _arch) in COCO_TOOLCHAIN_PLATFORMS:
        asserts.false(env, "_" in os, "OS %r would break platform keys" % os)

    return unittest.end(env)

version_tuple_test = unittest.make(_version_tuple_test)
download_prefix_test = unittest.make(_download_prefix_test)
archive_platform_test = unittest.make(_archive_platform_test)
platform_key_test = unittest.make(_platform_key_test)

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

_PACKAGE_TYPE = "@rules_coco//coco:toolchain_type"
_EXEC_TYPE = "@rules_coco//coco:exec_toolchain_type"

def _hub_entries_single_version_test(ctx):
    """One version yields, per platform, its own pair of toolchains plus the default pair."""
    env = unittest.begin(ctx)

    entries = toolchain_hub_entries(["1.5.7"])

    asserts.equals(env, 16, len(entries.toolchain_names))
    asserts.equals(env, {"1.5.7": "1_5_7"}, entries.version_suffixes)

    # Target-keyed and exec-keyed entries point at the same per-platform toolchain, and so do
    # the version-gated and the default ones.
    label = "@io_cocotec_coco_linux_x86_64__1_5_7//:toolchain_impl"
    for name in ["linux_x86_64__1_5_7", "linux_x86_64__1_5_7_exec", "linux_x86_64__default", "linux_x86_64__default_exec"]:
        asserts.true(env, name in entries.toolchain_names, name)
        asserts.equals(env, label, entries.toolchain_labels[name])
    asserts.equals(env, "1.5.7", entries.default_version)

    asserts.equals(env, _PACKAGE_TYPE, entries.toolchain_types["linux_x86_64__1_5_7"])
    asserts.equals(env, _EXEC_TYPE, entries.toolchain_types["linux_x86_64__1_5_7_exec"])

    # The target-keyed entry constrains the target platform only, the exec-keyed one the
    # execution platform only.
    constraints = ["@platforms//os:linux", "@platforms//cpu:x86_64"]
    asserts.equals(env, constraints, entries.target_compatible_with["linux_x86_64__1_5_7"])
    asserts.equals(env, [], entries.exec_compatible_with["linux_x86_64__1_5_7"])
    asserts.equals(env, [], entries.target_compatible_with["linux_x86_64__1_5_7_exec"])
    asserts.equals(env, constraints, entries.exec_compatible_with["linux_x86_64__1_5_7_exec"])

    asserts.equals(env, ["@coco_toolchains//:version_1_5_7"], entries.target_settings["linux_x86_64__1_5_7"])
    asserts.equals(env, ["@coco_toolchains//:version_1_5_7"], entries.target_settings["linux_x86_64__1_5_7_exec"])
    asserts.equals(env, ["@coco_toolchains//:version_default"], entries.target_settings["linux_x86_64__default"])
    asserts.equals(env, ["@coco_toolchains//:version_default"], entries.target_settings["linux_x86_64__default_exec"])

    return unittest.end(env)

def _hub_entries_default_is_first_version_only_test(ctx):
    """Only the first version gets the default toolchains."""
    env = unittest.begin(ctx)

    entries = toolchain_hub_entries(["1.5.0", "1.5.1"])

    asserts.equals(env, {"1.5.0": "1_5_0", "1.5.1": "1_5_1"}, entries.version_suffixes)
    asserts.equals(env, 24, len(entries.toolchain_names))
    asserts.equals(env, "@io_cocotec_coco_osx_aarch64__1_5_0//:toolchain_impl", entries.toolchain_labels["osx_aarch64__default"])
    asserts.equals(env, "@io_cocotec_coco_osx_aarch64__1_5_1//:toolchain_impl", entries.toolchain_labels["osx_aarch64__1_5_1"])
    asserts.equals(env, "1.5.0", entries.default_version)

    return unittest.end(env)

def _hub_entries_local_only_test(ctx):
    """A local-only setup registers exactly one pair of toolchains, gated on --version=local.

    Matching bzlmod: local never becomes the default, so a build that does not set the
    flag resolves no Coco toolchain at all. The constraints are left to the hub repository
    rule, which knows the host.
    """
    env = unittest.begin(ctx)

    entries = toolchain_hub_entries([], has_local = True)

    asserts.equals(env, ["local", "local_exec"], entries.toolchain_names)
    asserts.equals(env, {"local": "local"}, entries.version_suffixes)
    asserts.equals(env, "", entries.default_version)
    for name in entries.toolchain_names:
        asserts.equals(env, "@io_cocotec_coco_local//:toolchain_impl", entries.toolchain_labels[name])
        asserts.equals(env, ["@coco_toolchains//:version_local"], entries.target_settings[name])
        asserts.equals(env, [], entries.exec_compatible_with[name])
        asserts.equals(env, [], entries.target_compatible_with[name])
    asserts.equals(env, _PACKAGE_TYPE, entries.toolchain_types["local"])
    asserts.equals(env, _EXEC_TYPE, entries.toolchain_types["local_exec"])

    return unittest.end(env)

def _hub_entries_local_alongside_versions_test(ctx):
    """A local toolchain does not displace the downloaded default."""
    env = unittest.begin(ctx)

    entries = toolchain_hub_entries(["1.5.7"], has_local = True)

    asserts.equals(env, 18, len(entries.toolchain_names))
    asserts.equals(env, "@io_cocotec_coco_linux_x86_64__1_5_7//:toolchain_impl", entries.toolchain_labels["linux_x86_64__default"])
    asserts.equals(env, ["@coco_toolchains//:version_local"], entries.target_settings["local"])

    return unittest.end(env)

hub_entries_single_version_test = unittest.make(_hub_entries_single_version_test)
hub_entries_default_is_first_version_only_test = unittest.make(_hub_entries_default_is_first_version_only_test)
hub_entries_local_only_test = unittest.make(_hub_entries_local_only_test)
hub_entries_local_alongside_versions_test = unittest.make(_hub_entries_local_alongside_versions_test)

# Tests for render_toolchain_hub_build

_HOST = ("linux", "x86_64")

def _toolchain_decl(build, name):
    """Returns the toolchain() declaration named `name` from a rendered hub BUILD."""
    start = build.index('name = "%s",' % name)
    return build[start:build.index(")", start)]

def _hub_build_labels_test(ctx):
    """The rendered BUILD wires the version flag and both toolchain types by absolute label.

    Those labels have to resolve from a generated repository in both WORKSPACE mode
    (global repository namespace) and bzlmod (the extension's repo mapping), so they are
    pinned here.
    """
    env = unittest.begin(ctx)

    build = render_toolchain_hub_build(toolchain_hub_entries(["1.5.7"]), host = _HOST)

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
        'target_settings = ["@coco_toolchains//:version_1_5_7"]' in build,
        "target_settings missing: %s" % build,
    )

    package_entry = _toolchain_decl(build, "linux_x86_64__1_5_7")
    exec_entry = _toolchain_decl(build, "linux_x86_64__1_5_7_exec")
    asserts.true(env, 'toolchain_type = "@rules_coco//coco:toolchain_type"' in package_entry, package_entry)
    asserts.true(env, 'toolchain_type = "@rules_coco//coco:exec_toolchain_type"' in exec_entry, exec_entry)
    for entry in [package_entry, exec_entry]:
        asserts.true(env, 'toolchain = "@io_cocotec_coco_linux_x86_64__1_5_7//:toolchain_impl"' in entry, entry)

    return unittest.end(env)

def _hub_build_has_no_loads_test(ctx):
    """The hub uses only native rules, so it stays loadable before skylib is fetched."""
    env = unittest.begin(ctx)

    build = render_toolchain_hub_build(toolchain_hub_entries(["1.5.7"], has_local = True), host = _HOST)

    asserts.true(env, "load(" not in build, "hub BUILD must not load anything: %s" % build)

    return unittest.end(env)

def _hub_build_constraints_test(ctx):
    """Each entry constrains one platform dimension; the local pair is pinned to the host.

    The target-keyed entry is resolved by a coco_package analysed, through its consumers' exec
    transition, for their execution platform as the target platform; the exec-keyed entry by
    rules running popili themselves. Neither constrains the other dimension, so cross-compiling
    still resolves both.
    """
    env = unittest.begin(ctx)

    build = render_toolchain_hub_build(toolchain_hub_entries(["1.5.7"], has_local = True), host = _HOST)

    constraints = '["@platforms//os:osx", "@platforms//cpu:aarch64"]'
    package_entry = _toolchain_decl(build, "osx_aarch64__1_5_7")
    asserts.true(env, "target_compatible_with = %s" % constraints in package_entry, package_entry)
    asserts.true(env, "exec_compatible_with = []" in package_entry, package_entry)
    exec_entry = _toolchain_decl(build, "osx_aarch64__1_5_7_exec")
    asserts.true(env, "exec_compatible_with = %s" % constraints in exec_entry, exec_entry)
    asserts.true(env, "target_compatible_with = []" in exec_entry, exec_entry)

    host_constraints = '["@platforms//os:linux", "@platforms//cpu:x86_64"]'
    local_entry = _toolchain_decl(build, "local")
    asserts.true(env, "target_compatible_with = %s" % host_constraints in local_entry, local_entry)
    asserts.true(env, "exec_compatible_with = []" in local_entry, local_entry)
    local_exec_entry = _toolchain_decl(build, "local_exec")
    asserts.true(env, "exec_compatible_with = %s" % host_constraints in local_exec_entry, local_exec_entry)
    asserts.true(env, "target_compatible_with = []" in local_exec_entry, local_exec_entry)

    # Where popili is not published for the host, the local toolchain stays unconstrained:
    # nothing else can run on that host anyway.
    build = render_toolchain_hub_build(toolchain_hub_entries([], has_local = True), host = None)
    asserts.true(env, "@platforms//os" not in build, build)

    return unittest.end(env)

def _hub_build_runtime_aliases_test(ctx):
    """The hub aliases each kind's runtime of the configured version, with the default's."""
    env = unittest.begin(ctx)

    build = render_toolchain_hub_build(
        toolchain_hub_entries(["1.5.0", "1.5.1"], has_local = True),
        host = _HOST,
        cc_runtimes = {
            "1.5.0": "@io_cocotec_coco_cc_runtime__1_5_0//:runtime",
            "1.5.1": "@io_cocotec_coco_cc_runtime__1_5_1//:runtime",
            "local": "@io_cocotec_coco_cc_runtime__local//:runtime",
        },
        c_runtimes = {"1.5.1": "@io_cocotec_coco_c_runtime__1_5_1//:runtime"},
    )

    cc = build[build.index('name = "cc_runtime"'):build.index('name = "no_cc_runtime"')]
    asserts.true(env, '":version_1_5_0": "@io_cocotec_coco_cc_runtime__1_5_0//:runtime",' in cc, cc)
    asserts.true(env, '":version_default": "@io_cocotec_coco_cc_runtime__1_5_0//:runtime",' in cc, cc)
    asserts.true(env, '":version_1_5_1": "@io_cocotec_coco_cc_runtime__1_5_1//:runtime",' in cc, cc)
    asserts.true(env, '":version_local": "@io_cocotec_coco_cc_runtime__local//:runtime",' in cc, cc)
    asserts.true(env, '"//conditions:default": ":no_cc_runtime",' in cc, cc)

    # The first version has no C runtime, so an unset flag gets the fallback.
    c = build[build.index('name = "c_runtime"'):build.index('name = "no_c_runtime"')]
    asserts.true(env, '":version_1_5_1": "@io_cocotec_coco_c_runtime__1_5_1//:runtime",' in c, c)
    asserts.true(env, "version_default" not in c, c)
    asserts.true(env, "version_1_5_0" not in c, c)

    # The toolchains name no runtime.
    asserts.true(env, "runtime" not in build[:build.index('name = "cc_runtime"')], build)

    return unittest.end(env)

hub_build_labels_test = unittest.make(_hub_build_labels_test)
hub_build_has_no_loads_test = unittest.make(_hub_build_has_no_loads_test)
hub_build_constraints_test = unittest.make(_hub_build_constraints_test)
hub_build_runtime_aliases_test = unittest.make(_hub_build_runtime_aliases_test)

# Tests for BUILD_for_coco_toolchain

def _toolchain_build_records_platform_test(ctx):
    """A platform repository's toolchain says which platform its binary runs on."""
    env = unittest.begin(ctx)

    asserts.true(env, 'platform = "linux_x86_64",' in BUILD_for_coco_toolchain(name = "toolchain", platform = "linux_x86_64"))
    asserts.true(env, "platform" not in BUILD_for_coco_toolchain(name = "toolchain"))

    return unittest.end(env)

toolchain_build_records_platform_test = unittest.make(_toolchain_build_records_platform_test)

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

# Tests for render_version_registry_build

def _version_registry_build_test(ctx):
    """The registry records every version, the default and each runtime's version."""
    env = unittest.begin(ctx)

    build = render_version_registry_build(
        versions = ["1.5.0", "1.5.1", "local"],
        default = "1.5.0",
        host = "linux_x86_64",
        cc_runtimes = {
            "@io_cocotec_coco_cc_runtime__1_5_0//:runtime": "1.5.0",
            "@io_cocotec_coco_cc_runtime__local//:runtime": "local",
        },
        c_runtimes = {"@io_cocotec_coco_c_runtime__1_5_1//:runtime": "1.5.1"},
    )

    asserts.true(env, 'load("@rules_coco//coco/private:version_registry.bzl", "coco_version_registry")' in build, build)
    asserts.true(env, 'versions = ["1.5.0", "1.5.1", "local"],' in build, build)
    asserts.true(env, 'default = "1.5.0",' in build, build)
    asserts.true(env, 'host = "linux_x86_64",' in build, build)
    asserts.true(env, '"@io_cocotec_coco_cc_runtime__1_5_0//:runtime": "1.5.0"' in build, build)
    asserts.true(env, '"@io_cocotec_coco_cc_runtime__local//:runtime": "local"' in build, build)
    asserts.true(env, 'c_runtimes = {"@io_cocotec_coco_c_runtime__1_5_1//:runtime": "1.5.1"},' in build, build)

    # The :versions target every coco_package depends on must not pull in any runtime, and
    # each runtime registry only its own kind.
    versions_target = build[build.index('name = "versions"'):build.index('name = "cc_runtimes"')]
    cc_target = build[build.index('name = "cc_runtimes"'):build.index('name = "c_runtimes"')]
    c_target = build[build.index('name = "c_runtimes"'):]
    asserts.true(env, "runtime__" not in versions_target, versions_target)
    asserts.true(env, "@io_cocotec_coco_c_runtime__" not in cc_target, cc_target)
    asserts.true(env, "@io_cocotec_coco_cc_runtime__1_5_0" in cc_target, cc_target)
    asserts.true(env, "@io_cocotec_coco_cc_runtime__" not in c_target, c_target)
    asserts.true(env, "@io_cocotec_coco_c_runtime__1_5_1" in c_target, c_target)

    return unittest.end(env)

def _version_registry_build_without_runtimes_test(ctx):
    """With cc and c disabled the runtime maps are empty, not missing."""
    env = unittest.begin(ctx)

    build = render_version_registry_build(versions = ["1.5.7"], default = "1.5.7")

    asserts.true(env, "cc_runtimes = {}," in build, build)
    asserts.true(env, "c_runtimes = {}," in build, build)
    asserts.true(env, 'host = "",' in build, build)

    return unittest.end(env)

version_registry_build_test = unittest.make(_version_registry_build_test)
version_registry_build_without_runtimes_test = unittest.make(_version_registry_build_without_runtimes_test)

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
    asserts.true(env, "(through " in warnings[0] and "//:ws)" in warnings[0], warnings[0])

    return unittest.end(env)

def _pin_warnings_sorted_test(ctx):
    """Warnings are sorted by label, so their order doesn't depend on depset traversal."""
    env = unittest.begin(ctx)

    warnings = pin_warnings(Label("//:p1"), "1.5.0", [_pin("//:b", "1.5.1"), _pin("//:a", "1.5.1")])

    asserts.equals(env, 2, len(warnings))
    asserts.true(env, "//:a pins" in warnings[0] and "//:b pins" in warnings[1], warnings)

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
        cc_runtime_deps_local_version_test,
        cc_runtime_deps_non_root_rejected_test,
        cc_runtime_deps_non_root_rejected_even_when_root_also_present_test,
        cc_runtime_deps_unknown_version_test,

        # find_local_license tests
        local_license_linux_test,
        local_license_picks_its_own_version_test,
        local_license_xdg_data_home_test,
        local_license_popili_data_test,
        local_license_mac_test,
        local_license_windows_test,
        local_license_windows_appdata_fallback_test,
        local_license_windows_locallow_fallback_test,
        host_platform_test,
        local_license_unset_home_test,

        # license_versions.bzl tests
        license_version_test,
        parse_version_json_test,
        is_newer_than_known_test,
        license_representatives_test,

        # licence repository BUILD file tests
        fetch_license_build_test,
        fetch_license_build_without_token_test,
        local_license_build_test,
        known_license_versions_test,
        toolchain_build_declares_licenses_test,

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
        platform_key_test,

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
        hub_build_constraints_test,
        hub_build_runtime_aliases_test,

        # BUILD_for_coco_toolchain tests
        toolchain_build_records_platform_test,
        toolchain_build_records_version_test,

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

        # render_version_registry_build tests
        version_registry_build_test,
        version_registry_build_without_runtimes_test,

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
