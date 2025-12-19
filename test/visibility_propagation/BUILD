load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")

package(default_visibility = ["//visibility:private"])

coco_package(
    name = "simple",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

coco_generate(
    name = "simple_cpp",
    language = "cpp",
    package = ":simple",
    # Grant visibility to consumer package - this should propagate to .tst target too
    visibility = ["//test/visibility_propagation/consumer:__pkg__"],
)
