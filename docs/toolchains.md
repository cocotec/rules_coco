# Custom toolchains

By default rules_coco downloads popili and its runtimes for every registered version. This page covers the
two alternatives: a popili distribution on the local filesystem, and a toolchain you build or fetch yourself.

## Using a local toolchain

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

Under [`local_user` licensing](licensing.md#license-modes), set `license_protocol_version` when your popili does not read the newest licence
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

See [`e2e/local_toolchain`](../e2e/local_toolchain).

## Bring your own toolchain

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
    popili_version = "1.5.8",  # required: the version of that popili, not an alias
)

toolchain(
    name = "my_popili_tc",
    toolchain = ":my_popili",
    toolchain_type = "@rules_coco//coco:toolchain_type",
)
```

Use this when one `popili`, built in your repository, should run every target. A `toolchain()` without
`target_settings` or constraints, like the one above, matches every target, so it replaces rules_coco's own
toolchains and no pin or flag can select another one. Register only one such toolchain, since one registered after
it would never be selected; in `WORKSPACE`, register it before calling `coco_repositories`.

`popili_version` is the version of the `popili` binary the toolchain points at, such as `"1.5.8"`; an alias such
as `"stable"` is rejected. It picks the licence file under `local_user` licensing, and every target must ask for
that version or for none in particular. A target pinned to another version, or built with
`--@rules_coco//:version` set to another version, fails instead of running this `popili`:

```
@@//a:gen needs popili 1.5.1 (pinned by popili_version), but the bring-your-own coco_toolchain @@//tools:my_popili, which serves every target, is popili 1.5.8. ...
```

See [`e2e/byo_toolchain`](../e2e/byo_toolchain).
