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

"""Picks the output root that coco_generate passes to popili.

Bazel-side stand-in for `sources = [...]` in Coco.toml. See TODO-output-directory.md for known gaps.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")

def output_directory(package_dir, srcs):
    """Returns the output root, relative to package_dir, for the given source files.

    Args:
        package_dir: Directory containing Coco.toml.
        srcs: Depset of source Files (only `.path` is read).

    Returns:
        The dirname of the shortest source path relative to package_dir, or None if srcs is empty.
    """
    root_output_dir = None
    for src in srcs.to_list():
        relative_to_package = paths.relativize(src.path, package_dir)
        if not root_output_dir or len(relative_to_package) < len(root_output_dir):
            root_output_dir = paths.dirname(relative_to_package)
    return root_output_dir
