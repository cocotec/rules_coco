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

"""Tests for the release policy in release_policy.py."""

import importlib.util
import unittest

from release_policy import (
    PolicyError,
    branch_of_ref,
    check_message,
    check_release,
    commit_message,
    increment_of_messages,
    is_conventional_commit,
    is_latest,
    newest_release_branch,
    parse_version,
    is_release_as,
    next_version,
    release_as_note,
)


class BranchOfRefTest(unittest.TestCase):
    def test_branch(self):
        self.assertEqual("release/0.4", branch_of_ref("refs/heads/release/0.4"))

    def test_tag_named_like_a_branch(self):
        with self.assertRaisesRegex(PolicyError, "not from 'refs/tags/main'"):
            branch_of_ref("refs/tags/main")


class ParseVersionTest(unittest.TestCase):
    def test_version(self):
        self.assertEqual((0, 10, 2), parse_version("0.10.2"))

    def test_what_int_would_take(self):
        for text in ["0.5.-1", "1_0.0.0", "1.0", " 1.0.0"]:
            with self.subTest(text=text), self.assertRaisesRegex(PolicyError, "Not a MAJOR.MINOR.PATCH"):
                parse_version(text)


class NewestReleaseBranchTest(unittest.TestCase):
    def test_newest_by_number(self):
        branches = ["main", "release/0.4", "release/0.10", "release/0.4/x", "release/1"]
        self.assertEqual("release/0.10", newest_release_branch(branches, [(0, 4, 0), (0, 10, 1)]))

    def test_no_release_branch_yet(self):
        self.assertIsNone(newest_release_branch(["main"], [(0, 3, 4)]))

    def test_branch_of_the_newest_release_is_missing(self):
        with self.assertRaisesRegex(PolicyError, "0.5.0 is released, but release/0.5 does not exist"):
            newest_release_branch(["release/0.4"], [(0, 4, 2), (0, 5, 0)])


class NextVersionTest(unittest.TestCase):
    def test_main_follows_commitizen_for_a_minor(self):
        self.assertEqual((0, 4, 0), next_version("main", (0, 3, 4), "minor"))

    def test_main_follows_commitizen_for_a_major(self):
        self.assertEqual((1, 0, 0), next_version("main", (0, 9, 2), "major"))

    def test_main_is_at_least_a_minor(self):
        self.assertEqual((0, 4, 0), next_version("main", (0, 3, 4), "patch"))
        self.assertEqual((0, 4, 0), next_version("main", (0, 3, 4), None))

    def test_release_branch_is_a_patch(self):
        self.assertEqual((0, 4, 2), next_version("release/0.4", (0, 4, 1), "patch"))
        self.assertEqual((0, 4, 2), next_version("release/0.4", (0, 4, 1), None))

    def test_release_branch_rejects_a_feature(self):
        with self.assertRaisesRegex(PolicyError, "minor release"):
            next_version("release/0.4", (0, 4, 1), "minor")

    def test_release_branch_of_another_series(self):
        with self.assertRaisesRegex(PolicyError, "not a 0.5.x release"):
            next_version("release/0.5", (0, 4, 1), None)

    def test_other_branch(self):
        with self.assertRaisesRegex(PolicyError, "not from 'feat/x'"):
            next_version("feat/x", (0, 4, 1), None)


class CheckReleaseTest(unittest.TestCase):
    def test_main_minor(self):
        check_release("main", (0, 4, 0), (0, 3, 4), "minor")

    def test_main_patch(self):
        with self.assertRaisesRegex(PolicyError, "from release/0.3, not from main"):
            check_release("main", (0, 3, 5), (0, 3, 4), "minor")

    def test_not_newer(self):
        with self.assertRaisesRegex(PolicyError, "not newer"):
            check_release("main", (0, 3, 4), (0, 3, 4), None)

    def test_release_branch_patch(self):
        check_release("release/0.4", (0, 4, 1), (0, 4, 0), None)
        check_release("release/0.4", (0, 4, 1), (0, 4, 0), "patch")

    def test_release_branch_minor(self):
        with self.assertRaisesRegex(PolicyError, "only releases 0.4.x patch releases"):
            check_release("release/0.4", (0, 5, 0), (0, 4, 1), "minor")

    def test_release_branch_with_a_feature(self):
        with self.assertRaisesRegex(PolicyError, "call for a minor release"):
            check_release("release/0.4", (0, 4, 2), (0, 4, 1), "minor")


class IsLatestTest(unittest.TestCase):
    def test_newest(self):
        self.assertTrue(is_latest((0, 5, 0), [(0, 4, 0), (0, 4, 1)]))

    def test_patch_of_an_older_series(self):
        self.assertFalse(is_latest((0, 4, 2), [(0, 4, 1), (0, 5, 0)]))


class ReleaseAsTest(unittest.TestCase):
    NOTE = release_as_note((0, 4, 2), ["3f2a9c1e0b7d feat(rules): add x (#301)"])

    def test_note_names_the_version_and_the_commits(self):
        self.assertIn("* 3f2a9c1e0b7d feat(rules): add x (#301)", self.NOTE)
        self.assertTrue(is_release_as([commit_message("chore(release): 0.4.2", f"Bumps.\r\n\r\n{self.NOTE}")], (0, 4, 2)))

    def test_other_version(self):
        self.assertFalse(is_release_as(["fix: x", self.NOTE], (0, 4, 3)))
        self.assertFalse(is_release_as(["fix: x\n\nNot Release-As: 0.4.2 at all"], (0, 4, 2)))

    @unittest.skipUnless(importlib.util.find_spec("commitizen"), "needs commitizen")
    def test_note_does_not_change_the_size_of_the_release(self):
        check_message(
            "release/0.4",
            commit_message("chore(release): 0.4.2", self.NOTE),
            increment_of_messages,
            is_conventional_commit,
        )


# Bazel runs this test without commitizen; the PR Title workflow runs it with.
@unittest.skipUnless(importlib.util.find_spec("commitizen"), "needs commitizen (tools/requirements-release.txt)")
class CheckMessageTest(unittest.TestCase):
    def check(self, base, title, body=""):
        check_message(base, commit_message(title, body), increment_of_messages, is_conventional_commit)

    def test_main_takes_features_and_breaking_changes(self):
        self.check("main", "feat(rules)!: replace x", "BREAKING CHANGE: x")

    def test_title_must_be_a_conventional_commit(self):
        self.check("main", "revert: add x")
        for title in ["Add x", 'Revert "Revert "feat(rules): add x (#6)""', "Pull request to add x", "fixup! fix: x"]:
            for base in ["main", "release/0.4"]:
                with self.subTest(title=title, base=base), self.assertRaisesRegex(PolicyError, "not a conventional"):
                    self.check(base, title)

    def test_release_branch_takes_fixes(self):
        self.check("release/0.4", "fix(rules): quote env values")
        self.check("release/0.4", "chore(deps): update popili digests and release 0.4.1")
        self.check("release/0.4", "fix(rules): x", "Fixes y.\n\n* feat(rules): listed, so not read as a header")

    def test_release_branch_rejects_what_commitizen_reads_as_a_minor(self):
        for title in [
            "feat(rules): add x",
            "fix(rules)!: change x",
            "refactor!: drop x",
            "feat(select()): add x",
            "fix(a)(b)!: x",
        ]:
            with self.subTest(title=title), self.assertRaisesRegex(PolicyError, "Merge .* into main"):
                self.check("release/0.4", title)

    def test_release_branch_rejects_a_breaking_body(self):
        for line in [
            "feat: y",
            "feature: y",
            "feat2: y",
            "WARNING!: careful",
            "BREAKING CHANGE: y",
            "BREAKING-CHANGE: y",
            "BREAKING CHANGE(api): y",
        ]:
            with self.subTest(line=line), self.assertRaisesRegex(PolicyError, "The description has the line"):
                self.check("release/0.4", "fix(rules): x", f"Fixes y.\r\n\r\n{line}\r\n")


if __name__ == "__main__":
    unittest.main()
