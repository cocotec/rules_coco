# Macros that create companion targets (coco_generate's <name>.tst, the <name>._gen of
# the cc/c library macros, coco_fmt_test's <name>.format) must give them the main
# target's common attrs. Each target below fails analysis if its companion does not.
load("@rules_coco//coco:c.bzl", "coco_c_library")
load("@rules_coco//coco:cc.bzl", "coco_cc_library", "coco_cc_test_library")
load("@rules_coco//coco:defs.bzl", "coco_fmt_test", "coco_generate", "coco_package")

# Not a coco_package, so a generator that uses it fails analysis.
filegroup(
    name = "not_a_package",
    srcs = ["Coco.toml"],
)

# `//...` must skip both the generator and its .tst.
coco_generate(
    name = "manual_cpp",
    language = "cpp",
    package = ":not_a_package",
    tags = ["manual"],
)

# The companions below depend on testonly targets, so they must be testonly as well.
coco_package(
    name = "simple",
    testonly = True,
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

coco_package(
    name = "simple_c",
    testonly = True,
    srcs = glob(["c/src/**/*.coco"]),
    package = "c/Coco.toml",
)

coco_generate(
    name = "testonly_cpp",
    testonly = True,
    language = "cpp",
    mocks = True,
    package = ":simple",
)

coco_generate(
    name = "testonly_c",
    testonly = True,
    language = "c",
    package = ":simple_c",
)

coco_cc_library(
    name = "testonly_cc_lib",
    testonly = True,
    generated_package = ":testonly_cpp",
)

coco_cc_test_library(
    name = "testonly_cc_test_lib",
    testonly = True,
    generated_package = ":testonly_cpp",
)

# No coco_c_test_library: popili generates no C mocks, so it would have no srcs. It
# shares its implementation with coco_cc_test_library.
coco_c_library(
    name = "testonly_c_lib",
    testonly = True,
    generated_package = ":testonly_c",
)

coco_fmt_test(
    name = "testonly_fmt",
    testonly = True,
    package = ":simple",
)
