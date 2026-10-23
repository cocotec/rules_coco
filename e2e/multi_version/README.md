# Multi-Version E2E Test

End-to-end test for registering several popili versions in one build, in **both** `MODULE.bazel`
and `WORKSPACE` mode.

## What this tests

- Several popili versions can be registered at once, and each gets its own version-mangled
  repository (`io_cocotec_coco_<os>_<arch>__<version>`).
- The first registered version is what an unset `--@rules_coco//:version` resolves to.
- `popili_version` on a rule that runs popili selects another registered version for that target
  and the package beneath it, and wins over `--@rules_coco//:version`; an unpinned target follows
  the flag. In WORKSPACE mode as well as under bzlmod. A target pinned to the default shares the
  configuration (and output paths) of the unpinned ones; one pinned to 1.5.1 gets its own.
- `with_popili_version` still gives a version to a rule that has no `popili_version` of its own.
- `--@rules_coco//:force_version` ignores every pin and wrapper, so `--@rules_coco//:version` (or
  the default) applies to everything; the whole scenario builds and passes at 1.5.1 that way.
- Code generation at a pinned version feeds a `coco_cc_library` and a `cc_test` in the default
  configuration. A library's `popili_version` selects the runtime it links (`legacy_cc` links the
  1.5.1 runtime, `modern_cc` at the default shares the top-level configuration) and applies to an
  unpinned generator beneath it (`flexible_cc_at_151`); a library whose runtime is not the
  version its generated code came from fails with a message saying what to pin
  (`library_pinned_elsewhere`, `library_unpinned`), as does a library over generators at two
  versions (`library_mixed_generators`), unless forced, which puts library and generator at one
  version (`library_*_forced_*`).
- A pinned `coco_cc_test_library` keeps its default `gmock` in the test's configuration, so
  `legacy_mock_test`, which also depends on `@googletest//:gtest_main`, links one googletest.
- `coco_verify_test` and `coco_fmt_test` name the popili of the execution platform the test runs
  on (`test_platform_test.bzl`), checked with a foreign target platform and the host as the first
  execution platform. Bazel 9+ only: Bazel 8 does not tie tests to the target platform.
- A build without a matching toolchain fails with rules_coco's own message (the shared
  `popili_diagnostics_tests` from `@rules_coco//test/popili_diagnostics:diagnostics_test.bzl`).

## Structure

```
e2e/multi_version/
├── MODULE.bazel               # Registers popili 1.5.0 and 1.5.1 (bzlmod)
├── WORKSPACE                  # Registers the same two versions (WORKSPACE mode)
├── BUILD.bazel                # Per-version packages, pins and the assertions
├── pinned_popili_test.bzl     # Analysis tests: which popili a pinned/unpinned target runs
├── popili_version_report.bzl  # Rule asserting which popili the toolchain resolves to
├── test_platform_test.bzl     # Analysis test: a test's wrapper names popili for the test's platform
├── stub_cc_toolchain.bzl      # Analysis-only C++ toolchain for the foreign platform of that test
├── modern/                    # Package whose targets are pinned to popili 1.5.0
├── legacy/                    # Package whose targets are pinned to popili 1.5.1; its code and mocks feed cc_tests
└── flexible/                  # Package left on the default version
```

## Running

From this directory:

```bash
# Everything, in either mode
bazel test --config=bzlmod    //...
bazel test --config=workspace //...     # needs Bazel 8.x; WORKSPACE is gone in Bazel 9

# Just the version-selection assertions (analysis only, no popili execution, no licence)
bazel build --config=workspace --nobuild //:popili_is_150_by_default //:popili_is_151
bazel test --config=workspace //:pinned_popili

# Override the default version for everything unpinned
bazel build --config=workspace --@rules_coco//:version=1.5.1 //:flexible_cpp

# Run everything at 1.5.1, pins included. :popili_is_150_by_default asserts the unflagged
# default by design, so it is left out.
bazel test --@rules_coco//:force_version --@rules_coco//:version=1.5.1 -- //... -//:popili_is_150_by_default
```

CI runs this scenario in both modes via the `e2e/*/` loop in
`.github/workflows/continuous-integration.yml`, not as part of the root `bazel test //...`
(`e2e/` is listed in `/.bazelignore`).

## How version selection is asserted

`pinned_popili_test.bzl` reads the popili a target would run off its action (the run action's
executable, or a test's wrapper script) and checks the version-mangled repository name, with and
without `--@rules_coco//:version=1.5.1`, and with `--@rules_coco//:force_version` in both of those
states. That is a direct assertion on toolchain resolution in the real rules: it needs no licence,
no network and no popili execution, and reads identically in both modes. Every analysis test here
sets both flags itself, so the suite passes whatever the command line sets.

`popili_version_report` does the same for a rule that resolves the toolchain itself, and also
checks the toolchain's `version` field:

- `popili_is_150_by_default` — unwrapped, so it must resolve 1.5.0, the first registered version.
- `popili_is_151` — wrapped in `with_popili_version(version = "1.5.1")`, so it must resolve 1.5.1.

Because the check happens during analysis, these are plain targets rather than tests: being part
of `//...` is enough for `bazel build` or `bazel test` to run them. There is deliberately no
`build_test` wrapper — it generates genrules, which need a working `bash`, and the assertion needs
no action to run at all. `popili_is_151_impl` is tagged `manual` so that `//...` reaches it only
through the transition wrapper; built directly it would resolve the default version and fail.
