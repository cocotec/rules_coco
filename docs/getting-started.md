# Getting started

This page takes you from an empty Bazel module to a verified Coco package with generated C++ code. It uses bzlmod;
see [Setup](setup.md) for `WORKSPACE`.

## 1. Add rules_coco to `MODULE.bazel`

Take `VERSION` and `HASH` from the [latest release](https://github.com/cocotec/rules_coco/releases/latest):

```starlark
bazel_dep(name = "rules_cc", version = "0.2.18")  # for cc_binary below
bazel_dep(name = "rules_coco")
archive_override(
    module_name = "rules_coco",
    urls = [
        "https://github.com/cocotec/rules_coco/releases/download/VERSION/rules_coco_VERSION.tar.gz",
        "https://dl.cocotec.io/rules_coco/rules_coco_VERSION.tar.gz",
    ],
    integrity = "sha256-HASH",
)

coco = use_extension("@rules_coco//coco:extensions.bzl", "coco")
coco.toolchain(
    versions = ["stable"],
    cc = True,  # C++ runtime, for coco_cc_library
)
```

Still on `WORKSPACE`? See [Setup](setup.md#workspace-deprecated).

## 2. Make a license available

By default the rules reuse the Coco license already activated on your machine, so a local build needs no
configuration. CI and remote execution need a machine token: see [Licensing](licensing.md).

## 3. Declare a package, verify it and generate C++

This step assumes a Coco package: a `Coco.toml` with its `.coco` sources in `src/`. [`e2e/smoke`](../e2e/smoke) has a
minimal one to start from.

Next to your `Coco.toml`, add a `BUILD.bazel` file:

```starlark
load("@rules_cc//cc:defs.bzl", "cc_binary")
load("@rules_coco//coco:cc.bzl", "coco_cc_library")
load("@rules_coco//coco:defs.bzl", "coco_generate", "coco_package", "coco_verify_test")

coco_package(
    name = "example",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
)

coco_verify_test(
    name = "example_verify",
    package = ":example",
)

coco_generate(
    name = "example_cpp",
    language = "cpp",
    package = ":example",
)

coco_cc_library(
    name = "example_cc",
    generated_package = ":example_cpp",
)

cc_binary(
    name = "main",
    srcs = ["main.cc"],  # #include "Example.h" for src/Example.coco
    deps = [":example_cc"],
)
```

> [!IMPORTANT]
> This example assumes your `Coco.toml` keeps popili's default generator settings. Each `[generator.cpp]`,
> `[generator.c]` or `[generator.csharp]` setting that changes output paths, such as `headerFileExtension`, has to be
> repeated on `coco_package`, or the build fails with `output '...' was not created`. See
> [Output paths](code-generation.md#output-paths).

## 4. Build and test

```bash
bazel test //path/to/package:all       # runs the verification
bazel run //path/to/package:main       # builds the generated code and your binary
```

[`e2e/smoke`](../e2e/smoke) is a tested module built the same way, with C++ mocks and a GoogleTest test added.
