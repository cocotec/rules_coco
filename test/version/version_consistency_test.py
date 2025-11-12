#!/usr/bin/env python3

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

"""Test to verify version consistency between version.bzl and MODULE.bazel."""

import re
import sys
import unittest
from pathlib import Path

# Find repository root (two levels up from this test file)
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
VERSION_BZL = REPO_ROOT / "version.bzl"
MODULE_BAZEL = REPO_ROOT / "MODULE.bazel"


def extract_version_from_bzl() -> str:
    """Extract VERSION from version.bzl."""
    content = VERSION_BZL.read_text()
    match = re.search(r'^VERSION = "([0-9]+\.[0-9]+\.[0-9]+)"$', content, re.MULTILINE)
    if not match:
        raise ValueError(f"Could not find VERSION in {VERSION_BZL}")
    return match.group(1)


def extract_version_from_module() -> str:
    """Extract version from MODULE.bazel."""
    content = MODULE_BAZEL.read_text()
    match = re.search(r'^\s*version\s*=\s*"([0-9]+\.[0-9]+\.[0-9]+)"', content, re.MULTILINE)
    if not match:
        raise ValueError(f"Could not find version in {MODULE_BAZEL}")
    return match.group(1)


class VersionConsistencyTest(unittest.TestCase):
    """Test that version.bzl and MODULE.bazel have the same version."""

    def test_version_consistency(self):
        """Verify that version.bzl and MODULE.bazel declare the same version."""
        version_bzl = extract_version_from_bzl()
        version_module = extract_version_from_module()

        self.assertEqual(
            version_bzl,
            version_module,
            f"Version mismatch!\n"
            f"  version.bzl:   VERSION = \"{version_bzl}\"\n"
            f"  MODULE.bazel:  version = \"{version_module}\"\n"
            f"\n"
            f"To fix this, run:\n"
            f"  bazel run //tools:release -- --version {version_bzl}"
        )

    def test_version_bzl_exists(self):
        """Verify that version.bzl exists."""
        self.assertTrue(VERSION_BZL.exists(), f"{VERSION_BZL} does not exist")

    def test_module_bazel_exists(self):
        """Verify that MODULE.bazel exists."""
        self.assertTrue(MODULE_BAZEL.exists(), f"{MODULE_BAZEL} does not exist")

    def test_version_format_bzl(self):
        """Verify that version.bzl has a valid semantic version."""
        version = extract_version_from_bzl()
        parts = version.split('.')
        self.assertEqual(len(parts), 3, f"Invalid version format in version.bzl: {version}")
        for part in parts:
            self.assertTrue(part.isdigit(), f"Invalid version component in version.bzl: {part}")

    def test_version_format_module(self):
        """Verify that MODULE.bazel has a valid semantic version."""
        version = extract_version_from_module()
        parts = version.split('.')
        self.assertEqual(len(parts), 3, f"Invalid version format in MODULE.bazel: {version}")
        for part in parts:
            self.assertTrue(part.isdigit(), f"Invalid version component in MODULE.bazel: {part}")


if __name__ == "__main__":
    # Run tests
    unittest.main()
