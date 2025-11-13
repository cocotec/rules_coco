load("@rules_coco//coco:c.bzl", "coco_c_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")

coco_package(
    name = "c_file_extensions_test",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

coco_generate(
    name = "c_file_extensions_test_c",
    c_header_file_extension = ".h",
    c_implementation_file_extension = ".c",
    language = "c",
    package = ":c_file_extensions_test",
)

coco_c_library(
    name = "c_file_extensions_test_lib",
    generated_package = ":c_file_extensions_test_c",
)
