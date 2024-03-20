# Copyright 2019 Cocotec Limited
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

def _coco_toolchain_impl(ctx):
    toolchain = platform_common.ToolchainInfo(
        coco = ctx.file.coco,
        cocotec_licensing_server = ctx.file.cocotec_licensing_server,
        preferences_file = ctx.file.preferences_file,
    )
    return toolchain

coco_toolchain = rule(
    _coco_toolchain_impl,
    attrs = {
        "coco": attr.label(
            doc = "The location of the `coco` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            mandatory = True,
        ),
        "cocotec_licensing_server": attr.label(
            doc = "The location of the `cocotec-licensing-server` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            mandatory = True,
        ),
        "preferences_file": attr.label(
            doc = "The location of the Coco Platform `preferences.toml` file. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            default = "@io_cocotec_coco_preferences//:preferences",
        ),
    },
)
