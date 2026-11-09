# Copyright 2024 Cocotec Limited
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

"""Public API for Coco repository rules."""

load(
    "//coco/private:common_repositories.bzl",
    _AVAILABLE_STABLE_VERSIONS = "AVAILABLE_STABLE_VERSIONS",
    _coco_license_repository = "coco_fetch_license_repository",
)
load(
    "//coco/private:repositories.bzl",
    _coco_local_repositories = "coco_local_repositories",
    _coco_repositories = "coco_repositories",
)

coco_repositories = _coco_repositories
coco_local_repositories = _coco_local_repositories
coco_license_repository = _coco_license_repository

# Every stable popili version (1.5.0 onwards, no betas or release candidates) this
# rules_coco knows the downloads of, newest first: `versions = AVAILABLE_STABLE_VERSIONS`
# registers them all, with the newest as the default.
AVAILABLE_STABLE_VERSIONS = _AVAILABLE_STABLE_VERSIONS
