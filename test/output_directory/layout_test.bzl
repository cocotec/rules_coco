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

"""Output layout scenarios for coco_generate. See TODO-output-directory.md.

Each scenario has a layout (layouts.bzl): the files popili writes, relative to --output ("out") and
--test-output ("test"), and the generated headers each file includes, relative to --include-prefix.
Two tests check it from either side:

- <name>_popili_test runs popili on the fixture and compares its output with the layout. It checks our
  assumptions about popili, so it should pass.
- <name>_test is an analysis test (no popili): the rule must declare exactly the files popili will write,
  given the --output/--test-output it passes, and every include must resolve to a declared header via
  --include-prefix.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")
load("@rules_shell//shell:sh_test.bzl", "sh_test")

def _flag_value(argv, flag):
    for i, arg in enumerate(argv):
        if arg == flag and i + 1 < len(argv):
            return argv[i + 1]
    return None

def _strip_slash(path):
    return path.rstrip("/") if path else path

def _parse_layout(lines):
    """Returns ({"out"|"test": [relative paths]}, [(dir, relative file, included path)])."""
    files = {"out": [], "test": []}
    includes = []
    for line in lines:
        parts = line.split(" ")
        if parts[0] == "include":
            file = parts[1]
            includes.append((file.split("/")[0], file.partition("/")[2], parts[2]))
        else:
            files[parts[0]].append(parts[1])
    return files, includes

def _generate_layout_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "CocoGenerate"]
    asserts.equals(env, 1, len(actions), "expected exactly one CocoGenerate action")
    if len(actions) != 1:
        return analysistest.end(env)
    argv = actions[0].argv
    declared = sorted([f.path for f in actions[0].outputs.to_list()])

    roots = {
        "out": _strip_slash(_flag_value(argv, "--output")),
        "test": _strip_slash(_flag_value(argv, "--test-output")),
    }
    include_prefix = _strip_slash(_flag_value(argv, "--include-prefix"))
    genfiles_pkg = paths.join(ctx.bin_dir.path, ctx.attr.package_dir)

    if ctx.attr.check_output:
        asserts.equals(env, _strip_slash(paths.join(genfiles_pkg, ctx.attr.expected_output)), roots["out"], "--output")
        asserts.equals(env, _strip_slash(paths.join(ctx.attr.package_dir, ctx.attr.expected_output)), include_prefix, "--include-prefix")
    if ctx.attr.check_test_output:
        asserts.equals(env, _strip_slash(paths.join(genfiles_pkg, ctx.attr.expected_test_output)), roots["test"], "--test-output")

    files, includes = _parse_layout(ctx.attr.layout)

    # Where popili will write, given the flags the rule passes.
    expected = []
    for kind, relative_paths in files.items():
        for p in relative_paths:
            if not roots[kind]:
                asserts.true(env, False, "popili writes %s/%s, but the rule passes no --%s" % (kind, p, "output" if kind == "out" else "test-output"))
                continue
            expected.append(paths.join(roots[kind], p))
    asserts.equals(env, sorted(expected), declared, "declared outputs vs. where popili writes")

    # #include "<include-prefix>/<path>" must name a declared header.
    for kind, file, included in includes:
        target = paths.join(ctx.bin_dir.path, include_prefix or "", included)
        asserts.true(
            env,
            target in declared,
            "%s/%s includes \"%s\", which is not a declared output" % (kind, file, paths.join(include_prefix or "", included)),
        )

    return analysistest.end(env)

generate_layout_test = analysistest.make(
    _generate_layout_test_impl,
    attrs = {
        "check_output": attr.bool(),
        "check_test_output": attr.bool(),
        "expected_output": attr.string(doc = "Expected --output root, relative to the Coco.toml directory."),
        "expected_test_output": attr.string(doc = "Expected --test-output root, relative to the Coco.toml directory."),
        "layout": attr.string_list(mandatory = True),
        "package_dir": attr.string(mandatory = True, doc = "Directory containing Coco.toml."),
    },
)

def output_layout_scenario(name, layout, srcs, test_srcs = [], mocks = False, expected_output = None, expected_test_output = None):
    """Declares the package, generator, analysis test and popili probe for the fixture in ./<name>.

    Args:
        name: Fixture directory, containing Coco.toml.
        layout: Lines from layouts.bzl.
        srcs: The package's .coco sources.
        test_srcs: The package's .coco test sources.
        mocks: Passed to coco_generate; must match generateMocks in Coco.toml.
        expected_output: See generate_layout_test.
        expected_test_output: See generate_layout_test.
    """
    package_dir = paths.join(native.package_name(), name)
    coco_package(
        name = name,
        srcs = srcs,
        package = name + "/Coco.toml",
        test_srcs = test_srcs,
    )
    coco_generate(
        name = name + "_cpp",
        language = "cpp",
        mocks = mocks,
        package = ":" + name,
    )
    generate_layout_test(
        name = name + "_test",
        check_output = expected_output != None,
        check_test_output = expected_test_output != None,
        expected_output = expected_output or "",
        expected_test_output = expected_test_output or "",
        layout = layout,
        package_dir = package_dir,
        target_under_test = ":" + name + "_cpp",
    )
    write_file(
        name = name + "_layout",
        out = name + "_layout.txt",
        content = layout + [""],
    )
    sh_test(
        name = name + "_popili_test",
        srcs = ["popili_layout_test.sh"],
        args = [
            package_dir,
            "$(rootpath :%s_layout)" % name,
            "$(POPILI) $(POPILI_STARTUP_ARGS)",
        ],
        data = [
            ":" + name,
            ":" + name + "_layout",
            "@rules_coco//coco:current_popili_version",
        ],
        # Runs popili (needs a licence). Skip with --test_tag_filters=-popili.
        tags = ["popili"],
        toolchains = ["@rules_coco//coco:current_popili_version"],
    )
