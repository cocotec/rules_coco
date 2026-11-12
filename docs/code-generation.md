# Generating code

Code is generated from a [`coco_package`](packages.md) with `coco_generate`, and compiled with the C or C++
library rules. See [where generated code goes](packages.md#where-generated-code-goes) for the output layout and
how to include generated headers.

## C++ code generation

To generate [C++ code](https://cocotec.io/popili/doc/stable/cpp/index.html):

```starlark
load("@rules_coco//coco:defs.bzl", "coco_generate")

coco_generate(
    name = "my_package_cc_src",
    language = "cpp",
    package = ":my_package",
)
```

Compile the generated C++ with `coco_cc_library`, which adds the
[C++ runtime](https://cocotec.io/popili/doc/stable/cpp/runtime.html#cpp-runtime) as a dependency:

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

Besides `generated_package`, `coco_cc_library` and `coco_c_library` (and their test variants) take:

- `generated_packages`: several `coco_generate` targets compiled into one library; mutually exclusive with the
  `generated_package` attribute.
- `srcs`, `hdrs` and `deps`: hand-written sources, headers and dependencies to add to the library.
- `public_hdrs`: the generated headers dependents may include. By default that is all of them; `[]` makes them all
  private. An entry names a header by file name (`"ISensor.h"`) or, when several headers share a name, by a trailing
  part of its include path (`"sensors/ISensor.h"`). An entry that matches no header is an error.

Any other attribute, such as `copts` or `visibility`, is passed on to the rule that compiles the library:
`library_rule` when set, otherwise rules_cc's `cc_library`.

## C code generation

Enable the C runtime with `c = True` on `coco.toolchain` (or `coco_repositories`):

```starlark
coco.toolchain(
    versions = ["stable"],
    c = True,
)
```

To generate C code:

```starlark
load("@rules_coco//coco:defs.bzl", "coco_generate")

coco_generate(
    name = "my_package_c_src",
    language = "c",
    package = ":my_package",
)
```

Compile the generated C with `coco_c_library`:

```starlark
load("@rules_coco//coco:c.bzl", "coco_c_library")

coco_c_library(
    name = "my_package_c",
    generated_package = ":my_package_c_src",
)
```

Link it like any other `cc_library`:

```starlark
cc_binary(
    name = "main",
    srcs = ["main.c"],
    deps = [":my_package_c"],
)
```

`coco_c_test_library` compiles the generated C test code; see [Test code and mocks](#test-code-and-mocks).

## Output paths

Bazel has to be able to precompute the output paths of all rules. Since there are many settings in `Coco.toml` that can
affect output paths, these settings must be repeated on the `coco_package` in the `BUILD` file. If you forget to do
this, you will get errors when running `coco_generate` such as:

```
ERROR: example/BUILD:10:14: output 'example/Example.h' was not created
ERROR: example/BUILD:10:14: Generating cpp example_test failed: not all outputs were created or valid
```

If you see these errors then you need to make sure that the `BUILD` files contain mirrors of the settings in the
`Coco.toml` file. For example, suppose you have the following `Coco.toml` file.

```toml
[generator.cpp]
headerFileExtension = ".hpp"
runtimeHeaderFileExtension = ".h"   # required with a custom headerFileExtension
implementationFileExtension = ".cpp"
fileNameMangler = "LowerUnderscore"
includePrefix = "motor"
```

> [!IMPORTANT]
> With a custom `headerFileExtension` in `[generator.cpp]` or `[generator.c]`, `Coco.toml` must also set
> `runtimeHeaderFileExtension = ".h"` in the same section.

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

| Coco.toml Setting                                                                                                                               | `coco_package` Attribute            |
| ----------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| [`generator.c.headerFileExtension`](https://cocotec.io/popili/doc/1.6/codegen/c/settings.html#generator.c.headerFileExtension)                  | `c_header_file_extension`           |
| [`generator.c.implementationFileExtension`](https://cocotec.io/popili/doc/1.6/codegen/c/settings.html#generator.c.implementationFileExtension)  | `c_implementation_file_extension`   |
| [`generator.c.headerFilePrefix`](https://cocotec.io/popili/doc/1.6/codegen/c/settings.html#generator.c.headerFilePrefix)                        | `c_header_file_prefix`              |
| [`generator.c.implementationFilePrefix`](https://cocotec.io/popili/doc/1.6/codegen/c/settings.html#generator.c.implementationFilePrefix)        | `c_implementation_file_prefix`      |
| [`generator.c.fileNameMangler`](https://cocotec.io/popili/doc/1.6/codegen/c/settings.html#generator.c.fileNameMangler)                          | `c_file_name_mangler`               |
| [`generator.c.flatFileHierarchy`](https://cocotec.io/popili/doc/1.6/codegen/c/settings.html#generator.c.flatFileHierarchy)                      | `c_flat_file_hierarchy`             |
| [`generator.c.includePrefix`](https://cocotec.io/popili/doc/1.6/codegen/c/settings.html#generator.c.includePrefix)                              | `c_include_prefix`                  |
| [`generator.c.regeneratePackages`](https://cocotec.io/popili/doc/1.6/codegen/c/settings.html#generator.c.regeneratePackages)                    | `c_regenerate_packages`             |
| [`generator.cpp.headerFileExtension`](https://cocotec.io/popili/doc/stable/cpp/settings.html#generator.cpp.headerFileExtension)                 | `cpp_header_file_extension`         |
| [`generator.cpp.implementationFileExtension`](https://cocotec.io/popili/doc/stable/cpp/settings.html#generator.cpp.implementationFileExtension) | `cpp_implementation_file_extension` |
| [`generator.cpp.headerFilePrefix`](https://cocotec.io/popili/doc/1.6/codegen/cpp/settings.html#generator.cpp.headerFilePrefix)                  | `cpp_header_file_prefix`            |
| [`generator.cpp.implementationFilePrefix`](https://cocotec.io/popili/doc/1.6/codegen/cpp/settings.html#generator.cpp.implementationFilePrefix)  | `cpp_implementation_file_prefix`    |
| [`generator.cpp.fileNameMangler`](https://cocotec.io/popili/doc/stable/cpp/settings.html#generator.cpp.fileNameMangler)                         | `cpp_file_name_mangler`             |
| [`generator.cpp.flatFileHierarchy`](https://cocotec.io/popili/doc/stable/cpp/settings.html#generator.cpp.flatFileHierarchy)                     | `cpp_flat_file_hierarchy`           |
| [`generator.cpp.includePrefix`](https://cocotec.io/popili/doc/stable/cpp/settings.html#generator.cpp.includePrefix)                             | `cpp_include_prefix`                |
| [`generator.cpp.regeneratePackages`](https://cocotec.io/popili/doc/stable/cpp/settings.html#generator.cpp.regeneratePackages)                   | `cpp_regenerate_packages`           |
| [`generator.cpp.generateMocks`](https://cocotec.io/popili/doc/stable/cpp/settings.html#generator.cpp.generateMocks)                             | `cpp_mocks`                         |
| [`generator.csharp.regeneratePackages`](https://cocotec.io/popili/doc/1.6/codegen/csharp/settings.html#generator.csharp.regeneratePackages)     | `csharp_regenerate_packages`        |
| [`generator.csharp.generateMocks`](https://cocotec.io/popili/doc/1.6/codegen/csharp/settings.html#generator.csharp.generateMocks)               | `csharp_mocks`                      |

Each package in a `*_regenerate_packages` list must be a dependency of the package, directly or through another
package in `deps`, because Popili only regenerates dependencies. Otherwise the build fails with
`... is not a dependency of ...`.

### Include prefixes

Mirror the package's _effective_ value: the one in its own `Coco.toml`, or else the one it inherits from its workspace's
`Coco.toml` or receives from a dependency with `exportConfig = true` (see
[`includePrefix`](https://cocotec.io/popili/doc/stable/cpp/settings.html#generator.cpp.includePrefix),
[`exportConfig`](https://cocotec.io/popili/doc/stable/language/structure.html#package.exportConfig) and
[workspaces](https://cocotec.io/popili/doc/stable/language/structure.html#workspace)). A wrong `cpp_include_prefix` or
`c_include_prefix` fails when compiling the package's own generated code, as Popili wrote its includes with the
`Coco.toml` value:

```
fatal error: 'motor/Foo.h' file not found
```

The path in the message names the value to set. Keep the two equal even for a package nothing depends on yet: a
small package may compile despite a mismatch, as its sources find headers in their own directory, and the packages
that later depend on it fail instead.

### Header name collisions

Two unrelated packages may both have `src/Types.coco`. Hand-written code including `"Types.h"` gets the copy from
whichever include directory comes first on the compiler's command line. Generated code finds its own package's copy, as
the including file's directory is searched first, but with
[`includeGuardStyle = "IncludeGuard"`](https://cocotec.io/popili/doc/stable/cpp/settings.html#generator.cpp.includeGuardStyle)
both copies share the guard `TYPES_H`, so a file that reaches both through generated headers silently loses the second.
Give one of the packages an `includePrefix`. The same holds for a dependency regenerated through `regeneratePackages`
under the same prefix as the original: link only one copy. A hand-written `Foo.h` beside a `.cc` file shadows a
generated one, for the same reason.
[`shortenIncludes = "SameDirectory"`](https://cocotec.io/popili/doc/stable/cpp/settings.html#generator.cpp.shortenIncludes)
does not work across packages; leave it unset.

## Test code and mocks

Popili writes two kinds of test code: code generated from the package's test sources (`testSources` in `Coco.toml`), and
mocks of its components
([`generateMocks`](https://cocotec.io/popili/doc/stable/cpp/settings.html#generator.cpp.generateMocks); see
[mock generation](https://cocotec.io/popili/doc/stable/cpp/testing.html#mock-generation)). `coco_cc_test_library` and
`coco_c_test_library` compile this test code apart from the production library:

```starlark
coco_package(
    name = "example",
    srcs = glob(["src/**/*.coco"]),
    test_srcs = glob(["test/**/*.coco"]),  # testSources = ["test"] in Coco.toml
    cpp_mocks = "GMock",                   # generateMocks = "GMock" in Coco.toml
    package = "Coco.toml",
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

coco_cc_test_library(
    name = "example_cc_tst",
    generated_package = ":example_cpp",
    deps = [":example_cc"],
)

cc_test(
    name = "example_test",
    srcs = ["example_test.cc"],
    deps = [":example_cc_tst"],
)
```

Mocks are no exception: set `generateMocks = "GMock"` in `Coco.toml` _and_ `cpp_mocks = "GMock"` on `coco_package`
to get mocks for `coco_cc_test_library`. With only the attribute set, the build fails with
`output ... was not created`; with only the setting, Popili writes mocks that no target uses.

The test libraries link GoogleTest through `gmock`, which defaults to `@googletest//:gtest`. Add
`bazel_dep(name = "googletest", version = "...")` to `MODULE.bazel`, or set `gmock` to another target, or to `None` to
leave GoogleTest out. Set `test_source_roots` for `test_srcs` in the same cases as `source_roots` (see
[Source roots](packages.md#source-roots)). [`e2e/smoke`](../e2e/smoke) is a tested example.

Each `coco_generate` target also creates a `<name>.tst` target with only the generated test code, mocks included, for
consumers other than the test libraries. `coco_test_outputs_name` from `@rules_coco//coco:defs.bzl` returns its name.

## C# code generation

To generate [C# code](https://cocotec.io/popili/doc/1.6/codegen/csharp/index.html):

```starlark
load("@rules_coco//coco:defs.bzl", "coco_generate")

coco_generate(
    name = "my_package_csharp_src",
    language = "csharp",
    package = ":my_package",
)
```

> [!NOTE]
> C# code generation produces `.cs` files but does not include compilation support. Bazel's C# rules are currently too
> primitive to provide a good integration. The generated C# files can be consumed by other build systems or IDEs.

With `csharp_mocks` or test sources, the generated C# test code is in the `<name>.tst` target; see
[Test code and mocks](#test-code-and-mocks).
