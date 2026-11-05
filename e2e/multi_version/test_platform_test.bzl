"""Analysis tests: the wrapper of a Coco test or binary names popili for the platform it runs on.

Bazel places a test on an execution platform matching its target platform. With a foreign target
platform and the host registered as the first execution platform, popili resolved anywhere but the
`test` exec group would be the host's, while the test runs on the foreign platform. A binary runs
on the host under `bazel run`; with a foreign platform registered as the first execution platform,
popili resolved without regard for that would be the foreign platform's. Analysis only: the
platform is foreign to every CI host, so nothing is executed.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")

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

def _host_popili_repo(version):
    """The repository of the host's popili for `version`, named as the toolchain hub names it."""
    settings = dict([constraint.split("//")[1].split(":") for constraint in HOST_CONSTRAINTS])
    return "io_cocotec_coco_%s_%s__%s" % (settings["os"], settings["cpu"], version.replace(".", "_"))

def _run_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.equals(env, _host_popili_repo(ctx.attr.popili_version), _popili_repo(analysistest.target_under_test(env)), "popili repository named by the wrapper")
    return analysistest.end(env)

test_platform_popili_test = analysistest.make(
    _impl,
    attrs = {"expected_repo": attr.string(mandatory = True)},
    config_settings = {
        "//command_line_option:extra_execution_platforms": [str(Label("@platforms//host")), str(Label("//:linux_aarch64"))],
        "//command_line_option:extra_toolchains": [str(Label("//:linux_aarch64_stub_cc_toolchain"))],
        "//command_line_option:platforms": str(Label("//:linux_aarch64")),
        # Under a local licence mode only the host's popili resolves, whatever the test's platform.
        str(Label("@rules_coco//:license_source")): "action_environment",
        str(Label("@rules_coco//:version")): "",
        str(Label("@rules_coco//:force_version")): False,
    },
)

run_platform_popili_test = analysistest.make(
    _run_impl,
    attrs = {"popili_version": attr.string(mandatory = True)},
    config_settings = {
        "//command_line_option:extra_execution_platforms": [str(Label("//:linux_aarch64")), str(Label("@platforms//host"))],
        "//command_line_option:platforms": str(Label("@platforms//host")),
        str(Label("@rules_coco//:version")): "",
        str(Label("@rules_coco//:force_version")): False,
    },
)
