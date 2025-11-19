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

**Get the exact version and integrity hash from the [releases page](https://github.com/cocotec/rules_coco/releases).**

### WORKSPACE (Deprecated)

> [!WARNING] > `WORKSPACE` mode is deprecated and will be removed in a future version. Please migrate to bzlmod.

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
    version = "stable",  # Or specify a explicit version like "1.5.1"
    c = True,   # Enable C runtime (for coco_c_library)
    cc = True,  # Enable C++ runtime (for coco_cc_library)
)
```

**Get the exact version and integrity hash from the [releases page](https://github.com/cocotec/rules_coco/releases).**

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

- `local_acquire`: A license will be acquired on the local machine as part of the build using `COCOTEC_AUTH_TOKEN`.
  This is not compatible with remote execution.
- `local_user`: The user's existing license on this machine will be reused. This is not compatible with remote
  execution.
- `token`: The explicitly provided token should be used as `COCOTEC_AUTH_TOKEN`. In this case,
  `--@rules_coco//:license_token` must be set as well. This works with remote execution but it is only recommended when
  using workload identity federation as `COCOTEC_AUTH_TOKEN` is not a secret in that case.

This can be configured in three ways (in order of precedence):

1. **Via command-line flag** (highest precedence):

   ```bash
   bazel build --@rules_coco//:license_source=local_acquire //...
   ```

2. **In MODULE.bazel** (for bzlmod users):

   ```python
   coco = use_extension("@rules_coco//coco:extensions.bzl", "coco")
   coco.toolchain(
       versions = ["stable"],
       license_source = "local_acquire",  # Optional: set repository default
       # license_token = "...",  # Optional: only needed when license_source = "token"
   )
   ```

3. **In WORKSPACE** (for WORKSPACE users):
   ```python
   coco_repositories(
       version = "stable",
       license_source = "local_acquire",  # Optional: set repository default
       # license_token = "...",  # Optional: only needed when license_source = "token"
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

There are several ways of setting the version of Popili that you would like to use.

1. In `WORKSPACE` or `MODULE.bazel` you can specify a single version in `versions = [...]`.
2. If specifying several different versions in `WORKSPACE` or `MODULE.bazel` you can select your preferred one using
   `bazel build --@rules_coco//:version=1.5.1`
3. If you wish to use different versions of Popili by using transitions:

   In your `MODULE.bazel`:

   ```starlark
   coco = use_extension("@rules_coco//coco:extensions.bzl", "coco")
   coco.toolchain(
       c = True,
       cc = True,
       versions = ["1.5.0", "1.5.1"],  # Register both versions
   )
   ```

   Then in your `BUILD.bazel`:

   ```
   coco_package(
       name = "modern",
       srcs = ["modern/src/Example.coco"],
       package = "modern/Coco.toml",
   )

   with_popili_version(
       name = "modern_v150",
       target = ":modern",
       version = "1.5.0",
   )

   coco_generate(
       name = "modern_cpp",
       language = "cpp",
       package = ":modern_v150",
   )
   ```

   See `e2e/multi_version` for a full example.

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
    manifest = "Coco.toml",
)
```

If the `Coco.toml` file has dependencies then these need to be mirrored in the `BUILD` file:

```starlark
load("@rules_coco//coco:defs.bzl", "coco_package")

coco_package(
    name = "my_package",
    srcs = glob(["*.coco"]),
    manifest = "Coco.toml",
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
    manifest = "Coco.toml",
    typecheck = True,  # Validates types before code generation
)
```

When enabled, any target depending on this package (such as `coco_generate`) will wait for typecheck to pass.

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

This can then be compiled using `cc_library` like normal:

```starlark
load("@rules_cc//cc:defs.bzl", "cc_library")

cc_library(
    name = "my_package_cc",
    srcs = [":my_package_cc_src"],
    deps = [""],
)
```

Alternatively these steps can be combined using `coco_cc_library`:

```starlark
load("@rules_coco//coco:cc.bzl", "coco_cc_library")

coco_cc_library(
    name = "my_package_cc",
    generated_package = ":my_package_cc_src",
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
ERROR: example/BUILD:10:14: output 'example/src/Example.h' was not created
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
| `generator.c.regeneratePackages`            | `c_regenerate_packages`             |
| `generator.cpp.headerFileExtension`         | `cpp_header_file_extension`         |
| `generator.cpp.implementationFileExtension` | `cpp_implementation_file_extension` |
| `generator.cpp.headerFilePrefix`            | `cpp_header_file_prefix`            |
| `generator.cpp.implementationFilePrefix`    | `cpp_implementation_file_prefix`    |
| `generator.cpp.fileNameMangler`             | `cpp_file_name_mangler`             |
| `generator.cpp.flatFileHierarchy`           | `cpp_flat_file_hierarchy`           |
| `generator.cpp.regeneratePackages`          | `cpp_regenerate_packages`           |
| `generator.csharp.regeneratePackages`       | `csharp_regenerate_packages`        |

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
- `my_package_fmt`: Binary to format code in-place (`bazel run`)

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
