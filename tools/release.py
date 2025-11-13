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

"""Release script for rules_coco.

This script manages version updates across version.bzl and MODULE.bazel files.
It can automatically increment versions or accept explicit version strings.

Usage:
    # Auto-increment patch version (0.1.0 -> 0.1.1)
    python tools/release.py --bump patch

    # Auto-increment minor version (0.1.0 -> 0.2.0)
    python tools/release.py --bump minor

    # Auto-increment major version (0.1.0 -> 1.0.0)
    python tools/release.py --bump major

    # Set explicit version
    python tools/release.py --version 1.2.3

    # Preview changes without writing
    python tools/release.py --version 1.2.3 --dry-run
"""

import argparse
import re
import sys
from pathlib import Path
from typing import Tuple

# Paths relative to repository root
REPO_ROOT = Path(__file__).resolve().parent.parent
VERSION_BZL = REPO_ROOT / "version.bzl"
MODULE_BAZEL = REPO_ROOT / "MODULE.bazel"

# Regex patterns for finding version strings
VERSION_BZL_PATTERN = re.compile(r'^VERSION = "([0-9]+\.[0-9]+\.[0-9]+)"$', re.MULTILINE)
MODULE_VERSION_PATTERN = re.compile(
    r'^(\s*version\s*=\s*)"([0-9]+\.[0-9]+\.[0-9]+)"(,?)$', re.MULTILINE
)


def parse_version(version_str: str) -> Tuple[int, int, int]:
    """Parse a semantic version string into (major, minor, patch) tuple."""
    parts = version_str.split('.')
    if len(parts) != 3:
        raise ValueError(f"Invalid version format: {version_str}")
    try:
        return (int(parts[0]), int(parts[1]), int(parts[2]))
    except ValueError:
        raise ValueError(f"Invalid version format: {version_str}")


def format_version(major: int, minor: int, patch: int) -> str:
    """Format a version tuple as a string."""
    return f"{major}.{minor}.{patch}"


def bump_version(version_str: str, bump_type: str) -> str:
    """Increment a version string based on bump type (major, minor, patch)."""
    major, minor, patch = parse_version(version_str)

    if bump_type == "major":
        return format_version(major + 1, 0, 0)
    elif bump_type == "minor":
        return format_version(major, minor + 1, 0)
    elif bump_type == "patch":
        return format_version(major, minor, patch + 1)
    else:
        raise ValueError(f"Invalid bump type: {bump_type}")


def read_current_version() -> str:
    """Read the current version from version.bzl."""
    content = VERSION_BZL.read_text()
    match = VERSION_BZL_PATTERN.search(content)
    if not match:
        raise RuntimeError(f"Could not find VERSION in {VERSION_BZL}")
    return match.group(1)


def update_version_bzl(old_version: str, new_version: str, dry_run: bool) -> bool:
    """Update VERSION in version.bzl. Returns True if changes were made."""
    content = VERSION_BZL.read_text()
    new_content = VERSION_BZL_PATTERN.sub(f'VERSION = "{new_version}"', content)

    if content == new_content:
        print(f"⚠️  No changes needed in {VERSION_BZL}")
        return False

    if dry_run:
        print(f"Would update {VERSION_BZL}:")
        print(f"  VERSION = \"{old_version}\" -> VERSION = \"{new_version}\"")
    else:
        VERSION_BZL.write_text(new_content)
        print(f"✓ Updated {VERSION_BZL}: {old_version} -> {new_version}")

    return True


def update_module_bazel(old_version: str, new_version: str, dry_run: bool) -> bool:
    """Update version in MODULE.bazel. Returns True if changes were made."""
    content = MODULE_BAZEL.read_text()

    def replace_version(match):
        return f'{match.group(1)}"{new_version}"{match.group(3)}'

    new_content = MODULE_VERSION_PATTERN.sub(replace_version, content)

    if content == new_content:
        print(f"⚠️  No changes needed in {MODULE_BAZEL}")
        return False

    if dry_run:
        print(f"Would update {MODULE_BAZEL}:")
        print(f"  version = \"{old_version}\" -> version = \"{new_version}\"")
    else:
        MODULE_BAZEL.write_text(new_content)
        print(f"✓ Updated {MODULE_BAZEL}: {old_version} -> {new_version}")

    return True


def main():
    parser = argparse.ArgumentParser(
        description="Manage version updates for rules_coco",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )

    version_group = parser.add_mutually_exclusive_group(required=True)
    version_group.add_argument(
        "--version",
        type=str,
        help="Explicit version to set (e.g., 1.2.3)"
    )
    version_group.add_argument(
        "--bump",
        choices=["major", "minor", "patch"],
        help="Auto-increment version (major, minor, or patch)"
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview changes without writing files"
    )

    args = parser.parse_args()

    try:
        # Read current version
        current_version = read_current_version()
        print(f"Current version: {current_version}")

        # Determine new version
        if args.version:
            # Validate explicit version format
            parse_version(args.version)
            new_version = args.version
        else:
            # Auto-increment based on bump type
            new_version = bump_version(current_version, args.bump)

        print(f"New version: {new_version}")

        if current_version == new_version:
            print("⚠️  New version is the same as current version. No changes made.")
            return 0

        if args.dry_run:
            print("\n🔍 DRY RUN MODE - No files will be modified\n")
        else:
            print()

        # Update both files
        changed_bzl = update_version_bzl(current_version, new_version, args.dry_run)
        changed_module = update_module_bazel(current_version, new_version, args.dry_run)

        if not (changed_bzl or changed_module):
            print("\n⚠️  No files were modified")
            return 1

        if args.dry_run:
            print("\n✓ Dry run completed successfully")
        else:
            print("\n✓ Version update completed successfully")
            print(f"\nNext steps:")
            print(f"  1. Review changes: git diff")
            print(f"  2. Commit changes: git commit -am 'build: bump version to {new_version}'")
            print(f"  3. Push changes: git push")

        return 0

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
