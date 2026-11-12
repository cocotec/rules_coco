# Copyright 2023 Cocotec Limited
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

load("@rules_python//python:defs.bzl", "py_binary", "py_library", "py_test")

py_binary(
    name = "update_digests",
    srcs = ["update_digests.py"],
    tags = ["manual"],
)

py_binary(
    name = "release",
    srcs = ["release.py"],
    tags = ["manual"],
)

py_library(
    name = "release_policy_lib",
    srcs = [
        "release.py",
        "release_policy.py",
    ],
    imports = ["."],
)

py_test(
    name = "release_policy_test",
    srcs = ["release_policy_test.py"],
    deps = [":release_policy_lib"],
)
