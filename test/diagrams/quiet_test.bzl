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

"""Analysis test: a counterexample diagram runs popili quietly, keeping what it prints in a log."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _quiet_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    diagrams = [a for a in actions if a.mnemonic == "CocoDiagram"]
    asserts.equals(env, 1, len(diagrams), "CocoDiagram actions")
    for action in diagrams:
        logs = [f for f in action.outputs.to_list() if f.basename.endswith(".popili.log")]
        asserts.equals(env, 1, len(logs), "logs of what popili printed among the action's outputs")

        # On Windows, popili's arguments are in a response file; elsewhere, on the action's command line.
        responses = [a for a in actions if a.mnemonic == "FileWrite" and a.outputs.to_list()[0].extension == "params"]
        arguments = responses[0].content if responses else " ".join(action.argv)
        asserts.true(env, "--quiet" in arguments, "popili runs without --quiet: %s" % arguments)
    return analysistest.end(env)

quiet_test = analysistest.make(_quiet_test_impl)
