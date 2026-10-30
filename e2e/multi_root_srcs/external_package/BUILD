load("@rules_coco//coco:cc.bzl", "coco_cc_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package", "coco_verify_test")

coco_package(
    name = "external_package",
    srcs = glob(["src_root/*.coco"]),
    package = "Coco.toml",
    visibility = ["//visibility:public"],
)

coco_verify_test(
    name = "external_package_verify",
    package = ":external_package",
)

coco_generate(
    name = "external_package_cpp",
    language = "cpp",
    package = ":external_package",
)

coco_cc_library(
    name = "external_package_cc",
    generated_package = ":external_package_cpp",
    visibility = ["//visibility:public"],
)
