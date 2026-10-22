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

"""The licence protocol version of each popili version.

Popili stores the licence of protocol version `n` as `licenses_<n>.lic` in its data directory,
and a popili version only reads the file of its own protocol version. Each key below is the
earliest popili version that reads the protocol version it maps to; keys are in ascending
version order. See license_protocol_version() in version_resolution.bzl for the lookup.
"""

LICENSE_PROTOCOL_VERSIONS = {
    "1.5.0-beta.1": 6,
    "1.6.0-beta.1": 8,
    "1.6.0-beta.3": 9,
}
