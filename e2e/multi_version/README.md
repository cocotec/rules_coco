# Multi-Version E2E Test

End-to-end test for registering several popili versions in one build, in **both** `MODULE.bazel`
and `WORKSPACE` mode.

## What this tests

- Several popili versions can be registered at once, and each gets its own version-mangled
  repository (`io_cocotec_coco_<os>_<arch>__<version>`).
- The first registered version is what an unset `--@rules_coco//:version` resolves to.
- `--@rules_coco//:version=<v>` and the `with_popili_version` transition select another registered
  version — in WORKSPACE mode as well as under bzlmod.
- Code generation and `coco_cc_library` work against version-specific toolchains and runtimes.

## Structure

```
e2e/multi_version/
├── MODULE.bazel               # Registers popili 1.5.0 and 1.5.1 (bzlmod)
├── WORKSPACE                  # Registers the same two versions (WORKSPACE mode)
├── BUILD.bazel                # Version-selection assertions + per-version packages
├── popili_version_report.bzl  # Rule asserting which popili the toolchain resolves to
├── modern/                    # Package built against popili 1.5.0
├── legacy/                    # Package built against popili 1.5.1
└── flexible/                  # Package built against the default version
```

## Running

From this directory:

```bash
# Everything, in either mode
bazel test --config=bzlmod    //...
bazel test --config=workspace //...     # needs Bazel 8.x; WORKSPACE is gone in Bazel 9

# Just the version-selection assertions (analysis only, no popili execution, no licence)
bazel build --config=workspace --nobuild //:popili_is_150_by_default //:popili_is_151

# Override the default version
bazel build --config=workspace --@rules_coco//:version=1.5.1 //:flexible_cpp
```

CI runs this scenario in both modes via the `e2e/*/` loop in
`.github/workflows/continuous-integration.yml`, not as part of the root `bazel test //...`
(`e2e/` is listed in `/.bazelignore`).

## How version selection is asserted

`popili_version_report` resolves `@rules_coco//coco:toolchain_type` in its own configuration and
fails at analysis time unless the resolved popili lives in the expected version's repository. That
is a direct assertion on toolchain resolution: it needs no licence, no network and no popili
execution, and reads identically in both modes.

Two cases are covered:

- `popili_is_150_by_default` — unwrapped, so it must resolve 1.5.0, the first registered version.
- `popili_is_151` — wrapped in `with_popili_version(version = "1.5.1")`, so it must resolve 1.5.1.

Because the check happens during analysis, these are plain targets rather than tests: being part
of `//...` is enough for `bazel build` or `bazel test` to run them. There is deliberately no
`build_test` wrapper — it generates genrules, which need a working `bash`, and the assertion needs
no action to run at all. `popili_is_151_impl` is tagged `manual` so that `//...` reaches it only
through the transition wrapper; built directly it would resolve the default version and fail.

## Known gap

`modern_verify`, `legacy_verify` and `flexible_verify` take a _wrapped package_ but are not wrapped
themselves. `with_popili_version` carries an incoming transition, so it affects the target it wraps
and everything below it — not the target that consumes it. Those tests therefore run the default
popili regardless of the version their package asks for, and pass only because every registered
version can verify every package here. The `popili_version_report` targets above are what actually
pin version selection in the meantime.

Fixing the ergonomics — so that `coco_verify_test(package = ":legacy", popili_version = "1.5.1")`
works without a wrapper — needs an attribute transition on the popili-running rules, which is a
separate change with its own API design.
