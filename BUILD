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

load("@bazel_skylib//rules:common_settings.bzl", "string_flag")
load("@io_cocotec_rules_coco//coco/private:licensing.bzl", "LICENSE_SOURCES")

string_flag(
    name = "license_source",
    build_setting_default = "local_user",
    values = LICENSE_SOURCES,
    visibility = ["//visibility:public"],
)

string_flag(
    name = "license_token",
    build_setting_default = "",
    visibility = ["//visibility:public"],
)

string_flag(
    name = "verification_backend",
    build_setting_default = "",
    values = [
        "",
        "local",
        "remote",
        "attempt-remote",
    ],
    visibility = ["//visibility:public"],
)
