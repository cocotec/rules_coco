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
load(":coco.bzl", "compute_output_filenames", "mangle_name")

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
    )
