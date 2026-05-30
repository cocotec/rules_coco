# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Coco workspaces are now supported via the new `coco_workspace` rule and `workspace` attribute on `coco_package`.
- `coco.local_toolchain` allows you to point `rules_coco` at a `popili` on the local filesystem instead of a downloaded
  release. See the README section "Using a local toolchain".
- Documented how you can use `rules_coco` with your own `popili` toolchain obtained from other bazel rules. See the
  README section "Bring your own toolchain".

### Changed

- The Coco wrapper macros (`coco_generate`, `coco_package`, `coco_fmt_test`, `coco_workspace`, `coco_verify_test`,
  `coco_state_diagram`, `coco_architecture_diagram`) are now Bazel symbolic macros, so their attributes and
  documentation appear in `bazel query` output and the generated reference docs.
- **Breaking:** the `coco_fmt_test` formatter binary is now named `<name>.format` (previously the test target name
  with the `_test` suffix stripped). Run it as e.g. `bazel run //pkg:foo_fmt_test.format`.

### Fixed

- `coco_verify_test` and `coco_fmt_test` now resolve `--package`/`--import-path` against the runfiles tree, so a
  package that depends on a `coco_package` in another Bazel repository verifies correctly, fixing errors such as
  `invalid import path; external/<repo> is not a directory`.

## [0.2.0] - 2026/04/20

### Added

- `coco.cc_runtime_deps` module-extension tag and `cc_runtime_extra_deps` keyword argument on `coco_repositories()`
  for injecting extra `cc_library` targets into the Coco C++ runtime. This can be used to wire up Boost libraries when
  building against libstdc++ older than GCC 5. See the README section "Using an older C++ compiler (Boost libraries)"
  for usage patterns. (#138)

## [0.1.1] - 2025/11/14

Initial public release of Bazel rules for Popili.

### Added

#### Core Rules

##### Package and Code Generation

- `coco_package` - Define Coco packages from Coco.toml and .coco source files (supports `typecheck` attribute)
- `coco_generate` - Generate code from Coco packages (supports C++, C, and C# output)

##### C++ Language Support

- `coco_cc_library` - Build C++ libraries from generated code (includes runtime automatically)
- `coco_cc_test_library` - Build C++ test libraries with gMocks

##### C Language Support

- `coco_c_library` - Build C libraries from generated code (includes C runtime automatically)
- `coco_c_test_library` - Build C test libraries

##### Diagram Generation

- `coco_architecture_diagram` - Generate architecture diagrams from Coco packages
- `coco_counterexample_diagram` - Generate counterexample diagrams from verification results
- `coco_state_diagram` - Generate state machine diagrams
- `counterexample_options` - Helper for filtering counterexample diagrams

##### Testing and Verification

- `coco_fmt_test` - Check formatting and format code in-place
- `coco_verify_test` - Run Popili verification as a Bazel test

##### Version Management

- `with_popili_version` - Allows multiple Popili versions to be used side-by-side.

#### Build System Support

- bzlmod support for Bazel 8.0.0+ (recommended)
- WORKSPACE support (deprecated, will be removed in future versions)
- Multi-version support: Use multiple Popili versions in the same workspace

#### Platform Support

- Linux: x86_64, aarch64
- macOS: aarch64
- Windows: x86_64

[Unreleased]: https://github.com/cocotec/rules_coco/compare/0.1.0...HEAD
[0.1.0]: https://github.com/cocotec/rules_coco/releases/tag/0.1.0
