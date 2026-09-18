load("@rules_coco//coco:cc.bzl", "coco_cc_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")
load("@rules_shell//shell:sh_test.bzl", "sh_test")

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

# Directory-component mangling. popili derives a module's path from the source
# path relative to the sources root and passes *every* component of it through
# the file-name mangler, so under LowerUnderscore `src/Geometry/Dims.coco` is
# written to `src/geometry/dims.{h,cc}`.
#
# This needs a script rather than plain output declaration because macOS and
# Windows have case-insensitive filesystems, where a wrongly-cased declared
# output still resolves.
sh_test(
    name = "nested_dir_mangling_test",
    srcs = ["nested_dir_mangling_test.sh"],
    data = [":file_name_mangling_test_cpp"],
)
