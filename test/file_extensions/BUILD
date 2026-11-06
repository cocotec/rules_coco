load("@rules_coco//coco:cc.bzl", "coco_cc_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")

coco_package(
    name = "file_extensions_test",
    srcs = glob(["src/**/*.coco"]),
    cpp_header_file_extension = ".hpp",
    cpp_implementation_file_extension = ".cpp",
    package = "Coco.toml",
)

coco_generate(
    name = "file_extensions_test_cpp",
    language = "cpp",
    package = ":file_extensions_test",
)

coco_cc_library(
    name = "file_extensions_test_cc",
    generated_package = ":file_extensions_test_cpp",
)
