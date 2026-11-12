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

"""Which releases may be made from which branch. See RELEASING.md.

Minor (and major) releases come from `main`; patch releases come from the
`release/X.Y` branch of their minor. Commitizen's own rules size the
conventional commits since the previous release tag; a patch release must not
contain a `feat` or a breaking change.

Usage (with commitizen installed from tools/requirements-release.txt):

    # The version the "Prepare release" workflow bumps to: derived from the
    # commits, or the one given, if the branch may release it.
    python3 tools/release_policy.py next-version --ref refs/heads/main
    python3 tools/release_policy.py next-version --ref refs/heads/main --version 1.0.0

    # What the pull request of a release with a given version must say.
    python3 tools/release_policy.py release-as-note --ref refs/heads/release/0.4 --version 0.4.2

    # Whether version.bzl may be released from this branch.
    python3 tools/release_policy.py check-release --ref refs/heads/release/0.4

    # Whether a pull request may be merged into its base branch, run on its
    # merge commit: the title is a conventional commit, a release branch gets
    # no `feat` or breaking change, and a version bump is one the Release
    # workflow will accept.
    python3 tools/release_policy.py check-pull-request --base release/0.4 --title "fix(rules): ..." --body "..."

    # The same for the commits a merge queue is about to add to a branch, run
    # on the merge group's commit.
    python3 tools/release_policy.py check-merge-group --base-ref refs/heads/release/0.4 --base-rev <sha>

    # The version and the previous release, as `key=value` lines for
    # $GITHUB_OUTPUT.
    python3 tools/release_policy.py release-outputs

These need no commitizen, only git:

    # The version in version.bzl.
    python3 tools/release_policy.py current-version

    # Fails if version.bzl holds a version that is not released yet.
    python3 tools/release_policy.py check-version-released

    # Whether version.bzl becomes GitHub's "Latest" release: true or false.
    python3 tools/release_policy.py is-latest

    # The release/X.Y branch on the remote that new Popili digests are
    # released from: that of the newest release, or the one given. Prints
    # nothing while there is no release branch at all.
    python3 tools/release_policy.py digests-branch
    python3 tools/release_policy.py digests-branch --branch release/0.4
"""

import argparse
import functools
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Callable, Iterable, List, Optional, Sequence, Tuple

import release

REPO_ROOT = Path(__file__).resolve().parent.parent

Version = Tuple[int, int, int]

_VERSION_PATTERN = re.compile(r"^([0-9]+)\.([0-9]+)\.([0-9]+)$")
_RELEASE_BRANCH_PATTERN = re.compile(r"^release/([0-9]+)\.([0-9]+)$")
_BRANCH_REF_PREFIX = "refs/heads/"


class PolicyError(Exception):
    pass


class NotAPatchError(PolicyError):
    """The commits of a release branch hold a `feat` or a breaking change."""


def format_version(version: Version) -> str:
    return release.format_version(*version)


def branch_of_ref(ref: str) -> str:
    """Returns the branch of `refs/heads/<branch>`.

    A tag can be named like a branch (`main`, `release/0.4`), and a workflow
    can be started from one, so the short ref name does not say which it is.
    """
    if not ref.startswith(_BRANCH_REF_PREFIX):
        raise PolicyError(f"Releases are made from a branch, not from {ref!r}.")
    return ref[len(_BRANCH_REF_PREFIX) :]


def release_branch_series(branch: str) -> Optional[Tuple[int, int]]:
    """Returns (major, minor) for `release/X.Y`, None for any other branch."""
    match = _RELEASE_BRANCH_PATTERN.match(branch)
    if not match:
        return None
    return (int(match.group(1)), int(match.group(2)))


def parse_version(text: str) -> Version:
    """Parses a version that a person typed; stricter than release.parse_version()."""
    if not _VERSION_PATTERN.match(text):
        raise PolicyError(f"Not a MAJOR.MINOR.PATCH version: {text!r}")
    return release.parse_version(text)


def newest_release_branch(branches: Iterable[str], released: Iterable[Version]) -> Optional[str]:
    """The release branch that new Popili digests are released from: that of the newest release.

    Args:
      branches: the branches of the repository.
      released: the versions released so far.

    Returns:
      None while there is no release branch at all, i.e. before the first
      release under this scheme.
    """
    series = sorted(filter(None, map(release_branch_series, branches)))
    if not series:
        return None
    newest = max(released, default=None)
    if newest is not None and newest[:2] > series[-1]:
        raise PolicyError(
            f"{format_version(newest)} is released, but release/{newest[0]}.{newest[1]} does not exist, so the "
            f"digests would go to release/{series[-1][0]}.{series[-1][1]} only. Create the branch (see RELEASING.md), "
            f"or pass `branch` to release the digests from an older one."
        )
    return "release/%d.%d" % series[-1]


def step(previous: Version, new: Version) -> Optional[str]:
    """Classifies the step from `previous` to `new` as "major", "minor" or "patch"; None if it is not a step up."""
    if new <= previous:
        return None
    return release.classify_bump(format_version(previous), format_version(new))


def next_version(branch: str, previous: Version, increment: Optional[str]) -> Version:
    """The version to release from `branch`.

    Args:
      branch: the branch the release is prepared on.
      previous: the newest release tag reachable from the branch.
      increment: what commitizen makes of the commits since `previous`:
        "major", "minor", "patch", or None when they warrant no release.
    """
    if branch == "main":
        # A release from main always starts a new release/X.Y branch, so it is
        # at least a minor release, even when main only has fixes.
        if increment == "major":
            return (previous[0] + 1, 0, 0)
        return (previous[0], previous[1] + 1, 0)

    series = release_branch_series(branch)
    if series is None:
        raise PolicyError(f"Releases are made from main or a release/X.Y branch, not from {branch!r}.")
    if previous[:2] != series:
        raise PolicyError(
            f"The newest release tag on {branch} is {format_version(previous)}, "
            f"which is not a {series[0]}.{series[1]}.x release."
        )
    _check_patch_increment(branch, previous, increment)
    return (previous[0], previous[1], previous[2] + 1)


def check_release(branch: str, version: Version, previous: Version, increment: Optional[str]) -> None:
    """Raises PolicyError unless `version` may be released from `branch`.

    Args:
      branch: the branch being released.
      version: the version in version.bzl.
      previous: the newest release tag reachable from the branch.
      increment: as for next_version().
    """
    bump = step(previous, version)
    if bump is None:
        raise PolicyError(
            f"{format_version(version)} is not newer than the previous release {format_version(previous)}."
        )

    if branch == "main":
        if bump == "patch":
            raise PolicyError(
                f"{format_version(version)} is a patch release; patch releases are made from "
                f"release/{version[0]}.{version[1]}, not from main."
            )
        return

    series = release_branch_series(branch)
    if series is None:
        raise PolicyError(f"Releases are made from main or a release/X.Y branch, not from {branch!r}.")
    if version[:2] != series or bump != "patch":
        raise PolicyError(
            f"{branch} only releases {series[0]}.{series[1]}.x patch releases, "
            f"not {format_version(version)} (previous release {format_version(previous)})."
        )
    _check_patch_increment(branch, previous, increment)


def _check_patch_increment(branch: str, previous: Version, increment: Optional[str]) -> None:
    if increment in ("minor", "major"):
        raise NotAPatchError(
            f"The commits on {branch} since {format_version(previous)} call for a {increment} "
            f"release (a `feat` or a breaking change), but {branch} only makes patch releases; "
            f"features and breaking changes ship from main. Reverting them does not change this, since "
            f"they stay in the history: revert them in a pull request into {branch}, then run Prepare "
            f"Release on {branch} with `version` set, which releases that version regardless."
        )


def is_latest(version: Version, released: Iterable[Version]) -> bool:
    """Whether no release is newer than `version`, so GitHub should mark it "Latest".

    A patch release of an older series, e.g. 0.4.2 after 0.5.0, is not.
    """
    return all(version >= other for other in released)


def is_release_as(messages: Iterable[str], version: Version) -> bool:
    """Whether one of the commit `messages` has the footer `Release-As: <version>`.

    The pull request of a release whose version was given by hand carries it
    (see release_as_note()). Such a release is not held to what commitizen
    makes of the commits.
    """
    footer = f"Release-As: {format_version(version)}"
    return any(line.strip() == footer for message in messages for line in message.split("\n"))


def release_as_note(version: Version, waived: Sequence[str]) -> str:
    """The part of a pull request description that releases `version` because it was asked for.

    Args:
      version: the version given by hand.
      waived: the commits (hash and subject) that the release policy would
        refuse to release in this version.
    """
    lines = ["The version was set by hand (the `version` input of Prepare Release), not derived from the commits."]
    if waived:
        lines += [
            "That skips the check that a patch release holds no `feat` and no breaking change. It would refuse these "
            "commits; make sure each one is reverted or belongs in this release.",
            "",
            *(f"* {commit}" for commit in waived),
        ]
    return "\n".join(lines + ["", f"Release-As: {format_version(version)}"])


def commit_message(title: str, body: str = "") -> str:
    """The message of the commit that squash-merging a pull request creates."""
    return f"{title}\n\n{body}".strip()


def check_message(
    base: str,
    message: str,
    increment_of: Callable[[List[str]], Optional[str]],
    is_conventional: Callable[[str], bool],
) -> None:
    """Raises PolicyError if a pull request that is squashed into `message` may not be merged into `base`.

    The message must be a conventional commit, which is what commitizen sizes
    releases by. That includes reverts: `revert: ...`, not the `Revert "..."`
    that GitHub and git propose, which would hide what a revert of a revert
    brings back.

    A release branch only takes changes that fit a patch release. Commitizen
    reads every line of a commit message, so a `BREAKING CHANGE:` footer or a
    line such as `feat: ...` in the description makes the next release a minor
    one just like the title does.

    Args:
      base: the branch the pull request is merged into.
      message: see commit_message().
      increment_of: commitizen's verdict on a list of commit messages; see
        increment_of_messages().
      is_conventional: commitizen's verdict on the format of a commit message;
        see is_conventional_commit().
    """
    if not is_conventional(message):
        raise PolicyError(
            f"{message.splitlines()[0]!r} is not a conventional commit, such as `fix(rules): ...` or "
            f"`revert: ...`; see RELEASING.md."
        )
    if release_branch_series(base) is None:
        return
    for number, line in enumerate(message.split("\n")):
        if increment_of([line]) not in ("minor", "major"):
            continue
        if number == 0:
            raise PolicyError(
                f"{base} only takes changes for a patch release: no `feat` and no breaking change (`!`). "
                f"Merge {line!r} into main instead."
            )
        raise PolicyError(
            f"The description has the line {line.strip()!r}. It becomes part of the squashed commit, where "
            f"commitizen reads it as a `feat` or a breaking change, and {base} only makes patch releases. "
            f"Reword the line or put it in a list (`* ...`), or merge into main instead."
        )


@functools.lru_cache(maxsize=None)
def _bump_rules():
    """Commitizen's bump pattern and map for this repository's .cz.toml, as `cz bump` picks them."""
    from commitizen.config import read_cfg
    from commitizen.factory import committer_factory

    config = read_cfg(str(REPO_ROOT / ".cz.toml"))
    cz = committer_factory(config)
    bump_map = cz.bump_map_major_version_zero if config.settings["major_version_zero"] else cz.bump_map
    return cz, cz.bump_pattern, bump_map


def is_conventional_commit(message: str) -> bool:
    """Whether `cz check` accepts `message`, without the prefixes (`Merge`, `Revert`, `fixup!`, ...) it lets through."""
    cz, _, _ = _bump_rules()
    return bool(re.match(cz.schema_pattern(), message))


def increment_of_messages(messages: List[str]) -> Optional[str]:
    """What `cz bump` makes of commits with these messages: "major", "minor", "patch" or None."""
    from commitizen.version_increment import VersionIncrement

    _, pattern, bump_map = _bump_rules()
    increment = VersionIncrement.get_highest_by_messages(messages, pattern, bump_map)
    return None if increment == VersionIncrement.NONE else str(increment).lower()


def _commits_since(previous: Version, rev: str = "HEAD") -> list:
    """Commitizen's view of the commits after the `previous` release up to `rev`, newest first."""
    from commitizen import git as cz_git

    cz, _, _ = _bump_rules()
    return cz.filter_commits_before_bump(cz_git.get_commits(format_version(previous), rev))


def _messages_since(previous: Version) -> List[str]:
    """The messages of the commits after the `previous` release."""
    messages = [commit.message for commit in _commits_since(previous)]
    if not messages:
        raise PolicyError("Nothing to release: there are no commits since the previous release.")
    return messages


def _unfit_for_patch(branch: str, previous: Version, rev: str = "HEAD") -> List[str]:
    """The commits (hash and subject) since `previous` that the release branch `branch` may not release."""
    if release_branch_series(branch) is None:
        return []
    return [
        f"{commit.rev[:12]} {commit.title}"
        for commit in _commits_since(previous, rev)
        if increment_of_messages([commit.message]) in ("minor", "major")
    ]


def _increment_for(version: Version, messages: List[str]) -> Optional[str]:
    """What `cz bump` makes of `messages`, unless they ask for `version` by name."""
    if is_release_as(messages, version):
        print(f"Releasing {format_version(version)} as its `Release-As` footer asks, whatever the commits call for.")
        return None
    return increment_of_messages(messages)


def _git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=REPO_ROOT, check=True, capture_output=True, text=True).stdout


def _release_tags(*args: str) -> List[Version]:
    return [release.parse_version(tag) for tag in _git("tag", "--list", *args).split() if _VERSION_PATTERN.match(tag)]


def _remote_refs(kind: str, pattern: str) -> List[str]:
    """The names of the remote's branches (`kind` "heads") or tags ("tags") that match `pattern`."""
    prefix = f"refs/{kind}/"
    lines = _git("ls-remote", f"--{kind}", "origin", prefix + pattern).splitlines()
    return [line.split("\t")[1][len(prefix) :] for line in lines]


def _remote_releases() -> List[Version]:
    return [release.parse_version(tag) for tag in _remote_refs("tags", "*") if _VERSION_PATTERN.match(tag)]


def _previous_release(rev: str = "HEAD") -> Version:
    """The newest release tag reachable from `rev`."""
    versions = _release_tags("--merged", rev)
    if not versions:
        raise PolicyError(f"No release tag is reachable from {rev}; fetch the tags (fetch-depth: 0).")
    return max(versions)


def _version_bzl(rev: Optional[str] = None) -> Version:
    """The version in version.bzl: of the working tree, or of commit `rev`."""
    if rev is None:
        return release.parse_version(release.read_current_version())
    match = release.VERSION_BZL_PATTERN.search(_git("show", f"{rev}:version.bzl"))
    if not match:
        raise PolicyError(f"No VERSION in version.bzl at {rev}")
    return release.parse_version(match.group(1))


def _check_unreleased(version: Version) -> None:
    if _git("tag", "--list", format_version(version)).strip():
        raise PolicyError(f"Release {format_version(version)} already exists.")


def _check_version_released(branch: str) -> None:
    """Raises PolicyError if version.bzl holds a version that the Release workflow has not released (yet)."""
    version = _version_bzl()
    if version > _previous_release():
        _check_unreleased(version)
        raise PolicyError(
            f"version.bzl already says {format_version(version)}, which has not been released. "
            f"Run the Release workflow on {branch} to release it."
        )


def _check_version_change(base: str, base_rev: str, messages: List[str]) -> None:
    """Checks the version that the commits after `base_rev`, with `messages`, leave in version.bzl.

    A change of the version releases it when it lands on main or a release
    branch, so it is held to what the Release workflow will check after the
    merge, when a refusal leaves the bump behind without a release.
    """
    version = _version_bzl()
    if version == _version_bzl(base_rev) or (base != "main" and release_branch_series(base) is None):
        return
    previous = _previous_release(base_rev)
    if version == previous:
        # Takes back a bump that was not released; the Release workflow will refuse to run, as it should.
        return
    _check_unreleased(version)
    history = [commit.message for commit in _commits_since(previous, base_rev)]
    check_release(base, version, previous, _increment_for(version, messages + history))
    print(f"Merging releases {format_version(version)} from {base}.")


def _check_pull_request(base: str, base_rev: str, title: str, body: str) -> None:
    message = commit_message(title, body)
    check_message(base, message, increment_of_messages, is_conventional_commit)
    _check_version_change(base, base_rev, [message])


def _check_merge_group(base: str, base_rev: str) -> None:
    """Checks the commits after `base_rev` that a merge queue is about to add to `base`.

    Unlike a pull request's title and description, these are the commits the
    Release workflow will read, whatever the repository's squash settings make
    of a pull request.
    """
    from commitizen import git as cz_git

    messages = [commit.message for commit in cz_git.get_commits(base_rev, "HEAD")]
    for message in messages:
        check_message(base, message, increment_of_messages, is_conventional_commit)
    _check_version_change(base, base_rev, messages)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    next_parser = commands.add_parser("next-version", help="print the version to prepare a release of")
    next_parser.add_argument("--ref", required=True, help="the full ref to release from, e.g. refs/heads/main")
    next_parser.add_argument(
        "--version", type=parse_version, help="release this version instead of the one the commits call for"
    )
    note_parser = commands.add_parser("release-as-note", help="print the description of a release with a given version")
    note_parser.add_argument("--ref", required=True, help="the full ref to release from, e.g. refs/heads/main")
    note_parser.add_argument("--version", required=True, type=parse_version)
    release_parser = commands.add_parser("check-release", help="check version.bzl may be released")
    release_parser.add_argument("--ref", required=True, help="the full ref to release from, e.g. refs/heads/main")
    pr_parser = commands.add_parser("check-pull-request", help="check a pull request, on its merge commit")
    pr_parser.add_argument("--base", required=True, help="the branch the pull request is merged into")
    pr_parser.add_argument("--base-rev", default="HEAD^1", help="the commit of the base branch (default: HEAD^1)")
    pr_parser.add_argument("--title", required=True)
    pr_parser.add_argument("--body", default="")
    group_parser = commands.add_parser("check-merge-group", help="check a merge group, on its commit")
    group_parser.add_argument("--base-ref", required=True, help="the full ref the group is merged into")
    group_parser.add_argument("--base-rev", required=True, help="the commit of the base branch the group starts from")
    commands.add_parser("release-outputs", help="print version= and previous= for the Release workflow")
    commands.add_parser("current-version", help="print the version in version.bzl")
    commands.add_parser("check-version-released", help="check version.bzl holds a released version")
    commands.add_parser("is-latest", help="print whether version.bzl becomes GitHub's Latest release")
    digests_parser = commands.add_parser("digests-branch", help="print the release branch to release digests from")
    digests_parser.add_argument("--branch", help="release from this branch instead of that of the newest release")
    try:
        args = parser.parse_args()
    except PolicyError as e:
        parser.error(str(e))

    # Commitizen runs git in the working directory.
    os.chdir(REPO_ROOT)
    try:
        if args.command == "next-version":
            branch = branch_of_ref(args.ref)
            _check_version_released(branch)
            previous = _previous_release()
            if args.version:
                version = args.version
                _check_unreleased(version)
                check_release(branch, version, previous, None)
            else:
                version = next_version(branch, previous, increment_of_messages(_messages_since(previous)))
            print(format_version(version))
        elif args.command == "release-as-note":
            branch = branch_of_ref(args.ref)
            print(release_as_note(args.version, _unfit_for_patch(branch, _previous_release())))
        elif args.command == "check-release":
            branch = branch_of_ref(args.ref)
            version = _version_bzl()
            _check_unreleased(version)
            previous = _previous_release()
            check_release(branch, version, previous, _increment_for(version, _messages_since(previous)))
            print(f"{format_version(version)} may be released from {branch}.")
        elif args.command == "check-pull-request":
            _check_pull_request(args.base, args.base_rev, args.title, args.body)
        elif args.command == "check-merge-group":
            _check_merge_group(branch_of_ref(args.base_ref), args.base_rev)
        elif args.command == "release-outputs":
            version = _version_bzl()
            print(f"version={format_version(version)}")
            print(f"previous={format_version(_previous_release())}")
        elif args.command == "current-version":
            print(format_version(_version_bzl()))
        elif args.command == "check-version-released":
            _check_version_released(_git("rev-parse", "--abbrev-ref", "HEAD").strip())
        elif args.command == "is-latest":
            print(str(is_latest(_version_bzl(), _remote_releases())).lower())
        elif args.command == "digests-branch":
            branches = _remote_refs("heads", "release/*")
            if args.branch is None:
                print(newest_release_branch(branches, _remote_releases()) or "")
            elif release_branch_series(args.branch) is None or args.branch not in branches:
                raise PolicyError(f"{args.branch!r} is not a release/X.Y branch of this repository.")
            else:
                print(args.branch)
    except subprocess.CalledProcessError as e:
        print(f"Error: {' '.join(e.cmd)} failed:\n{e.stderr}", file=sys.stderr)
        return 1
    except (PolicyError, ValueError, RuntimeError) as e:
        print(f"Error: {e}", file=sys.stderr)
        if isinstance(e, NotAPatchError):
            # Of the branch as it is; the commits of the pull request or merge group were checked one by one.
            if args.command == "check-pull-request":
                branch, rev = args.base, args.base_rev
            elif args.command == "check-merge-group":
                branch, rev = branch_of_ref(args.base_ref), args.base_rev
            else:
                branch, rev = branch_of_ref(args.ref), "HEAD"
            print("The commits:", *_unfit_for_patch(branch, _previous_release(rev), rev), sep="\n  ", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
