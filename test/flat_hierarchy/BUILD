load("@rules_coco//coco:cc.bzl", "coco_cc_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")

coco_package(
    name = "flat_hierarchy_test",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

coco_generate(
    name = "flat_hierarchy_test_cpp",
    cpp_flat_file_hierarchy = True,
    language = "cpp",
    package = ":flat_hierarchy_test",
)

coco_cc_library(
    name = "flat_hierarchy_test_cc",
    generated_package = ":flat_hierarchy_test_cpp",
)
