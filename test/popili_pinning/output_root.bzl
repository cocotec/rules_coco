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

"""Reads which configuration a target was analysed in, for analysis tests.

Targets in the same configuration share a bin dir, so comparing the bin dirs of two targets' outputs
tells whether a transition changed the configuration. Shared with e2e/multi_version.
"""

def output_root(target):
    """The bin dir of a target's generated outputs, which names its configuration.

    Args:
        target: The target under test.

    Returns:
        The root path of the first generated file among the target's default outputs.
    """
    for file in target[DefaultInfo].files.to_list():
        if not file.is_source:
            return file.root.path
    fail("%s has no generated file to read its bin dir off" % target.label)
