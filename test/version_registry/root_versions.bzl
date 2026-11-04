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

"""The popili versions the root workspace registers for rules_coco's own tests.

Kept in step by hand with `coco_dev.toolchain` in MODULE.bazel and `coco_repositories` in
WORKSPACE, which cannot load this file. Consumers inherit none of it.
"""

load("@rules_coco//coco/private:toolchain_hub.bzl", "resolve_versions")  # buildifier: disable=bzl-visibility

# A registered version other than the default, for tests that need one. Unlike `testing`, which
# names the same release as `stable` between a release and the next beta, it never coincides with
# the default.
OLDER_VERSION = "1.5.7"

# As written in MODULE.bazel and WORKSPACE: the default first.
ROOT_POPILI_VERSIONS = ["stable", "testing", OLDER_VERSION]

# What the registry holds: the aliases resolved and duplicates dropped, in first-seen order.
ROOT_REGISTERED_VERSIONS, _ = resolve_versions(ROOT_POPILI_VERSIONS)
