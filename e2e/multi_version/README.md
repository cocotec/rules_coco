# Multi-Version E2E Test

This is an end-to-end test for rules_coco's multi-version support feature.

## Purpose

This test verifies that:

- Multiple popili versions can be registered simultaneously
- Different `coco_package` targets can use different popili versions in the same build
- The `popili_version` attribute correctly selects the appropriate toolchain
- The `--@rules_coco//:version` flag provides a working default
- C++ code generation works with version-specific toolchains
- All packages can be built and verified in a single bazel command

## Structure

```
e2e/smoke/multi_version/
├── MODULE.bazel          # Registers popili 1.5.0 and 1.5.1
├── BUILD.bazel           # Test targets with different version specifications
├── modern/               # Package explicitly using popili 1.5.0
│   ├── Coco.toml
│   └── src/Example.coco
├── legacy/               # Package explicitly using popili 1.5.1
│   ├── Coco.toml
│   └── src/Example.coco
└── flexible/             # Package using default version from flag
    ├── Coco.toml
    └── src/Example.coco
```

## Running the Tests

From the repository root:

```bash
# Run all multi-version tests
bazel test //e2e/smoke/multi_version:all

# Run specific tests
bazel test //e2e/smoke/multi_version:modern_verify
bazel test //e2e/smoke/multi_version:legacy_verify
bazel test //e2e/smoke/multi_version:flexible_verify

# Build all packages (tests toolchain resolution)
bazel build //e2e/smoke/multi_version:modern
bazel build //e2e/smoke/multi_version:legacy
bazel build //e2e/smoke/multi_version:flexible

# Build C++ generated code (tests version-specific code generation)
bazel build //e2e/smoke/multi_version:modern_cc
bazel build //e2e/smoke/multi_version:legacy_cc
bazel build //e2e/smoke/multi_version:flexible_cc

# Test with different default versions
bazel test //e2e/smoke/multi_version:flexible_verify --@rules_coco//:version=1.5.0
bazel test //e2e/smoke/multi_version:flexible_verify --@rules_coco//:version=1.5.1
```

## What This Tests

### Version Registration

- `MODULE.bazel` registers both popili 1.5.0 and 1.5.1
- Version-specific C++ runtime repositories are exposed

### Per-Target Version Selection

- `modern` package has `popili_version = "1.5.0"` - always uses popili 1.5.0
- `legacy` package has `popili_version = "1.5.1"` - always uses popili 1.5.1
- `flexible` package has no version attribute - uses the flag default

### Toolchain Resolution

- Bazel's toolchain resolution picks the correct toolchain based on:
  - The `popili_version` attribute (if specified)
  - The `--@rules_coco//:version` flag (otherwise)
  - Platform constraints (os, architecture)

### Configuration Transitions

- Each package with a `popili_version` attribute transitions to that configuration
- Dependencies between packages with different versions work correctly

### C++ Integration

- Code generation works with version-specific toolchains
- Version-specific C++ runtimes are correctly linked

## Expected Behavior

When running `bazel test //e2e/smoke/multi_version:all`:

1. Bazel resolves three different toolchain configurations (1.5.0, 1.5.1, and default)
2. Each package is built/verified with its specified toolchain
3. All tests pass, demonstrating successful multi-version support

## CI Integration

This test runs automatically in CI as part of `bazel test //...` across multiple platforms and Bazel versions.
