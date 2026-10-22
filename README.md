# rules_coco

[Bazel](https://github.com/bazelbuild/bazel) rules for the [Coco language](https://cocotec.io/popili/coco/) that can
use [Popili](https://cocotec.io/popili/) to:

- Generate code from Coco packages.
- Run verification on Coco packages as part of Bazel test.

The rules are fully compatible with remote caching and execution.

## Requirements

- Bazel 8.0.0 or higher.
- Popili 1.5.0 or higher.
- A valid Coco/Popili license.

## Setup

Follow the installation instructions from the [latest release](https://github.com/cocotec/rules_coco/releases/latest).

### bzlmod (Recommended)

Add the following to your `MODULE.bazel` file:

```starlark
bazel_dep(name = "rules_coco")
archive_override(
    module_name = "rules_coco",
    urls = [
        "https://github.com/cocotec/rules_coco/releases/download/VERSION/rules_coco_VERSION.tar.gz",
        "https://dl.cocotec.io/rules_coco/rules_coco_VERSION.tar.gz",
    ],
    integrity = "sha256-HASH",  # See releases page
)

coco = use_extension("@rules_coco//coco:extensions.bzl", "coco")
coco.toolchain(
    versions = ["stable"],  # Or specify explicit versions like ["1.5.1"]
    c = True,   # Enable C runtime (for coco_c_library)
    cc = True,  # Enable C++ runtime (for coco_cc_library)
)
```

Every module declaring `coco.toolchain` contributes its versions and runtimes. When no module in
the dependency graph declares one, `stable` is registered with both runtimes.

**Get the exact version and integrity hash from the [releases page](https://github.com/cocotec/rules_coco/releases).**

### WORKSPACE (Deprecated)

> [!WARNING]
> Beware that `WORKSPACE` mode is deprecated and will be removed in a future version. Please migrate to bzlmod.

Add the following to your `WORKSPACE` file:

```starlark
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_coco",
    integrity = "sha256-HASH",  # See releases page
    urls = [
        "https://github.com/cocotec/rules_coco/releases/download/VERSION/rules_coco_VERSION.tar.gz",
        "https://dl.cocotec.io/rules_coco/rules_coco_VERSION.tar.gz",
    ],
)

load("@rules_coco//coco:repositories.bzl", "coco_repositories")

coco_repositories(
    versions = ["stable"],  # Or explicit versions, e.g. ["1.5.1"] or ["1.5.1", "1.5.0"]
    c = True,   # Enable C runtime (for coco_c_library)
    cc = True,  # Enable C++ runtime (for coco_cc_library)
)
```

**Get the exact version and integrity hash from the [releases page](https://github.com/cocotec/rules_coco/releases).**

In `WORKSPACE` mode the repository must be named `rules_coco`: the generated toolchain hub
refers to `@rules_coco//:version` and `@rules_coco//coco:toolchain_type` by absolute label, and
repositories created by a repository rule have no repository mapping to rewrite them.

## Configuration

### Licensing

To use the rules, the host where the build actions executes will need to have a license. If the build runs locally,
then this means that local host requires a license. If remote execution is being used, then the remote executor will
need a license.

When using these rules in a CI environment you will need to provide a machine token. This can either be done by:

- (Preferred) Using workload identity federation: in this, tokens from your existing identity provider can be used to
  authenticate to Cocotec. This works with AWS or any OIDC-compatible identity provider, such as Github Actions and
  Google Cloud.
- Using a secret API token for the Cocotec services.

Contact [Cocotec Support](https://cocotec.io/support/) to set this up or discuss options.

`rules_coco` supports several different license modes:

- `action_environment`: Suitable credentials will be provided in the execution environment of each action. What is
  supported will depend on the version of Popili, but could include `COCOTEC_AUTH_TOKEN` being injected into the
  build action environment via some non-bazel mechanism.

  This is the recommended mode when using remote execution, as it will not interfere with bazel's cache, and also keeps
  the license token most secure.

- `action_file`: An auth token file path is provided that is guaranteed to be available in the execution environment of
  each action (e.g., mounted on remote runners). The path must be specified via `--@rules_coco//:auth_token_path` or in
  the toolchain configuration. Popili will be invoked with `--machine-auth-token` pointing to this file.

  This mode is suitable for remote execution environments where auth token files are pre-mounted or made available through
  other mechanisms. **Requires popili 1.5.2 or later.**

- `local_acquire`: A license will be acquired on the local machine as part of the build using `COCOTEC_AUTH_TOKEN`.
  This is not compatible with remote execution.
- `local_user`: The user's existing license on this machine will be reused. This is not compatible with remote
  execution. Each popili version gets the license file it reads (`licenses_<n>.lic` in popili's data directory, `n`
  being its licence protocol version); a local or bring-your-own toolchain of unknown version gets the file of the
  newest protocol version, unless it sets `license_protocol_version` or (bring your own) `popili_version`.
- `token`: The explicitly provided token should be used as `COCOTEC_AUTH_TOKEN`. In this case,
  `--@rules_coco//:license_token` must be set as well. This works with remote execution but it is only recommended when
  using workload identity federation as `COCOTEC_AUTH_TOKEN` is not a secret in that case.

This can be configured in three ways (in order of precedence):

1. **Via command-line flag** (highest precedence):

   ```bash
   bazel build --@rules_coco//:license_source=local_acquire //...

   # For action_file mode, also specify the auth token path:
   bazel build --@rules_coco//:license_source=action_file --@rules_coco//:auth_token_path=/path/to/token //...
   ```

2. **In MODULE.bazel** (for bzlmod users):

   ```python
   coco = use_extension("@rules_coco//coco:extensions.bzl", "coco")
   coco.toolchain(
       versions = ["stable"],
       license_source = "local_acquire",  # Optional: set repository default
       # license_token = "...",  # Optional: only needed when license_source = "token"
       # auth_token_path = "/path/to/token",  # Optional: only needed when license_source = "action_file"
   )
   ```

3. **In WORKSPACE** (for WORKSPACE users):
   ```python
   coco_repositories(
       versions = ["stable"],
       license_source = "local_acquire",  # Optional: set repository default
       # license_token = "...",  # Optional: only needed when license_source = "token"
       # auth_token_path = "/path/to/token",  # Optional: only needed when license_source = "action_file"
   )
   ```

The repository-level configuration (MODULE.bazel or WORKSPACE) sets a default that applies to all builds, while the
command-line flag can be used to override it for specific builds. If neither is specified, the default is `local_user`.

**⚠️ Security Warning for `license_token`:**

The `license_token` parameter is available in repository configuration for convenience, but:

- The `license_token` parameter should **only** be used in repository configuration when using workload identity
  federation, where the token is not a secret.
- For secret tokens, use the command-line flag instead: `--@rules_coco//:license_token=<token>`, or better yet ensure
  that your bazel execution environment injects `COCOTEC_AUTH_TOKEN` directly into actions.

### Popili Version

Register every Popili version you need; the first one is the default. In `MODULE.bazel`:

```starlark
coco = use_extension("@rules_coco//coco:extensions.bzl", "coco")
coco.toolchain(
    c = True,
    cc = True,
    versions = ["1.5.0", "1.5.1"],
)
```

or, in `WORKSPACE`:

```starlark
coco_repositories(
    c = True,
    cc = True,
    versions = ["1.5.0", "1.5.1"],
)
```

Then choose the version per target with `popili_version` on the rules that run Popili:
`coco_generate`, `coco_verify_test`, `coco_fmt_test` (its `<name>.format` binary formats with the
same version), `coco_architecture_diagram`, `coco_state_diagram` and `coco_counterexample_diagram`.
A pin applies to that target and everything beneath it, so the `coco_package` it reads is analysed
with the same version. Aliases such as `"stable"` are allowed.

`coco_cc_library`, `coco_cc_test_library`, `coco_c_library` and `coco_c_test_library` take
`popili_version` too. On a `coco_cc_library` it selects which version's runtime the library links,
and it also applies to the unpinned `coco_generate` targets the library builds from. The library's
own `srcs`, `deps` and `gmock` are not affected.

A `coco_cc_library` only builds from code generated by the same version. So if you pin a
`coco_generate`, pin the `coco_cc_library` that uses it to the same version; otherwise the build
fails with a message saying what to pin. You can skip this when the `coco_generate` is pinned to
the version unpinned targets get anyway: the default, or the value of `--@rules_coco//:version`.

All the `coco_generate` targets one `coco_cc_library` builds from must use the same version. For
code generated by several versions, use one `coco_cc_library` per version. A `cc_binary` that
links `coco_cc_library` targets of different versions links the runtime of each version, so only
do that when those runtimes can be linked together.

```starlark
coco_package(
    name = "modern",
    srcs = ["modern/src/Example.coco"],
    package = "modern/Coco.toml",
)

coco_generate(
    name = "modern_cpp",
    language = "cpp",
    package = ":modern",
    popili_version = "1.5.1",
)

coco_cc_library(
    name = "modern_cc",
    generated_package = ":modern_cpp",
    popili_version = "1.5.1",
)

coco_verify_test(
    name = "modern_verify",
    package = ":modern",
    popili_version = "1.5.1",
)
```

Everything without a pin uses the default, or the version `--@rules_coco//:version` selects, for
example `bazel build --@rules_coco//:version=1.5.1 //...`. The flag takes a concrete version (or
`local`); aliases such as `stable` are for pins only. A pin always wins over the flag.

A pin equal to the version the build uses anyway (the flag, or the default when the flag is unset)
costs nothing. A target pinned to any other version is built in a configuration of its own, so its
outputs and test logs land under `bazel-out/<cpu>-fastbuild-ST-<hash>/` rather than in `bazel-bin`
and `bazel-testlogs`. In CI, collect test results through the Build Event Protocol
(`--build_event_json_file`) or from `bazel-out/*/testlogs/**/test.xml`.

`with_popili_version` remains for targets that have no `popili_version` of their own, such as a
custom rule that resolves the Coco toolchain: it builds the wrapped target and everything beneath
it with the given version.

See `e2e/multi_version` for a full example, in both `MODULE.bazel` and `WORKSPACE` form.

### Using a local toolchain

To point at a popili toolchain on the local filesystem instead of a download add `coco.local_toolchain` to
`MODULE.bazel`:

```starlark
coco = use_extension("@rules_coco//coco:extensions.bzl", "coco")
coco.local_toolchain(
    popili = "/path/to/popili-dist",      # holds the popili + cocotec-licensing-server binaries
    cc_runtime = "/path/to/cpp-runtime",  # optional: holds the `coco/` subtree
    # c_runtime = "/path/to/c-runtime",   # optional: holds the `coco_c/` subtree
)
```

Each path (absolute, or workspace-relative) mirrors the **extracted release archive layout** — i.e. the contents
of `popili_<os>_<arch>.zip`, `coco-cpp-runtime.zip`, and `coco-c-runtime.zip` respectively. To use it, run with
`bazel build --@rules_coco//:version=local //...` (consider a `.bazelrc` `--config`).

Under `local_user` licensing, set `license_protocol_version` when your popili does not read the newest licence
protocol version, e.g. `license_protocol_version = 6` for popili 1.5.x.

For `WORKSPACE` mode use `coco_local_repositories(path=..., cc_runtime_path=..., c_runtime_path=...)`,
which behaves the same way: the local toolchain is selected by `--@rules_coco//:version=local` and
never becomes the default, so a build that does not set the flag fails, saying that no default popili
version is registered.

To register a local distribution _alongside_ downloaded releases, pass it to `coco_repositories`
instead, and switch between them with the version flag:

```starlark
coco_repositories(
    cc = True,
    versions = ["1.5.1"],
    local_popili = "/path/to/popili-dist",
    local_cc_runtime = "/path/to/cpp-runtime",
)
```

See `e2e/local_toolchain`.

### Bring your own toolchain

To point at a popili toolchain obtained from other bazel rules you can register your own `coco_toolchain` and skip
rules_coco's toolchain machinery entirely. In `MODULE.bazel` you just need

```starlark
register_toolchains("//tools:my_popili_tc")
```

```starlark
# tools/BUILD.bazel
load("@rules_coco//coco:toolchain.bzl", "coco_toolchain")

coco_toolchain(
    name = "my_popili",
    coco = "//path/to:popili",
    cocotec_licensing_server = "//path/to:cocotec-licensing-server",
    # cc_runtime = "//path/to:cpp_runtime",  # optional cc_library, for coco_cc_library
    # popili_version = "1.5.8",  # optional, picks the licence file under local_user licensing
)

toolchain(
    name = "my_popili_tc",
    toolchain = ":my_popili",
    toolchain_type = "@rules_coco//coco:toolchain_type",
)
```

### Using an older C++ compiler (Boost libraries)

Most users can skip this section. The Coco C++ runtime compiles cleanly on any toolchain that supports C++11 or
later. It also includes limited support for GCC 4.x but requires some Boost dependencies to support this compiler.

`rules_coco` does not supply its own `rules_boost`; instead you need to supply your own library targets if you want to
ensure compatibility with older compilers. In `rules_boost` terms the two targets are `@boost//:integer` and
`@boost//:type_traits`.

#### Every build uses GCC 4.x

Depend on Boost unconditionally:

```starlark
coco = use_extension("@rules_coco//coco:extensions.bzl", "coco")
coco.toolchain(versions = ["1.5.1"], cc = True)
coco.cc_runtime_deps(
    version = "1.5.1",
    deps = ["@boost//:integer", "@boost//:type_traits"],
)
```

#### Some builds use GCC 4.x, some don't

`MODULE.bazel` is evaluated before `select()` fires, so the conditional lives in a target you own:

```starlark
# MODULE.bazel
coco.cc_runtime_deps(version = "1.5.1", deps = ["//third_party/boost_shim"])
```

```starlark
# third_party/boost_shim/BUILD.bazel
cc_library(name = "empty")
cc_library(
    name = "boost_bundle",
    deps = ["@boost//:integer", "@boost//:type_traits"],
)

alias(
    name = "boost_shim",
    actual = select({
        "//config:old_libstdcxx": ":boost_bundle",
        "//conditions:default": ":empty",
    }),
    visibility = ["//visibility:public"],
)
```

`//config:old_libstdcxx` is whatever `config_setting` you already use to identify old-compiler builds — typically a
platform constraint so the `select()` fires automatically off `--platforms`:

```starlark
# //config/BUILD.bazel
constraint_setting(name = "libstdcxx_era")
constraint_value(name = "pre_gcc5", constraint_setting = ":libstdcxx_era")
config_setting(name = "old_libstdcxx", constraint_values = [":pre_gcc5"])
```

#### Same as above, and keep `rules_boost` out of modern-compiler workspaces

The shim above still pulls `rules_boost` into every workspace, because `@boost//:integer` is named in a `select()`
branch Bazel must load. A `label_flag` defers the reference until `.bazelrc` sets it:

```starlark
# third_party/boost_shim/BUILD.bazel
cc_library(name = "empty")
label_flag(
    name = "boost_shim",
    build_setting_default = ":empty",
    visibility = ["//visibility:public"],
)
```

```ini
# .bazelrc — only old-compiler configs set the flag
build:old_compiler --//third_party/boost_shim=@boost//:integer
```

In a real build, point the flag at an aggregate covering both `@boost//:integer` and `@boost//:type_traits`.

A `coco.local_toolchain` runtime is addressed as version `"local"`:

```starlark
coco.cc_runtime_deps(version = "local", deps = ["//third_party/boost_shim"])
```

#### WORKSPACE mode

A flat list applies to every registered version:

```starlark
coco_repositories(
    versions = ["1.5.1"],
    cc = True,
    cc_runtime_extra_deps = ["@my_workspace//third_party/boost_shim"],
)
```

A dict targets one version at a time, mirroring bzlmod's per-version `coco.cc_runtime_deps` tag:

```starlark
coco_repositories(
    versions = ["1.5.1", "1.5.0"],
    cc = True,
    cc_runtime_extra_deps = {
        "1.5.1": ["@my_workspace//third_party/boost_shim"],
        "1.5.0": ["@my_workspace//third_party/boost_shim_old"],
    },
)
```

Naming a version that was not registered is an error. Unlike the bzlmod tag, these labels are not
resolved against your workspace before being written into the generated runtime repository, so
they must be repository-absolute (`@my_workspace//...`, not `//...`).

Which target you name is an independent choice: the three patterns above describe that, and all
three work here unchanged — Boost directly, a `cc_library` wrapping a `select()`, or a `label_flag`.
Only the spelling differs between the two modes.

### Verification Backend

The verification backend can be selected using the `--@rules_coco//:verification_backend` option:

- `local`: Local verification (default). Runs on the build executor.
- `remote`: Remote verification: uses the configured remote verification service.
- `attempt-remote`: Attempt remote, fallback to local if it's not available.

For example:

```bash
bazel build --@rules_coco//:verification_backend=remote //...
```

## Usage

### Defining Packages

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

To enable type checking as part of the build, add `typecheck = True`:

```starlark
coco_package(
    name = "my_package",
    srcs = glob(["*.coco"]),
    package = "Coco.toml",
    typecheck = True,  # Validates types before code generation
)
```

When enabled, any target depending on this package (such as `coco_generate`) will wait for typecheck to pass.

#### Where Generated Code Goes

`coco_generate` writes all generated code, including test code and mocks, below a directory of its own,
`bazel-bin/<package>/_coco/<name>/`, and makes that directory a quote include directory of every library built from
it. Below it, each file lies under the package's `includePrefix` (`generator.cpp.includePrefix` or
`generator.c.includePrefix` in `Coco.toml`, empty by default) at its path relative to its source root
(`package.sources` or `package.testSources` in `Coco.toml`). Generated headers are included the way popili's own
generated code includes them (see [Including Generated Headers](#including-generated-headers)). With `Coco.toml` in
`pkg` and `sources = ["src", "interfaces"]`:

| Source                        | Include the generated header as |
| ----------------------------- | ------------------------------- |
| `pkg/src/Foo.coco`            | `#include "Foo.h"`              |
| `pkg/interfaces/api/Bar.coco` | `#include "api/Bar.h"`          |

With `includePrefix = "motor"` in `Coco.toml`, and `include_prefix = "motor"` on the `coco_generate`, the same
headers are included as `"motor/Foo.h"` and `"motor/api/Bar.h"`.

`outputDirectory` and `testOutputDirectory` in `Coco.toml` are ignored. If one package is generated for several
languages, give each `coco_generate` different file extensions (see [Output Paths](#output-paths)) so that their
files do not clash.

> [!NOTE]
> rules_coco 0.3 included generated headers by the path of their source file (`#include "pkg/src/Foo.h"`). See the
> [changelog](CHANGELOG.md) for how to update your include paths.

To predict these paths, `coco_package` needs the source roots. If all `srcs` (or `test_srcs`) are below one
directory, that directory is used. Otherwise, for example when a package has several roots, set `source_roots` (or
`test_source_roots`):

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

### Generating Code

#### C++ Code Generation

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

#### C Code Generation

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

##### Output Paths

Bazel has to be able to precompute the output paths of all rules. Since there are many settings in `Coco.toml` that
can affect output paths, these settings must be repeated in the `BUILD` file. If you forget to do this, you will get
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
```

Then this would require the following in your `BUILD` file:

```starlark
coco_generate(
    name = "my_package_cc_src",
    language = "cpp",
    package = ":my_package",
    cpp_header_file_extension = ".hpp",        # Must match Coco.toml
    cpp_implementation_file_extension = ".cpp", # Must match Coco.toml
    cpp_file_name_mangler = "LowerUnderscore", # Must match Coco.toml
)
```

| Coco.toml Setting                           | `coco_generate` Attribute           |
| ------------------------------------------- | ----------------------------------- |
| `generator.c.headerFileExtension`           | `c_header_file_extension`           |
| `generator.c.implementationFileExtension`   | `c_implementation_file_extension`   |
| `generator.c.headerFilePrefix`              | `c_header_file_prefix`              |
| `generator.c.implementationFilePrefix`      | `c_implementation_file_prefix`      |
| `generator.c.fileNameMangler`               | `c_file_name_mangler`               |
| `generator.c.flatFileHierarchy`             | `c_flat_file_hierarchy`             |
| `generator.c.includePrefix`                 | `include_prefix`                    |
| `generator.c.regeneratePackages`            | `c_regenerate_packages`             |
| `generator.cpp.headerFileExtension`         | `cpp_header_file_extension`         |
| `generator.cpp.implementationFileExtension` | `cpp_implementation_file_extension` |
| `generator.cpp.headerFilePrefix`            | `cpp_header_file_prefix`            |
| `generator.cpp.implementationFilePrefix`    | `cpp_implementation_file_prefix`    |
| `generator.cpp.fileNameMangler`             | `cpp_file_name_mangler`             |
| `generator.cpp.flatFileHierarchy`           | `cpp_flat_file_hierarchy`           |
| `generator.cpp.includePrefix`               | `include_prefix`                    |
| `generator.cpp.regeneratePackages`          | `cpp_regenerate_packages`           |
| `generator.csharp.regeneratePackages`       | `csharp_regenerate_packages`        |

Mirror the package's _effective_ value: the one in its own `Coco.toml`, or else the one it inherits from its
workspace's `Coco.toml` or receives from a dependency with `exportConfig = true`.

#### Including Generated Headers

Include a generated header the way popili's own generated code includes it: by the module's path below its source
root, behind the package's `includePrefix` if it has one.

```c++
#include "Foo.h"        // pkg/src/Foo.coco, no includePrefix
#include "api/Bar.h"    // pkg/interfaces/api/Bar.coco, no includePrefix
#include "motor/Foo.h"  // pkg/src/Foo.coco, includePrefix = "motor"
```

The same string works everywhere: in hand-written code, in the package's own generated code and in the generated
code of Coco packages depending on it, whichever repository the package lives in. `coco_cc_library` and
`coco_c_library` need no `includes` for generated headers; `includes` keeps its `cc_library` meaning for
hand-written ones.

`include_prefix` on `coco_generate` mirrors `Coco.toml` like the settings in the table above: set it to the
package's effective `includePrefix`. The default, `""`, is popili's default too. A package with
`includePrefix = "motor"` depending on `//base`:

```starlark
coco_package(
    name = "motor",
    srcs = glob(["src/**/*.coco"]),
    package = "Coco.toml",
    deps = ["//base"],
)

coco_generate(
    name = "motor_cpp",
    include_prefix = "motor",  # Must match Coco.toml
    language = "cpp",
    package = ":motor",
)

coco_cc_library(
    name = "motor_cc",
    generated_package = ":motor_cpp",
    deps = ["//base:base_cc"],
)
```

If `include_prefix` differs from the effective `includePrefix`, compiling the package's own generated code fails,
because popili wrote the includes with the `Coco.toml` value:

```
fatal error: 'motor/Foo.h' file not found
```

The path in the message names the value to set. Keep the two equal even for a package nothing depends on yet: a
small package may compile despite a mismatch, as its sources find headers in their own directory, and the packages
that later depend on it fail instead.

Things to know:

- **One name in unrelated packages.** Coco rejects two modules at the same path within one dependency chain, but
  two unrelated packages may both have `src/Types.coco`. A file including both as `"Types.h"` gets the one from
  the first include directory on its command line. Give one of the packages an `includePrefix`. With
  `headerGuardStyle = "IncludeGuard"`, both headers also carry the guard `TYPES_H`, so the second is skipped
  silently rather than failing.
- **Hand-written headers beside generated ones.** `#include "Foo.h"` searches the including file's own directory
  first, so a hand-written `Foo.h` next to a `.cc` file shadows the generated one.
- **`shortenIncludes = "SameDirectory"`** does not work across packages. popili then includes a dependency's header
  by bare name whenever it sits in the same directory, relative to its own source root, as the file including it,
  for example when both modules sit at the top of their source roots. Leave it unset.
- **Regenerated packages.** With `regeneratePackages`, a dependency's code is generated a second time, under the
  regenerating package's settings and prefix. If both prefixes are equal, the two copies are included by the same
  strings, and a binary linking both gets whichever comes first without a diagnostic, so link only one of them.

#### C# Code Generation

To generate C# code:

```starlark
load("@rules_coco//coco:defs.bzl", "coco_generate")

coco_generate(
    name = "my_package_csharp_src",
    language = "csharp",
    package = ":my_package",
)
```

The generated files are written below `bazel-bin/<package>/_coco/<name>/`, at each module's path relative to its
source root.

**Note:** C# code generation produces `.cs` files but does not include compilation support. Bazel's C# rules are currently too primitive to provide a good integration. The generated C# files can be consumed by other build systems or IDEs.

### Verification

These rules can be used to create bazel test targets that execute the verification when `bazel test` is executed.

```starlark
load("@rules_coco//coco:defs.bzl", "coco_verify_test")

coco_verify_test(
    name = "my_package_test",
    package = ":my_package",
)
```

### Formatting

Format checking can be integrated into your test suite using `coco_fmt_test`:

```starlark
load("@rules_coco//coco:defs.bzl", "coco_fmt_test")

coco_fmt_test(
    name = "my_package_fmt_test",
    package = ":my_package",
)
```

This creates two targets:

- `my_package_fmt_test`: Test that fails if code isn't formatted (`bazel test`)
- `my_package_fmt_test.format`: Binary to format code in-place (`bazel run`)

### Diagram Generation

`rules_coco` provides rules for generating diagrams from Coco code:

#### Architecture Diagrams

Generate component architecture diagrams showing the structure and connections of your components:

```starlark
load("@rules_coco//coco:defs.bzl", "coco_architecture_diagram")

# Generate diagram for a single component
coco_architecture_diagram(
    name = "my_component_arch",
    package = ":my_package",
    components = {
        "my_component.svg": "MyComponent",
    },
    port_names = True,
    port_types = True,
)

# Generate diagrams for multiple components
coco_architecture_diagram(
    name = "all_components_arch",
    package = ":my_package",
    components = {
        "component1.svg": "Component1",
        "component2.svg": "Component2",
        "component3.svg": "Component3",
    },
)
```

#### State Machine Diagrams

Generate state machine diagrams:

```starlark
load("@rules_coco//coco:defs.bzl", "coco_state_diagram")

coco_state_diagram(
    name = "my_state_machine",
    package = ":my_package",
    targets = ["MyComponent.MyMachine"],
    separate_edges = False,
)
```

**Note:** State diagram generation currently requires packages with a single `.coco` file.

#### Counterexample Diagrams

Generate sequence diagrams for verification failures. You must specify the expected counterexamples as a dict mapping
output filenames to target declarations:

```starlark
load("@rules_coco//coco:defs.bzl", "coco_counterexample_diagram")

coco_counterexample_diagram(
    name = "my_counterexamples",
    package = ":my_package",
    counterexamples = {
        "alarm_failure.svg": "Alarm",
        "safety_violation.svg": "SafetyChecker",
    },
    deterministic = True,
)
```

For filtering by specific assertions, use the `counterexample_options()` helper:

```starlark
load("@rules_coco//coco:defs.bzl", "coco_counterexample_diagram", "counterexample_options")

coco_counterexample_diagram(
    name = "specific_counterexamples",
    package = ":my_package",
    counterexamples = {
        "safety.svg": counterexample_options(
            decl = "SafetyChecker",
            assertion = "Well-formedness",
        ),
        "liveness.svg": counterexample_options(
            decl = "LivenessChecker",
            assertion = "Implements Provided Port",
        ),
    },
)
```

## API Reference

For detailed API documentation of all rules, macros, and their attributes, see the auto-generated documentation:

- **[defs.md](docs/defs.md)** - Core rules and macros
- **[cc.md](docs/cc.md)** - C++ integration
- **[c.md](docs/c.md)** - C integration
- **[extensions.md](docs/extensions.md)** - Module extension (bzlmod setup)
- **[repositories.md](docs/repositories.md)** - Repository setup (WORKSPACE mode)
- **[renovate.md](docs/renovate.md)** - Using Renovate for automatic updates (including offline/firewall scenarios)

## License

Copyright 2019- Cocotec Limited. Licensed under the Apache License, Version 2.0.
