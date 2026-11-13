# Setup

Follow the installation instructions from the [latest release](https://github.com/cocotec/rules_coco/releases/latest).
Each release lists the exact version and integrity hash to use in place of `VERSION` and `HASH` below.

## bzlmod (recommended)

Add rules_coco to `MODULE.bazel` as in [Getting started](getting-started.md#1-add-rules_coco-to-modulebazel), and enable
the runtimes you need on [`coco.toolchain`](reference/extensions.md#coco.toolchain): `cc = True` for
[`coco_cc_library`](reference/cc.md#coco_cc_library), `c = True` for [`coco_c_library`](reference/c.md#coco_c_library).

Every module declaring `coco.toolchain` contributes its versions and runtimes. When no module in the dependency graph
declares one, `stable` is registered with both runtimes.

See [Popili versions](popili-versions.md) for registering and pinning several versions, and the
[module extension reference](reference/extensions.md) for every tag and attribute.

## `WORKSPACE` (deprecated)

<!-- prettier-ignore -->
> [!WARNING]
> The `WORKSPACE` mode is deprecated and needs Bazel 8.3.0 or higher. Please migrate to bzlmod.

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

For a single version, [`coco_repositories(version = "1.5.1", ...)`](reference/repositories.md#coco_repositories) is a
shorthand for `versions = ["1.5.1"]`. The two are mutually exclusive, and with neither, `stable` is registered.

In `WORKSPACE` mode the `http_archive` must be named `rules_coco`, because the repositories rules_coco generates refer
to `@rules_coco` by absolute label.

See the [repository rules reference](reference/repositories.md) for every `coco_repositories` argument.

## Keeping rules_coco up to date

rules_coco is fetched with `archive_override`, which Renovate does not update on its own. See
[Using Renovate](renovate.md) for a configuration that does, including for networks that cannot reach GitHub.
