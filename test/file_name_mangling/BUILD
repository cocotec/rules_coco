load("@rules_coco//coco:cc.bzl", "coco_cc_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")

coco_package(
    name = "file_name_mangling_test",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

coco_generate(
    name = "file_name_mangling_test_cpp",
    cpp_file_name_mangler = "LowerUnderscore",
    language = "cpp",
    package = ":file_name_mangling_test",
)

coco_cc_library(
    name = "file_name_mangling_test_cc",
    generated_package = ":file_name_mangling_test_cpp",
)
