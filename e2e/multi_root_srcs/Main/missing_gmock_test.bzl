"""Analysis test: a coco_cc_test_library compiling generated mocks fails without a GoogleMock.

This module names no GoogleMock (no coco.cc_test_runtime tag, no cc_test_runtime_gmock), so its
test library, over test source roots alone, links the plain runtime. A package generating mocks
needs GoogleMock, and the library compiling them fails saying how to name one. Nothing is
executed, so the package's cpp_mocks need not match its Coco.toml.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _missing_gmock_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "compiles the mocks of ")
    asserts.expect_failure(env, ", which need GoogleMock, but the Coco toolchain ")
    asserts.expect_failure(env, "coco.cc_test_runtime(gmock = \"@googletest//:gtest\")")
    return analysistest.end(env)

missing_gmock_test = analysistest.make(_missing_gmock_test_impl, expect_failure = True)
