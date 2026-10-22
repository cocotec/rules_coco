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

"""Reads which popili a target resolved off what it would run, for analysis tests.

The popili lives in a version-mangled repository (`io_cocotec_coco_<os>_<arch>__<version>`), so
the path names the version in both bzlmod and WORKSPACE mode. Shared with e2e/multi_version.
"""

load("@bazel_skylib//lib:unittest.bzl", "asserts")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_coco//coco/private:version_resolution.bzl", "version_to_repo_suffix")  # buildifier: disable=bzl-visibility

def popili_evidence(target):
    """Text naming the repository of the popili a target resolved.

    Args:
        target: The target under test.

    Returns:
        The popili a run action executes, the headers of the runtime a library's `._gen` target
        forwards, or the text of a test's or binary's wrapper script.
    """
    for action in target.actions:
        if action.mnemonic in ("CocoGenerate", "CocoDiagram"):
            return action.argv[0]

    # After the actions: a coco_generate provides a CcInfo too, of its own generated headers.
    if CcInfo in target:
        return " ".join([header.path for header in target[CcInfo].compilation_context.headers.to_list()])
    executable = target[DefaultInfo].files_to_run.executable
    for action in target.actions:
        if executable in action.outputs.to_list():
            return action.content
    fail("%s runs no popili action and writes no wrapper script" % target.label)

def assert_popili_version(env, target, version):
    """Asserts that `target` resolved popili `version`.

    Args:
        env: The analysistest environment.
        target: The target under test.
        version: A registered version, not an alias.
    """
    repository = "__%s/" % version_to_repo_suffix(version)
    evidence = popili_evidence(target).replace("\\", "/")
    asserts.true(env, repository in evidence, "expected popili %s (...%s) in: %s" % (version, repository, evidence))
