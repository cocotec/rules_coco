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

"""The licence modes. Loads nothing, so the toolchain hub's code can use it."""

LICENSE_SOURCES = [
    # Suitable credentials will be provided in the execution environment of each action. What is supported will depend
    # on the version of Coco, but could include COCOTEC_AUTH_TOKEN being injected into the environment via some
    # non-bazel mechanism.
    "action_environment",

    # An auth token file path will be provided that is available in the execution environment of each action.
    # The file path should be specified via --@rules_coco//:auth_token_path or in the toolchain configuration.
    # Popili will be invoked with --machine-auth-token pointing to this file.
    # Requires popili 1.5.2 or later.
    "action_file",

    # A license will be acquired on the local machine when Bazel fetches repositories, using COCOTEC_AUTH_TOKEN.
    #
    # This is not compatible with remote execution.
    "local_acquire",

    # The user's existing license on this machine will be reused.
    #
    # This is not compatible with remote execution.
    "local_user",

    # The explicitly provided token should be used as COCOTEC_AUTH_TOKEN. In this case,
    # --@rules_coco//:license_token must be set as well
    "token",
]

# The modes that read a licence on this machine, so popili must run here: off remote executors,
# and with this machine's own binary.
LOCAL_LICENSE_SOURCES = ["local_acquire", "local_user"]

# The mode that applies when neither --@rules_coco//:license_source nor the toolchain sets one.
DEFAULT_LICENSE_SOURCE = "local_user"
