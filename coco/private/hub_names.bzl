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

"""Names of the toolchain hub and the repositories it points at.

Loads nothing, so //coco:BUILD can read them without loading the repository layer.
"""

DEFAULT_HUB_NAME = "coco_toolchains"

# Enables the toolchains of execution platforms other than the host's: only when the licence mode
# lets popili run remotely. The local modes run popili on this machine (`no-remote-exec`), which
# needs this machine's binary, whichever execution platform Bazel would otherwise pick first.
LICENSE_REMOTE_CAPABLE = "license_remote_capable"

# Matches when the licence mode that applies is `local_acquire`: the toolchains then point at the
# licence acquired for their popili's protocol version, which is only fetched, and so acquired, then.
LICENSE_LOCAL_ACQUIRE = "license_local_acquire"

def license_fetch_repo_name(protocol_version):
    """Returns the name of the repository acquiring the licence of a licence protocol version.

    Args:
      protocol_version: The licence protocol version, an int.

    Returns:
      The repository name.
    """
    return "io_cocotec_licensing_fetch_%d" % protocol_version
