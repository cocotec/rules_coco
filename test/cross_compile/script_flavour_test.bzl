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
"""Analysis tests: generated scripts follow the popili binary's platform, not the target platform.

Each test builds for a foreign target platform with a fake Coco toolchain wrapping either `popili`
or `popili.exe`, and asserts the wrapper or typecheck script has the extension the binary demands,
and that build actions set `HOME` for a POSIX popili only.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _wrapper_test_impl(ctx):
    env = analysistest.begin(ctx)
    executable = analysistest.target_under_test(env)[DefaultInfo].files_to_run.executable
    asserts.equals(env, ctx.attr.expected_ext, executable.extension, "wrapper script flavour")
    return analysistest.end(env)

def _typecheck_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    scripts = [a.argv[0] for a in actions if a.mnemonic == "CocoTypecheck"]
    asserts.equals(env, 1, len(scripts), "CocoTypecheck actions")
    for script in scripts:
        asserts.true(env, script.endswith("." + ctx.attr.expected_ext), "typecheck script %s is not a .%s" % (script, ctx.attr.expected_ext))
        content = [a.content for a in actions if a.mnemonic == "FileWrite" and a.outputs.to_list()[0].path == script][0]
        asserts.equals(env, ctx.attr.expected_ext == "sh", "export HOME='/nonexistent'" in content, "typecheck script sets HOME:\n" + content)
    return analysistest.end(env)

def _generate_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "CocoGenerate"]
    asserts.equals(env, 1, len(actions), "CocoGenerate actions")
    expected = "/nonexistent" if ctx.attr.expected_ext == "sh" else None
    asserts.equals(env, expected, actions[0].env.get("HOME"), "CocoGenerate HOME")
    return analysistest.end(env)

def _settings(target_os, toolchain):
    return {
        "//command_line_option:extra_toolchains": [str(Label("//test/cross_compile:fake_%s_toolchain" % toolchain))],
        "//command_line_option:platforms": str(Label("//test/cross_compile:" + target_os)),
    }

_ATTRS = {"expected_ext": attr.string(mandatory = True)}

# rule() must be called at top level and bound to a global, hence one pair per combination. Each
# combination mismatches the target OS and the binary's OS, which is what the real hosts never do.
posix_on_windows_wrapper_test = analysistest.make(_wrapper_test_impl, attrs = _ATTRS, config_settings = _settings("windows", "posix"))
posix_on_windows_typecheck_test = analysistest.make(_typecheck_test_impl, attrs = _ATTRS, config_settings = _settings("windows", "posix"))
posix_on_windows_generate_test = analysistest.make(_generate_test_impl, attrs = _ATTRS, config_settings = _settings("windows", "posix"))
windows_on_linux_wrapper_test = analysistest.make(_wrapper_test_impl, attrs = _ATTRS, config_settings = _settings("linux", "windows"))
windows_on_linux_typecheck_test = analysistest.make(_typecheck_test_impl, attrs = _ATTRS, config_settings = _settings("linux", "windows"))
windows_on_linux_generate_test = analysistest.make(_generate_test_impl, attrs = _ATTRS, config_settings = _settings("linux", "windows"))

def script_flavour_tests(name, package, generate, wrapper):
    """Declares the typecheck, generate and wrapper tests for both mismatching combinations, plus a test_suite.

    Args:
        name: Prefix for the tests and the name of the test_suite.
        package: A coco_package with `typecheck = True`.
        generate: A coco_generate of `package`.
        wrapper: A non-test executable built with `create_coco_wrapper_script`.
    """
    combos = {
        "posix_on_windows": ("sh", posix_on_windows_typecheck_test, posix_on_windows_generate_test, posix_on_windows_wrapper_test),
        "windows_on_linux": ("bat", windows_on_linux_typecheck_test, windows_on_linux_generate_test, windows_on_linux_wrapper_test),
    }
    for combo, (ext, typecheck_test, generate_test, wrapper_test) in combos.items():
        typecheck_test(name = "%s_%s_typecheck" % (name, combo), size = "small", target_under_test = package, expected_ext = ext)
        generate_test(name = "%s_%s_generate" % (name, combo), size = "small", target_under_test = generate, expected_ext = ext)
        wrapper_test(name = "%s_%s_wrapper" % (name, combo), size = "small", target_under_test = wrapper, expected_ext = ext)
    native.test_suite(name = name, tests = ["%s_%s_%s" % (name, combo, kind) for combo in combos for kind in ["typecheck", "generate", "wrapper"]])
