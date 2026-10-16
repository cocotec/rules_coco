"""Analysis test: the hub's registry reports what the root workspace registered.

The root registers `stable` and no local distribution, in both MODULE.bazel and WORKSPACE, so
the registry must list exactly the version `stable` resolves to.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_coco//coco/private:version_registry.bzl", "CocoVersionRegistryInfo")  # buildifier: disable=bzl-visibility
load("@rules_coco//coco/private:version_resolution.bzl", "resolve_version_alias")  # buildifier: disable=bzl-visibility

def _impl(ctx):
    env = analysistest.begin(ctx)
    registry = analysistest.target_under_test(env)[CocoVersionRegistryInfo]
    asserts.equals(env, [resolve_version_alias("stable")], registry.versions, "registered versions")
    asserts.false(env, registry.has_local, "no local toolchain is registered")
    asserts.equals(env, 2, len(registry.host), "host is an (os, cpu) pair")
    return analysistest.end(env)

registry_test = analysistest.make(_impl)
