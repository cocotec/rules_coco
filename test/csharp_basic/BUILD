load("@rules_cc//cc:defs.bzl", "cc_test")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")

coco_package(
    name = "csharp_basic_test",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

coco_generate(
    name = "csharp_basic_test_generated",
    language = "csharp",
    package = ":csharp_basic_test",
)

# Note: No coco_csharp_library - we only generate C# code, not compile it
# The generated C# files are available as outputs of csharp_basic_test_generated

cc_test(
    name = "csharp_validation_test",
    srcs = ["validator.cc"],
    args = ["$(location :csharp_basic_test_generated)"],
    data = [":csharp_basic_test_generated"],
)
