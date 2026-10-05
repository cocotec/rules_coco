"""Analysis tests: a package's typecheck runs its version, wherever that version comes from.

A coco_package with `typecheck = True` typechecks itself, and every consumer waits for it. The
typecheck must run the package's version: its own pin, or the pin it inherits from its
workspace. Nothing is executed: the assertions are on the actions' inputs.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _popili_repos(action):
    return [f.owner.repo_name for f in action.inputs.to_list() if f.basename.startswith("popili")]

def _typecheck_impl(ctx):
    env = analysistest.begin(ctx)

    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == ctx.attr.mnemonic]
    asserts.equals(env, 1, len(actions), "expected exactly one %s action" % ctx.attr.mnemonic)
    if len(actions) != 1:
        return analysistest.end(env)

    repos = _popili_repos(actions[0])
    asserts.true(
        env,
        len(repos) == 1 and repos[0].endswith(ctx.attr.expected_repo_suffix),
        "expected popili from a repository ending in %s, got %s" % (ctx.attr.expected_repo_suffix, repos),
    )

    # A consumer waits for the package's typecheck: the marker is one of its inputs.
    if ctx.attr.expected_marker:
        asserts.true(
            env,
            ctx.attr.expected_marker in [f.basename for f in actions[0].inputs.to_list()],
            "%s does not wait for %s" % (ctx.attr.mnemonic, ctx.attr.expected_marker),
        )

    return analysistest.end(env)

_ATTRS = {
    "expected_marker": attr.string(doc = "Basename of a typecheck marker the action must take as input, if any."),
    "expected_repo_suffix": attr.string(
        mandatory = True,
        doc = "The mangled version the popili repository's name must end with, e.g. '__1_5_0'.",
    ),
    "mnemonic": attr.string(mandatory = True, doc = "The action to check, e.g. 'CocoTypecheck'."),
}

# As built, without flags.
typecheck_test = analysistest.make(_typecheck_impl, attrs = _ATTRS)

# With --@rules_coco//:version=1.5.1, which an unpinned package would use. A package pinned
# directly or through its workspace must keep its pin.
typecheck_flag_151_test = analysistest.make(
    _typecheck_impl,
    attrs = _ATTRS,
    config_settings = {str(Label("@rules_coco//:version")): "1.5.1"},
)
