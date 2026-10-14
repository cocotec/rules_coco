# coco_generate(language = "c", mocks = True) must fail analysis with a clear message:
# popili does not generate C mocks, so the declared mock outputs would never be created.
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package")
load(":failure_test.bzl", "analysis_failure_test")

coco_package(
    name = "simple",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

# Manual, as it fails analysis; only analysed through the test below.
coco_generate(
    name = "simple_c",
    language = "c",
    mocks = True,
    package = ":simple",
    tags = ["manual"],
)

analysis_failure_test(
    name = "c_mocks_unsupported_test",
    expected_message = "mocks = True is not supported for language = \"c\"",
    target_under_test = ":simple_c",
)
