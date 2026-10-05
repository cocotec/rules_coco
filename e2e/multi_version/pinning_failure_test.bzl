"""Analysis test asserting that a target fails analysis with the expected message."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _pinning_failure_test_impl(ctx):
    env = analysistest.begin(ctx)
    for message in ctx.attr.expected_messages:
        asserts.expect_failure(env, message)
    return analysistest.end(env)

pinning_failure_test = analysistest.make(
    _pinning_failure_test_impl,
    expect_failure = True,
    attrs = {
        "expected_messages": attr.string_list(
            doc = "Substrings the analysis failure message must contain.",
        ),
    },
)
