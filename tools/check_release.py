#!/usr/bin/env python3

# Copyright 2026 Cocotec Limited
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
"""Checks which version a branch may release.

Minor and major releases (X.Y.0) come from main; patch releases (X.Y.N) come from
release/X.Y, which starts at the X.Y.0 tag.

Usage:
    # Print commit=, version=, previous= and latest= for the Release workflow
    python tools/check_release.py release --branch release/0.4

    # Print the release branch that new Popili digests should be released from
    python tools/check_release.py digests-branch
"""

import argparse
import re
import subprocess
import sys
from typing import List, Optional, Tuple

Version = Tuple[int, int, int]

RELEASE_BRANCH = re.compile(r'^release/([0-9]+)\.([0-9]+)$')
VERSION = re.compile(r'^([0-9]+)\.([0-9]+)\.([0-9]+)$')
VERSION_BZL = re.compile(r'^VERSION = "([0-9]+\.[0-9]+\.[0-9]+)"$',
                         re.MULTILINE)


class ReleaseError(Exception):
    pass


def git(*args: str) -> str:
    return subprocess.run(['git', *args],
                          check=True,
                          capture_output=True,
                          text=True).stdout.strip()


def parse(version: str) -> Version:
    match = VERSION.match(version)
    if not match:
        raise ReleaseError(f"'{version}' is not a version")
    return (int(match[1]), int(match[2]), int(match[3]))


def fmt(version: Version) -> str:
    return '.'.join(str(part) for part in version)


def released() -> List[Version]:
    return sorted(
        parse(tag) for tag in git('tag', '--list').split()
        if VERSION.match(tag))


def is_ancestor(tag: Version, commit: str) -> bool:
    return subprocess.run(
        ['git', 'merge-base', '--is-ancestor', f'refs/tags/{fmt(tag)}',
         commit]).returncode == 0


def branch_commit(branch: str) -> str:
    if branch != 'main' and not RELEASE_BRANCH.match(branch):
        raise ReleaseError(
            f"Releases come from main or release/X.Y, not '{branch}'")
    try:
        return git('rev-parse', '--verify',
                   f'refs/remotes/origin/{branch}^{{commit}}')
    except subprocess.CalledProcessError:
        raise ReleaseError(f"There is no branch '{branch}'")


def version_at(commit: str) -> Version:
    match = VERSION_BZL.search(git('show', f'{commit}:version.bzl'))
    if not match:
        raise ReleaseError(f'No VERSION in version.bzl at {commit}')
    return parse(match[1])


def check_release(branch: str, commit: str) -> Tuple[Version, Optional[Version], bool]:
    """Returns the version to release, the release before it and whether it is the newest."""
    tags = released()
    version = version_at(commit)
    if version in tags:
        raise ReleaseError(f'{fmt(version)} has been released already')

    if branch == 'main':
        if version[2] != 0:
            raise ReleaseError(
                f'main releases X.Y.0 versions, not {fmt(version)}; patch releases '
                'come from release/X.Y')
        if tags and version < tags[-1]:
            raise ReleaseError(
                f'{fmt(version)} is older than the newest release, {fmt(tags[-1])}'
            )
    else:
        match = RELEASE_BRANCH.match(branch)
        if not match:
            raise ReleaseError(
                f"Releases come from main or release/X.Y, not '{branch}'")
        series = (int(match[1]), int(match[2]))
        if version[:2] != series or version[2] == 0:
            raise ReleaseError(
                f'{branch} releases {series[0]}.{series[1]}.N patch versions, not '
                f'{fmt(version)}')
        for needed in sorted({(*series, 0), (*series, version[2] - 1)}):
            if needed not in tags or not is_ancestor(needed, commit):
                raise ReleaseError(
                    f'{fmt(version)} must follow {fmt(needed)} on {branch}')

    previous = max((tag for tag in tags if is_ancestor(tag, commit)),
                   default=None)
    latest = not tags or version > tags[-1]
    return version, previous, latest


def digests_branch() -> str:
    tags = released()
    if not tags:
        raise ReleaseError('Nothing has been released yet')
    newest = tags[-1]
    branch = f'release/{newest[0]}.{newest[1]}'
    try:
        branch_commit(branch)
    except ReleaseError:
        raise ReleaseError(
            f'{fmt(newest)} has no release branch. An admin creates {branch} with:\n'
            '  python tools/release.py --create-release-branch')
    return branch


def main() -> int:
    parser = argparse.ArgumentParser(
        description='Check which version a branch may release',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    release = commands.add_parser('release')
    release.add_argument('--branch', required=True)
    release.add_argument('--commit',
                         help='Commit to release (default: the head of --branch)')
    commands.add_parser('digests-branch')
    args = parser.parse_args()

    try:
        if args.command == 'release':
            commit = args.commit or branch_commit(args.branch)
            if args.commit and not re.fullmatch(r'[0-9a-f]{40}', commit):
                raise ReleaseError(f"'{commit}' is not a full commit hash")
            version, previous, latest = check_release(args.branch, commit)
            print(f'commit={commit}')
            print(f'version={fmt(version)}')
            print(f'previous={fmt(previous) if previous else ""}')
            print(f'latest={"true" if latest else "false"}')
        else:
            print(digests_branch())
    except ReleaseError as e:
        print(f'Error: {e}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
