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

"""The licence files of the local licence modes, by path rather than as build inputs."""

LicensePathsInfo = provider(
    doc = "Licence files on this machine: the user's (`local_user`) or acquired ones (`local_acquire`).",
    fields = {
        "error": "Why a licence is missing, or \"\".",
        "error_path": "The absolute path of a file holding `error`, or \"\": tests print it as they run, which keeps it out of their key.",
        "paths": "A dict from file name (`licenses_<n>.lic`) to its absolute path.",
    },
)

def _license_paths_impl(ctx):
    return [LicensePathsInfo(paths = ctx.attr.paths, error = ctx.attr.error, error_path = ctx.attr.error_path)]

license_paths = rule(
    doc = """Names licence files without making them inputs.

popili reads the licence at its path, so the file's contents stay out of the action key: popili's
licensing daemon rewrites the user's licence as it renews, and every acquisition writes a new
licence, either of which would otherwise rerun every popili action. That is only sound because the
local licence modes keep popili off remote executors.""",
    implementation = _license_paths_impl,
    attrs = {
        "error": attr.string(doc = "Why a licence is missing, shown when popili runs without it."),
        "error_path": attr.string(doc = "Absolute path of a file holding `error`, empty when there is none."),
        "paths": attr.string_dict(doc = "File name to absolute path."),
    },
    provides = [LicensePathsInfo],
)
