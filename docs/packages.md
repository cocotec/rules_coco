# Defining packages

For each `Coco.toml` file add the following to your `BUILD` file:

```starlark
load("@rules_coco//coco:defs.bzl", "coco_package")

coco_package(
    name = "my_package",
    srcs = glob(["*.coco"]),
    package = "Coco.toml",
)
```

If the `Coco.toml` file has dependencies then these need to be mirrored in the `BUILD` file:

```starlark
load("@rules_coco//coco:defs.bzl", "coco_package")

coco_package(
    name = "my_package",
    srcs = glob(["*.coco"]),
    package = "Coco.toml",
    deps = [
        "//my:other_pkg",
    ]
)
```

The `deps` mirror `[dependencies]` in `Coco.toml`:

```toml
[dependencies]
other_pkg = "*"
```

Each package gets its own `coco_generate` and `coco_cc_library`. A library lists the libraries of the packages its
package depends on in `deps`:

```starlark
coco_cc_library(
    name = "my_package_cc",
    generated_package = ":my_package_cpp",
    deps = ["//my:other_pkg_cc"],
)
```

To enable type checking as part of the build, add `typecheck = True`:

```starlark
coco_package(
    name = "my_package",
    srcs = glob(["*.coco"]),
    package = "Coco.toml",
    typecheck = True,  # Validates types before code generation
)
```

With `typecheck = True`, building the package runs `popili typecheck`, so `bazel build //path/to:my_package` fails on
type errors directly. Targets that read the package, such as `coco_generate`, run only after the typecheck has passed.
Without it, those targets still fail on type errors when they run popili.

## Workspaces

A popili workspace is a `Coco.toml` with a `[workspace]` section, whose settings, such as `[language]` and
`[generator]`, apply to the member packages it lists. Declare it with `coco_workspace` and point each member's
`coco_package` at it:

```starlark
load("@rules_coco//coco:defs.bzl", "coco_package", "coco_workspace")

coco_workspace(
    name = "workspace",
    workspace = "Coco.toml",  # [workspace] members = ["base", ...]
)

coco_package(
    name = "base",
    srcs = glob(["base/src/**/*.coco"]),
    package = "base/Coco.toml",
    workspace = ":workspace",
)
```

For mirroring, a generator setting a member inherits from the workspace counts as its own (see
[Output paths](code-generation.md#output-paths)). For example, to use the mocks from `generateMocks = "GMock"` in the
workspace's `Coco.toml`, set `cpp_mocks = "GMock"` on the member's `coco_package`.

A workspace nested inside another names the enclosing one with `parent`. A workspace can also restrict the popili
versions of its members; see [Workspaces](popili-versions.md#workspaces).
[`test/workspace_basic`](../test/workspace_basic) and [`test/workspace_nested`](../test/workspace_nested) are complete
examples.

## Where generated code goes

`coco_generate` writes all generated code, including test code and mocks, to a directory of its own:

```
bazel-bin/<package path>/_coco/<generate name>/<includePrefix>/<path below the source root>
```

`<package path>` is the directory of the `BUILD` file declaring the `coco_generate` (below `external/<repo>/` for
another repository) and `<generate name>` is its `name`. `coco_cc_library` and `coco_c_library` add
`bazel-bin/<package path>/_coco/<generate name>` as a quote include directory. A generated header is therefore included
by the rest of its path: the package's `includePrefix`, empty by default, then the path of its source below the source
root. popili's generated code includes its headers by that same path, so hand-written code does too, and the libraries
need no `includes` for generated headers.

With `coco_generate(name = "motor_cpp")` in `hw/motor/BUILD`, `sources = ["src"]` and `includePrefix = "motor"`,
`hw/motor/src/Foo.coco` becomes `bazel-bin/hw/motor/_coco/motor_cpp/motor/Foo.h`, included as
`#include "motor/Foo.h"`. Mirror `includePrefix` on the `coco_package` with `cpp_include_prefix` (or
`c_include_prefix`), like the other settings under [Output Paths](code-generation.md#output-paths).

`outputDirectory` and `testOutputDirectory` in `Coco.toml` are ignored. If one package is generated for several
languages, give each language different file extensions (see [Output Paths](code-generation.md#output-paths)) so that their files
do not clash.

To predict these paths, `coco_package` needs the source roots. When `source_roots` is unset, `coco_package` uses the
deepest directory that contains all `srcs`. Set `source_roots` (and `test_source_roots` for `test_srcs`) when that
directory isn't the one `Coco.toml` lists in `package.sources`. Three common cases: the package has several roots; all
sources sit in a subdirectory such as `src/sub/` while `Coco.toml` says `sources = ["src"]`; or the sources are outside
the directory of `Coco.toml`.

```starlark
coco_package(
    name = "my_package",
    srcs = glob([
        "src/**/*.coco",
        "interfaces/**/*.coco",
    ]),
    package = "Coco.toml",
    source_roots = [
        "src",
        "interfaces",
    ],  # Must match package.sources in Coco.toml
)
```

```toml
[package]
name = "my_package"
sources = ["src", "interfaces"]
```

[`e2e/multi_root_srcs`](../e2e/multi_root_srcs) also has roots outside the package directory, and test sources.
