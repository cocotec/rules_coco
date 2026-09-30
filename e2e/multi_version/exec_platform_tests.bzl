"""Analysis tests for running the package's popili on the consumer's execution platform.

A rule consuming a coco_package reaches it through an exec transition, so the package is
analysed with the rule's execution platform as its target platform, and the popili it hands the
rule is the one built for that platform. These tests register a second execution platform,
linux_aarch64, which is never the host on CI (ubuntu x86_64, macos arm64, windows x86_64), and
constrain a consumer to it, so the consumer runs somewhere other than where the package is
otherwise analysed, as with heterogeneous remote execution. Nothing is executed: the assertions
are on analysis results.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

# The host first, so that everything unconstrained stays on it and only a consumer constrained
# to the extra platform lands there. Canonical labels: skylib resolves these strings from its
# own repository, where neither @platforms nor @rules_coco is visible.
_HOST = str(Label("@platforms//host"))
_LINUX_AARCH64 = str(Label("//:linux_aarch64"))
_LINUX_RISCV64 = str(Label("//:linux_riscv64"))
_LICENSE_SOURCE_FLAG = str(Label("@rules_coco//:license_source"))

def _remote_settings(platform):
    # A licence mode that is valid off the host.
    return {
        "//command_line_option:extra_execution_platforms": [_HOST, platform],
        _LICENSE_SOURCE_FLAG: "action_environment",
    }

def _runs_with_impl(ctx):
    env = analysistest.begin(ctx)

    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "CocoDiagram"]
    asserts.equals(env, 1, len(actions), "expected exactly one CocoDiagram action")
    popili = [f.path for f in actions[0].inputs.to_list() if f.basename.startswith("popili")]
    asserts.true(
        env,
        len(popili) == 1 and ctx.attr.expected_repo in popili[0],
        "expected popili from %s, got %s" % (ctx.attr.expected_repo, popili),
    )

    return analysistest.end(env)

# A consumer constrained to linux_aarch64 gets its package's version built for linux_aarch64,
# and only that platform's repository is fetched on top of the host's.
exec_platform_runs_package_version_test = analysistest.make(
    _runs_with_impl,
    attrs = {
        "expected_repo": attr.string(
            doc = "The repository the popili action's binary must come from.",
            mandatory = True,
        ),
    },
    config_settings = _remote_settings(_LINUX_AARCH64),
)

def _failure_impl(ctx):
    env = analysistest.begin(ctx)
    for message in ctx.attr.expected_messages:
        asserts.expect_failure(env, message)
    return analysistest.end(env)

# A consumer constrained to a platform popili is not published for fails at analysis, naming
# the platforms it is published for, rather than on the worker with a binary for another OS.
exec_platform_unpublished_test = analysistest.make(
    _failure_impl,
    expect_failure = True,
    attrs = {
        "expected_messages": attr.string_list(
            doc = "Substrings the analysis failure message must contain.",
        ),
    },
    config_settings = _remote_settings(_LINUX_RISCV64),
)
