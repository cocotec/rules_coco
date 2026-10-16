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

"""Source root scenarios for coco_generate.

Each scenario generates C++ for a fixture with real popili and compiles the result. That checks the rule
declares the files popili writes: a declared file popili does not write fails the action, and an
undeclared one that is included fails the compile.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@rules_coco//coco:cc.bzl", "coco_cc_library", "coco_cc_test_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package", "coco_verify_test")

def _flag_value(argv, flag):
    for i, arg in enumerate(argv):
        if arg == flag and i + 1 < len(argv):
            return argv[i + 1]
    return None

def _generate_flags_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "CocoGenerate"]
    asserts.equals(env, 1, len(actions), "expected exactly one CocoGenerate action")
    if len(actions) != 1:
        return analysistest.end(env)
    argv = actions[0].argv
    target = analysistest.target_under_test(env).label
    output = "/".join([ctx.bin_dir.path, target.package, "_coco", target.name, ctx.attr.include_prefix])
    asserts.equals(env, output, _flag_value(argv, "--output"), "--output")
    asserts.equals(env, output, _flag_value(argv, "--test-output"), "--test-output")
    asserts.equals(env, ctx.attr.include_prefix, _flag_value(argv, "--include-prefix"), "--include-prefix")
    return analysistest.end(env)

generate_flags_test = analysistest.make(
    _generate_flags_test_impl,
    attrs = {
        "include_prefix": attr.string(mandatory = True, doc = "Expected --include-prefix; --output and --test-output are below the generate's include root."),
    },
)

def _package_failure_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, ctx.attr.expected_message)
    return analysistest.end(env)

package_failure_test = analysistest.make(
    _package_failure_test_impl,
    expect_failure = True,
    attrs = {
        "expected_message": attr.string(mandatory = True),
    },
)

def source_root_scenario(name, srcs, test_srcs = [], mocks = False, **package_kwargs):
    """Declares the package, generator, build test and verify test for the fixture in directory `name`.

    Args:
        name: Scenario name; also the fixture directory.
        srcs: The package's .coco sources.
        test_srcs: The package's .coco test sources.
        mocks: Passed to coco_generate; must match generateMocks in Coco.toml.
        **package_kwargs: Forwarded to coco_package (source_roots, test_source_roots).
    """
    coco_package(
        name = name,
        srcs = srcs,
        package = name + "/Coco.toml",
        test_srcs = test_srcs,
        **package_kwargs
    )
    coco_verify_test(
        name = name + "_verify",
        package = ":" + name,
    )
    coco_generate(
        name = name + "_cpp",
        language = "cpp",
        mocks = mocks,
        package = ":" + name,
    )
    coco_cc_library(
        name = name + "_cc",
        generated_package = ":" + name + "_cpp",
    )
    build_targets = [":" + name + "_cc"]
    if mocks or test_srcs:
        coco_cc_test_library(
            name = name + "_cc_tst",
            generated_package = ":" + name + "_cpp",
            deps = [":" + name + "_cc"],
        )
        build_targets.append(":" + name + "_cc_tst")
    build_test(
        name = name + "_build_test",
        targets = build_targets,
    )
