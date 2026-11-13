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

"""Attribute docs shared by the coco tag class and coco_toolchain."""

# Completes "... licence mode for ...: ".
LICENSE_SOURCE_DOC = (
    "`\"local_user\"`, `\"local_acquire\"`, `\"token\"`, `\"action_environment\"` or `\"action_file\"`; see " +
    "[Licensing](../licensing.md#licence-modes). Empty means `\"local_user\"`. The " +
    "`--@rules_coco//:license_source` flag overrides it."
)

LICENSE_TOKEN_DOC = "The licence token for `\"token\"` mode."

AUTH_TOKEN_PATH_DOC = "Path to the auth token file for `\"action_file\"` mode. The file must exist wherever actions run."
