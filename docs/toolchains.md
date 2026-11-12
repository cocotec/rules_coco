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
`bazel build --@rules_coco//:version=local //...`. To select it with `--config=local_popili`, add to `.bazelrc`:

```
build:local_popili --@rules_coco//:version=local
```

The local toolchain is registered alongside the versions from `coco.toolchain` (or the default `stable`), and never
becomes the default. Targets use those versions unless `--@rules_coco//:version=local` selects the local one, so the
same build can switch between them.

The local popili runs only on the host. If no registered execution platform is the host, for example under remote
execution, add `--extra_execution_platforms=@platforms//host`. On Bazel 9, which runs a test on an execution platform
matching the test's target platform, `coco_verify_test` and `coco_fmt_test` also need `--platforms=@platforms//host`.
rules_coco fails with a message naming the missing flag.

`coco.local_toolchain` is allowed only in the root module, and at most once.

Under [`local_user` licensing](licensing.md#license-modes), set `license_protocol_version` when your popili does not
read the newest licence protocol version, e.g. `license_protocol_version = 6` for popili 1.5.x.

For `WORKSPACE` mode use `coco_local_repositories(path=..., cc_runtime_path=..., c_runtime_path=...)`, with
`license_protocol_version=...` when needed (see above). It registers only the local toolchain, which is selected by
`--@rules_coco//:version=local` and never becomes the default. So a build that does not set the flag fails, saying
that no default popili version is registered.

In `WORKSPACE`, to register a local distribution _alongside_ downloaded releases, pass it to `coco_repositories`
instead, and switch between them with the version flag:

```starlark
coco_repositories(
    cc = True,
    versions = ["1.5.1"],
    local_popili = "/path/to/popili-dist",
    local_cc_runtime = "/path/to/cpp-runtime",
    # local_license_protocol_version = 6,  # as license_protocol_version above
)
```

See [`e2e/local_toolchain`](../e2e/local_toolchain).

## Bring your own toolchain

To use a popili obtained from other Bazel rules, register your own `coco_toolchain` and skip rules_coco's toolchain
downloads entirely. With bzlmod you don't need the `coco` extension at all, because rules_coco's own module sets up the
repositories its rules read. With `WORKSPACE`, still call `coco_repositories`, which creates those repositories, and
register your toolchain before it. In `MODULE.bazel` you just need

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
it would never be selected.

A bring-your-own `coco_toolchain` does not see the license settings on `coco.toolchain` or `coco_repositories`; those
apply only to the toolchains rules_coco creates. Set `license_source` (and `license_token` or `auth_token_path` when
the mode needs them) on the `coco_toolchain` itself, or use the `--@rules_coco//:license_source` flag.

`popili_version` is the version of the `popili` binary the toolchain points at, such as `"1.5.8"`; an alias such as
`"stable"` is rejected. Under `local_user` licensing it selects which license file popili gets. Because this toolchain
serves every target, a target may ask only for this version or for none. A target pinned to another version, or built
with `--@rules_coco//:version` set to another version, fails instead of running this `popili`:

```
@@//a:gen needs popili 1.5.1 (pinned by popili_version), but the bring-your-own coco_toolchain @@//tools:my_popili, which serves every target, is popili 1.5.8. ...
```

See [`e2e/byo_toolchain`](../e2e/byo_toolchain).

## Execution platforms and cross-compilation

Bazel picks popili by execution platform. For every registered version, rules_coco declares one toolchain per platform
popili supports: Linux (x86_64 and aarch64), macOS (aarch64) and Windows (x86_64). Each toolchain is constrained to
that execution platform only. So actions such as `coco_generate` run on any of these execution platforms, local or
remote, whatever the target platform.

The Coco runtimes that `coco_cc_library` and `coco_c_library` link are compiled for the target platform like any other
`cc_library`, so cross-compiling the generated code needs no extra configuration.

`coco_verify_test` and `coco_fmt_test` run popili when the test runs, using the popili of the execution platform the
test runs on. On Bazel 9 that platform must also match the test's target platform, so these tests need a target
platform that popili supports. Otherwise rules_coco fails with a message naming the target platform.

The `.format` target of `coco_fmt_test` uses the popili of the platform `bazel run` executes it on.
