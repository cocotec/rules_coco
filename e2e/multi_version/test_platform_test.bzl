"""Analysis test: the wrapper of a Coco test names popili for the platform the test runs on.

Bazel places a test on an execution platform matching its target platform. With a foreign target
platform and the host registered as the first execution platform, popili resolved anywhere but the
`test` exec group would be the host's, while the test runs on the foreign platform. Analysis only:
the platform is foreign to every CI host, so nothing is executed.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _popili_repo(target):
    executable = target[DefaultInfo].files_to_run.executable
    for action in target.actions:
        if executable in action.outputs.to_list():
            command = action.content.replace("\\", "/")
            return command.split("/bin/popili")[0].split("/")[-1].split("+")[-1]
    fail("no action writes %s" % executable.short_path)

def _impl(ctx):
    env = analysistest.begin(ctx)
    asserts.equals(env, ctx.attr.expected_repo, _popili_repo(analysistest.target_under_test(env)), "popili repository named by the wrapper")
    return analysistest.end(env)

test_platform_popili_test = analysistest.make(
    _impl,
    attrs = {"expected_repo": attr.string(mandatory = True)},
    config_settings = {
        "//command_line_option:extra_execution_platforms": [str(Label("@platforms//host")), str(Label("//:linux_aarch64"))],
        "//command_line_option:extra_toolchains": [str(Label("//:linux_aarch64_stub_cc_toolchain"))],
        "//command_line_option:platforms": str(Label("//:linux_aarch64")),
    },
)
