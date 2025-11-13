load("@rules_coco//coco:c.bzl", "coco_c_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")

coco_package(
    name = "c_basic_test",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

coco_generate(
    name = "c_basic_test_c",
    language = "c",
    package = ":c_basic_test",
)

coco_c_library(
    name = "c_basic_test_lib",
    generated_package = ":c_basic_test_c",
)
