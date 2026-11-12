# Setup

Follow the installation instructions from the [latest release](https://github.com/cocotec/rules_coco/releases/latest).
Each release lists the exact version and integrity hash to use in place of `VERSION` and `HASH` below.

## bzlmod (Recommended)

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

See [Popili versions](popili-versions.md) for registering and pinning several versions, and the
[module extension reference](reference/extensions.md) for every tag and attribute.

## WORKSPACE (Deprecated)

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

In `WORKSPACE` mode the repository must be named `rules_coco`: the generated toolchain hub
refers to `@rules_coco//:version` and `@rules_coco//coco:toolchain_type` by absolute label, and
repositories created by a repository rule have no repository mapping to rewrite them.

See the [repository rules reference](reference/repositories.md) for every `coco_repositories` argument.

## Keeping rules_coco up to date

rules_coco is fetched with `archive_override`, which Renovate does not update on its own. See
[Using Renovate](renovate.md) for a configuration that does, including for networks that cannot
reach GitHub.
