load("@rules_coco//coco:c.bzl", "coco_c_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")

coco_package(
    name = "c_file_name_mangling_test",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

coco_generate(
    name = "c_file_name_mangling_test_c",
    c_file_name_mangler = "LowerUnderscore",
    language = "c",
    package = ":c_file_name_mangling_test",
)

coco_c_library(
    name = "c_file_name_mangling_test_lib",
    generated_package = ":c_file_name_mangling_test_c",
)
