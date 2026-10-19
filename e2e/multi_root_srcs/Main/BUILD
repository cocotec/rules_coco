# Main's Coco.toml has sources = ["src_root", "../external_sources"] and testSources = ["test_root",
# "../external_test_sources"]: one source root and one test source root are outside the directory
# containing Coco.toml.

load("@rules_coco//coco:cc.bzl", "coco_cc_library", "coco_cc_test_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package", "coco_verify_test")

coco_package(
    name = "main_package",
    srcs = glob(["src_root/*.coco"]) + ["//external_sources"],
    package = "Coco.toml",
    source_roots = [
        "src_root",
        "../external_sources",
    ],
    test_source_roots = [
        "test_root",
        "../external_test_sources",
    ],
    test_srcs = glob(["test_root/*.coco"]) + ["//external_test_sources"],
    deps = ["//external_package"],
)

coco_verify_test(
    name = "main_package_verify",
    package = ":main_package",
)

# MyPort, and the test code for both test roots, is generated beside Coco.toml, next to MainComponent.
coco_generate(
    name = "main_package_cpp",
    language = "cpp",
    package = ":main_package",
)

coco_cc_library(
    name = "main_package_cc",
    generated_package = ":main_package_cpp",
    deps = ["//external_package:external_package_cc"],
)

coco_cc_test_library(
    name = "main_package_cc_tst",
    generated_package = ":main_package_cpp",
    deps = [":main_package_cc"],
)
