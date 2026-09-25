# Multi-Version E2E Test

End-to-end test for using several popili versions in one build, in **both** `MODULE.bazel` and
`WORKSPACE` mode.

## What this tests

- Several popili versions can be registered at once (1.5.0, the default, and 1.5.1), each in its
  own version-mangled repository (`io_cocotec_coco_<os>_<arch>__<version>`).
- `popili_version` on a `coco_package` or `coco_workspace` selects the version for that package,
  and every consumer (verify, generate, and the C++ runtime `coco_cc_library` links) uses it.
- An unpinned package takes its workspace's pin, else the default.
- A dependency's pin never changes the consuming package's version. When they differ, the
  package warns that the pin is ignored.
- A package pinning a different version from its workspace is an error.
- `with_popili_version` forces a version over every pin in the subgraph it wraps, and rejects an
  unregistered version.

## Structure

```
e2e/multi_version/
├── MODULE.bazel               # Registers popili 1.5.0 and 1.5.1 (bzlmod)
├── WORKSPACE                  # Registers the same two versions (WORKSPACE mode)
├── BUILD.bazel                # The packages and every assertion
├── popili_version_report.bzl  # Asserts which popili / runtime a target uses, at analysis time
├── pinning_failure_test.bzl   # Asserts a target fails analysis with a given message
├── shared/                    # Unpinned library, used on both versions
├── modern/                    # Pins 1.5.0
├── legacy/                    # Pins 1.5.1; depends on shared
├── uses_legacy/               # Unpinned, depends on legacy: resolves 1.5.0 and warns
├── flexible/                  # Unpinned, depends on modern (1.5.0): no warning
└── ws150/                     # Workspace pinning 1.5.0
    └── app/                   # ws_app: inherits 1.5.0, depends on legacy (warns) and shared
```

## Running

From this directory:

```bash
# Everything, in either mode
bazel test --config=bzlmod    //...
bazel test --config=workspace //...     # needs Bazel 8.x; WORKSPACE is gone in Bazel 9

# Just the version assertions (analysis only: no popili execution, no licence)
bazel build --nobuild --config=bzlmod //...
bazel test --config=bzlmod //:ws_app_disagrees_test //:on_unregistered_test

# Force everything onto one version, overriding every pin
bazel build --config=bzlmod --@rules_coco//:version=1.5.1 --@rules_coco//:force_version //...
```

The last command fails on purpose, on the `*_is_150*` reports: forcing 1.5.1 is exactly what
they check doesn't happen by default.

CI runs this scenario in both modes via the `e2e/*/` loop in
`.github/workflows/continuous-integration.yml`, not as part of the root `bazel test //...`
(`e2e/` is listed in `/.bazelignore`).

## How version selection is asserted

`popili_version_report` fails at analysis time unless the target it points at uses the expected
version. It checks the repository the resolved popili, or the linked C++ runtime, comes from.
It needs no licence, no network and no popili execution, and reads identically in both modes.
What it checks depends on which attribute is set:

- none: the toolchain resolved in the report's own configuration (`popili_is_150_by_default`, and
  `popili_is_151` through `with_popili_version`);
- `package`: the toolchain a `coco_package` resolved and hands to its consumers, and the warnings
  it raised about pinned dependencies (`expected_warnings`; an empty list asserts none);
- `generated`: the toolchain a `coco_generate` target generated its code with;
- `library`: the C++ runtime linked into a `coco_cc_library`, which must be exactly one.

Because the check happens during analysis, these are plain targets rather than tests: being part
of `//...` is enough for `bazel build` or `bazel test` to run them. There is deliberately no
`build_test` wrapper. It generates genrules, which need a working `bash`, and the assertion needs
no action to run at all. The two expected failures are `analysistest`s on `manual` targets.

The `*_verify` tests and `*_cc` libraries also run popili for real, so `bazel test //...`
additionally checks that each version really verifies and generates its packages.
