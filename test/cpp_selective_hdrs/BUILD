# Copyright 2025 Cocotec Limited
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

load("@rules_cc//cc:defs.bzl", "cc_test")
load("@rules_coco//coco:cc.bzl", "coco_cc_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")

coco_package(
    name = "selective",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

coco_generate(
    name = "selective_cpp",
    language = "cpp",
    package = ":selective",
)

# Only IPublicApi.h is public; InternalComp.h stays private (in srcs).
# The library still compiles because InternalComp.h is in srcs alongside
# InternalComp.cc, so the compiler can find it during compilation.
coco_cc_library(
    name = "selective_lib",
    generated_package = ":selective_cpp",
    public_hdrs = ["IPublicApi.h"],
)

# Downstream test can include IPublicApi.h (public) but not InternalComp.h (private).
cc_test(
    name = "unit",
    srcs = ["test/selective_test.cc"],
    deps = [
        ":selective_lib",
        "@googletest//:gtest_main",
    ],
)
