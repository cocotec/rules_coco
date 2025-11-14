load("@rules_coco//coco:c.bzl", "coco_c_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")

coco_package(
    name = "c_file_prefixes_test",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

coco_generate(
    name = "c_file_prefixes_test_c",
    c_header_file_prefix = "api_",
    c_implementation_file_prefix = "impl_",
    language = "c",
    package = ":c_file_prefixes_test",
)

coco_c_library(
    name = "c_file_prefixes_test_lib",
    generated_package = ":c_file_prefixes_test_c",
)
