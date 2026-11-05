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
load(":platforms.bzl", "COCO_TOOLCHAIN_PLATFORMS", "platform_constraints")

# Canonical labels, so constraints match however their repository is spelled.
_HOST = {str(Label(c)): True for c in HOST_CONSTRAINTS}

def matches_host(constraints):
    """Whether the host has every constraint value in `constraints`, a list of label strings."""
    return all([str(Label(c)) in _HOST for c in constraints])

def unless_host(constraints, settings):
    """`settings`, unless the host matches `constraints`; then none.

    Args:
        constraints: A popili platform's constraint value labels, as strings.
        settings: The `target_settings` to add when that platform is not the host.

    Returns:
        A list of labels.
    """
    return [] if matches_host(constraints) else settings

def host_popili_platform():
    """Which of COCO_TOOLCHAIN_PLATFORMS the host is.

    Returns:
        An (os, arch) pair, or None when popili is not published for the host.
    """
    for os, arch in COCO_TOOLCHAIN_PLATFORMS:
        if matches_host(platform_constraints(os, arch)):
            return (os, arch)
    return None
