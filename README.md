# rules_coco

[Bazel](https://github.com/bazelbuild/bazel) rules for the [Coco language](https://cocotec.io/popili/coco/) that can
use [Popili](https://cocotec.io/popili/) to:

- Generate code from Coco packages.
- Run verification on Coco packages as part of Bazel test.

The rules are fully compatible with remote caching and execution.

## Requirements

- Bazel 8.0.0 or higher.
- A valid Coco/Popili license.

## Setup

### bzlmod (Recommended)

Add the following to your `MODULE.bazel` file:

```starlark
bazel_dep(name = "rules_coco")
archive_override(
    module_name = "rules_coco",
    urls = ["https://github.com/cocotec/rules_coco/archive/refs/tags/v0.1.0.tar.gz"],
    strip_prefix = "rules_coco-0.1.0",
    integrity = "sha256-<integrity-hash>",  # Replace with actual hash
)

coco = use_extension("@rules_coco//coco:extensions.bzl", "coco")
coco.toolchain(
    versions = ["stable"],  # Or specify explicit versions like ["1.5.1"]
    cc = True,
)
```

### WORKSPACE (Deprecated)

> [!WARNING] > `WORKSPACE` mode is deprecated and will be removed in a future version. Please migrate to bzlmod.

Add the following to your `WORKSPACE` file:

```starlark
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_coco",
    sha256 = "<sha256>",
    urls = ["https://github.com/cocotec/rules_coco/archive/refs/tags/v0.1.0.tar.gz"],
    strip_prefix = "rules_coco-0.1.0",
)

load("@rules_coco//coco:repositories.bzl", "coco_repositories")

coco_repositories(
    versions = ["stable"],  # Or specify explicit versions like ["1.5.1"]
    cc = True,
)
```

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

This can be set via a flag.

```bash
bazel build --@rules_coco//:license_source=local_acquire //...
```

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
       cc = True,
       versions = ["1.5.0", "1.4.0"],  # Register both versions
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

   coco_package_generate(
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

### Generating Code

To generate C++ code:

```starlark
load("@rules_coco//coco:defs.bzl", "coco_package_generate")

coco_package_generate(
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
coco_cc_library(
    name = "my_package_cc",
    generated_package = ":base_cpp",
)
```

### Verification

These rules can be used to create bazel test targets that execute the verification when `bazel test` is executed.

```starlark
load("@rules_coco//coco:defs.bzl", "coco_verify_test")

coco_verify_test(
    name = "my_package_test",
    package = ":my_package",
)
```

## License

Copyright 2024 Cocotec Limited. Licensed under the Apache License, Version 2.0.
