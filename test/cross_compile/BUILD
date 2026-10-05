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
# Cross-compiling: the Coco toolchain constrains only the exec platform, and the scripts the rules
# Cross-compiling: the Coco toolchain constrains only the exec platform, and the scripts the rules
# emit must follow the popili binary rather than the target platform.

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_coco//coco:defs.bzl", "coco_fmt_test", "coco_package")
load("@rules_coco//coco:toolchain.bzl", "coco_toolchain")
load(":script_flavour_test.bzl", "script_flavour_tests")

[
    platform(
        name = os,
        constraint_values = [
            "@platforms//os:" + os,
            "@platforms//cpu:x86_64",
        ],
    )
    for os in [
        "linux",
        "windows",
    ]
]

# Fake Coco toolchains around empty binaries: only the file names matter to the tests, and without
# C/C++ runtimes nothing needs a C++ toolchain for the foreign target platform.
[
    (
        write_file(
            name = "fake_%s_popili" % kind,
            out = "fake_%s/popili%s" % (kind, ext),
        ),
        write_file(
            name = "fake_%s_licensing_server" % kind,
            out = "fake_%s/cocotec-licensing-server%s" % (kind, ext),
        ),
        coco_toolchain(
            name = "fake_%s_toolchain_impl" % kind,
            coco = ":fake_%s_popili" % kind,
            cocotec_licensing_server = ":fake_%s_licensing_server" % kind,
        ),
        toolchain(
            name = "fake_%s_toolchain" % kind,
            toolchain = ":fake_%s_toolchain_impl" % kind,
            toolchain_type = "@rules_coco//coco:toolchain_type",
        ),
    )
    for kind, ext in [
        ("posix", ""),
        ("windows", ".exe"),
    ]
]

coco_package(
    name = "base",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
    typecheck = True,
)

# Only analysed, never run. Test rules cannot be cross-compiled (Bazel runs a test on a platform
# matching its target), but the .format binary shares the wrapper code path with them.
coco_fmt_test(
    name = "base_fmt_test",
    package = ":base",
    tags = ["manual"],
)

script_flavour_tests(
    name = "script_flavour",
    package = ":base",
    wrapper = ":base_fmt_test.format",
)
