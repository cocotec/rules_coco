# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- WORKSPACE mode now supports multiple Popili versions, like bzlmod already did.
  `coco_repositories(versions = ["1.5.1", "1.5.0"])` registers a toolchain per version, selected
  with `--@rules_coco//:version=1.5.0` or per target with `with_popili_version`. The first entry is
  used when the flag is unset.
- `coco_repositories` gained `local_popili`, `local_cc_runtime` and `local_c_runtime`, so a Popili
  distribution on the local filesystem can be registered alongside downloaded releases and selected
  with `--@rules_coco//:version=local`. This is the WORKSPACE equivalent of combining
  `coco.toolchain` with `coco.local_toolchain`.
- `cc_runtime_extra_deps` now accepts a dict mapping a version to its labels, in addition to a flat
  list applied to every registered version.

### Changed

- **Breaking:** the local toolchain registered by `coco_local_repositories()` in WORKSPACE mode is
  now selected by `--@rules_coco//:version=local` and is no longer active by default, matching the
  bzlmod `coco.local_toolchain` tag. Builds that do not set the flag will report
  `No matching toolchains found for @rules_coco//coco:toolchain_type`. Add
  `common --@rules_coco//:version=local` to your `.bazelrc`.
- **Breaking:** the generated per-platform repositories are now version-mangled, matching bzlmod:
  `io_cocotec_coco_<os>_<arch>` became `io_cocotec_coco_<os>_<arch>__<version>`, and the local one
  became `io_cocotec_coco_local` (previously `coco_local`). The `io_cocotec_coco_<os>_<arch>_toolchains`
  proxy repositories are gone; every `toolchain()` is now declared in the `@coco_toolchains` hub and
  registered with a single `@coco_toolchains//:all`. These names are implementation details, only
  reachable via `--extra_toolchains` or `--override_repository`.
- **Breaking:** `coco_repositories` takes explicit named parameters instead of `**kwargs`, so an
  unrecognised argument is now an error rather than being silently ignored.
- `coco_repositories` now fails with a clear message if called more than once, instead of producing
  duplicate-repository warnings and a silently wrong configuration.
- `"local"` and `"default"` are rejected as version strings; they name the hub's own
  `config_setting`s.

### Fixed

- `coco_repositories(versions = [...])` was accepted but silently ignored in WORKSPACE mode, so a
  workspace following the README's "Popili Version" section got `stable` instead of the versions it
  asked for. It is now honoured — check that your default version has not moved.

## [0.3.0] - 2026/05/31

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
