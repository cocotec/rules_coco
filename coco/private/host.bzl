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

"""Host checks for the toolchain hub's BUILD file, which loads this file.

It loads only `@platforms` and `platforms.bzl`, which loads nothing, so the hub stays loadable
before bazel_skylib has been fetched in WORKSPACE mode, and the hub's content stays independent of
the host: the check runs when the hub's BUILD file is loaded.
"""

load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load(":platforms.bzl", "toolchain_platform_of")

def unless_host(constraints, settings):
    """`settings`, unless `constraints` are the host's popili platform; then none.

    Args:
        constraints: A popili platform's constraint value labels, as strings.
        settings: The `target_settings` to add when that platform is not the host.

    Returns:
        A list of labels.
    """
    return [] if toolchain_platform_of(constraints) == toolchain_platform_of(HOST_CONSTRAINTS) else settings
