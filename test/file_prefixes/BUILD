load("@rules_coco//coco:cc.bzl", "coco_cc_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")

coco_package(
    name = "file_prefixes_test",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

coco_generate(
    name = "file_prefixes_test_cpp",
    language = "cpp",
    package = ":file_prefixes_test",
    cpp_header_file_prefix = "api_",
    cpp_implementation_file_prefix = "impl_",
)

coco_cc_library(
    name = "file_prefixes_test_cc",
    generated_package = ":file_prefixes_test_cpp",
)
