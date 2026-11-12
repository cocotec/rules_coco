# Generating code

Code is generated from a [`coco_package`](packages.md) with `coco_generate`, and compiled with the C or C++
library rules. See [where generated code goes](packages.md#where-generated-code-goes) for the output layout and
how to include generated headers.

## C++ Code Generation

To generate C++ code:

```starlark
load("@rules_coco//coco:defs.bzl", "coco_generate")

coco_generate(
    name = "my_package_cc_src",
    language = "cpp",
    package = ":my_package",
)
```

This is compiled using `coco_cc_library`, which adds the C++ runtime as a dependency:

```starlark
load("@rules_coco//coco:cc.bzl", "coco_cc_library")

coco_cc_library(
    name = "my_package_cc",
    generated_package = ":my_package_cc_src",
)
```

If your project wraps `cc_library` in a macro of its own, for example to add default `copts`, pass it as
`library_rule` and `coco_cc_library` calls it instead of rules_cc's `cc_library`, with the same attributes:

```starlark
load("@rules_coco//coco:cc.bzl", "coco_cc_library")
load("//tools:defs.bzl", "my_cc_library")

coco_cc_library(
    name = "my_package_cc",
    generated_package = ":my_package_cc_src",
    library_rule = my_cc_library,
)
```

> [!IMPORTANT]
> Your Coco.toml file must set `generator.cpp.runtimeHeaderFileExtension` to `.h` if you use a custom value for
> `generator.cpp.headerFileExtension`.

## C Code Generation

To generate C code:

```starlark
load("@rules_coco//coco:defs.bzl", "coco_generate")

coco_generate(
    name = "my_package_c_src",
    language = "c",
    package = ":my_package",
)
```

This can be compiled using `coco_c_library`:

```starlark
load("@rules_coco//coco:c.bzl", "coco_c_library")

coco_c_library(
    name = "my_package_c",
    generated_package = ":my_package_c_src",
)
```

> [!IMPORTANT]
> Your Coco.toml file must set `generator.c.runtimeHeaderFileExtension` to `.h` if you use a custom value for
> `generator.c.headerFileExtension`.

## Output Paths

Bazel has to be able to precompute the output paths of all rules. Since there are many settings in `Coco.toml` that
can affect output paths, these settings must be repeated on the `coco_package` in the `BUILD` file. If you forget to do this, you will get
errors when running `coco_generate` such as:

```
ERROR: example/BUILD:10:14: output 'example/Example.h' was not created
ERROR: example/BUILD:10:14: Generating cpp example_test failed: not all outputs were created or valid
```

If you see these errors then you need to make sure that the `BUILD` files contain mirrors of the settings in the
`Coco.toml` file. For example, suppose you have the following `Coco.toml` file.

```toml
[generator.cpp]
headerFileExtension = ".hpp"
implementationFileExtension = ".cpp"
fileNameMangler = "LowerUnderscore"
includePrefix = "motor"
```

Then this would require the following in your `BUILD` file:

```starlark
coco_package(
    name = "my_package",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
    cpp_header_file_extension = ".hpp",        # Must match Coco.toml
    cpp_implementation_file_extension = ".cpp", # Must match Coco.toml
    cpp_file_name_mangler = "LowerUnderscore", # Must match Coco.toml
    cpp_include_prefix = "motor",              # Must match Coco.toml
)
```

| Coco.toml Setting                           | `coco_package` Attribute            |
| ------------------------------------------- | ----------------------------------- |
| `generator.c.headerFileExtension`           | `c_header_file_extension`           |
| `generator.c.implementationFileExtension`   | `c_implementation_file_extension`   |
| `generator.c.headerFilePrefix`              | `c_header_file_prefix`              |
| `generator.c.implementationFilePrefix`      | `c_implementation_file_prefix`      |
| `generator.c.fileNameMangler`               | `c_file_name_mangler`               |
| `generator.c.flatFileHierarchy`             | `c_flat_file_hierarchy`             |
| `generator.c.includePrefix`                 | `c_include_prefix`                  |
| `generator.c.regeneratePackages`            | `c_regenerate_packages`             |
| `generator.cpp.headerFileExtension`         | `cpp_header_file_extension`         |
| `generator.cpp.implementationFileExtension` | `cpp_implementation_file_extension` |
| `generator.cpp.headerFilePrefix`            | `cpp_header_file_prefix`            |
| `generator.cpp.implementationFilePrefix`    | `cpp_implementation_file_prefix`    |
| `generator.cpp.fileNameMangler`             | `cpp_file_name_mangler`             |
| `generator.cpp.flatFileHierarchy`           | `cpp_flat_file_hierarchy`           |
| `generator.cpp.includePrefix`               | `cpp_include_prefix`                |
| `generator.cpp.regeneratePackages`          | `cpp_regenerate_packages`           |
| `generator.cpp.generateMocks`               | `cpp_mocks`                         |
| `generator.csharp.regeneratePackages`       | `csharp_regenerate_packages`        |
| `generator.csharp.generateMocks`            | `csharp_mocks`                      |

Mirror the package's _effective_ value: the one in its own `Coco.toml`, or else the one it inherits from its
workspace's `Coco.toml` or receives from a dependency with `exportConfig = true` (see the popili documentation
on `includePrefix`). A wrong `cpp_include_prefix` or `c_include_prefix` fails when compiling the package's own generated code, as popili
wrote its includes with the `Coco.toml` value:

```
fatal error: 'motor/Foo.h' file not found
```

The path in the message names the value to set. Keep the two equal even for a package nothing depends on yet: a
small package may compile despite a mismatch, as its sources find headers in their own directory, and the packages
that later depend on it fail instead.

Two unrelated packages may both have `src/Types.coco`. Hand-written code including `"Types.h"` gets the copy from
whichever include directory comes first on the compiler's command line. Generated code finds its own package's copy,
as the including file's directory is searched first, but with `includeGuardStyle = "IncludeGuard"` both copies share
the guard `TYPES_H`, so a file that reaches both through generated headers silently loses the second. Give one of the
packages an `includePrefix`. The same holds for a dependency regenerated through `regeneratePackages` under the same
prefix as the original: link only one copy. A hand-written `Foo.h` beside a `.cc` file shadows a generated one, for
the same reason. `shortenIncludes = "SameDirectory"` does not work across packages; leave it unset.

Mocks are no exception: set `generateMocks = "GMock"` in `Coco.toml` _and_ `cpp_mocks = "GMock"` on `coco_package`
to get mocks for `coco_cc_test_library`. With only the attribute set, the build fails with
`output ... was not created`; with only the setting, popili writes mocks that no target uses.

## C# Code Generation

To generate C# code:

```starlark
load("@rules_coco//coco:defs.bzl", "coco_generate")

coco_generate(
    name = "my_package_csharp_src",
    language = "csharp",
    package = ":my_package",
)
```

The generated files are written to `bazel-bin/<package path>/_coco/<generate name>/<path below the source root>`,
see [Where Generated Code Goes](packages.md#where-generated-code-goes).

**Note:** C# code generation produces `.cs` files but does not include compilation support. Bazel's C# rules are currently too primitive to provide a good integration. The generated C# files can be consumed by other build systems or IDEs.
