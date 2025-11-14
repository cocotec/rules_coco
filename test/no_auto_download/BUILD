# Test to verify that popili's auto-downloader is disabled when running via Bazel.
# This test uses a version mismatch: selectedVersion = "1.2.0" but standard = "2024"
# which requires version 1.5+. If auto-download is disabled (as it should be),
# this will fail with a version error. If auto-download is enabled (bug), it might
# succeed by downloading the newer version.

load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")

coco_package(
    name = "no_auto_download_test",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
    typecheck = True,
)

coco_generate(
    name = "no_auto_download_test_cpp",
    language = "cpp",
    package = ":no_auto_download_test",
)
