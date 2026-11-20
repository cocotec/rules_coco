# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A bring-your-own toolchain can now list its own licence server to be used with the `local_acquire` licence mode. See
  [Bring your own toolchain](docs/toolchains.md#bring-your-own-toolchain).

### Changed

- Under `local_user` and `local_acquire`, Popili now gets the licence file by its absolute path instead of as an action
  input, so a renewed or newly acquired licence no longer reruns every Popili action and test. Under `local_acquire`,
  the licence is now acquired when Bazel fetches repositories. See [Licence modes](docs/licensing.md#licence-modes).
- Under the `local_user` and `local_acquire` licence modes, Popili's actions and tests now always run on the host, even
  with remote execution enabled. See [Licence modes](docs/licensing.md#licence-modes).
- **Breaking:** under `local_acquire`, a bring-your-own `coco_toolchain` must set its new `local_acquire_licenses`, for
  example to a `coco_license_repository`, for Popili to get the acquired licence. `fetch_license` has been removed. See
  [Bring your own toolchain](docs/toolchains.md#bring-your-own-toolchain).

### Deprecated

- `coco_toolchain`'s `cocotec_licensing_server` is ignored and no longer required: nothing runs the server from a build
  any more.

### Fixed

- Fixes an issue where `coco_verify_test` on Windows did not write its JUnit results to the file Bazel reads.

## [0.4.0] - 2026-11-19

### Added

- **Per-target Popili versions:** the rules that run Popili, and `coco_cc_library` and `coco_c_library`, now accept
  `popili_version`, which wins over `--@rules_coco//:version`. `--@rules_coco//:force_version` overrides every pin. See
  [Pinning targets](docs/popili-versions.md#pinning-targets).
- **Package version constraints:** `coco_package` and `coco_workspace` now accept `popili_versions`, the Popili versions
  a package supports. See
  [Restricting the versions of a package](docs/popili-versions.md#restricting-the-versions-of-a-package).
- **Multiple versions in WORKSPACE mode:** `coco_repositories(versions = [...])` now registers every listed version, as
  bzlmod already did. Previously the list was silently ignored and `stable` was used, so check that your default version
  has not moved. `local_popili`, `local_cc_runtime` and `local_c_runtime` register a local distribution alongside them.
  See [Registering versions](docs/popili-versions.md#registering-versions).
- `AVAILABLE_STABLE_VERSIONS` lists every stable Popili version rules_coco knows of. See
  [Registering versions](docs/popili-versions.md#registering-versions).
- `coco_package` now accepts `source_roots` and `test_source_roots`. See [Source roots](docs/packages.md#source-roots).
- The C and C++ library macros now accept `library_rule`, to compile with your own wrapper of `cc_library`. See
  [C++ code generation](docs/code-generation.md#c-code-generation).
- `cc_runtime_extra_deps` now accepts a dict from version to labels. See
  [Using an older C++ compiler](docs/old-compilers.md#workspace-mode).
- Local toolchains now accept `license_protocol_version`. See
  [Using a local toolchain](docs/toolchains.md#using-a-local-toolchain).
- `CocoPackageInfo`, `CocoCcGeneratedInfo` and `CocoCSharpGeneratedInfo` are now exported from
  `@rules_coco//coco:defs.bzl`. See the [API reference](docs/reference/defs.md).

### Changed

- **Breaking:** generated headers are now included the way Popili's own generated code includes them. See
  [Where generated code goes](docs/packages.md#where-generated-code-goes).
- **Breaking:** the `Coco.toml` generator attributes (`c_*`, `cpp_*` and `csharp_*`) moved from `coco_generate` to
  `coco_package`, which also gains `cpp_include_prefix` and `c_include_prefix`. `coco_generate`'s `mocks` is replaced by
  `cpp_mocks` and `csharp_mocks`. See [Output paths](docs/code-generation.md#output-paths).
- **Breaking:** `coco_cc_test_library` now takes GoogleMock from `coco.cc_test_runtime` (or `cc_test_runtime_gmock` in
  WORKSPACE mode) and links the runtime's `coco/gmock_helpers.h`. See [GoogleMock](docs/code-generation.md#googlemock).
- **Breaking:** rules_coco's default toolchain is now only registered when no module declares `coco.toolchain`. If yours
  declares one, add `c = True` / `cc = True` for the runtimes you use. See [Setup](docs/setup.md#bzlmod-recommended).
- **Breaking:** `coco_toolchain` now requires `popili_version`. A bring-your-own toolchain fails a target that asks for
  another version. See [Bring your own toolchain](docs/toolchains.md#bring-your-own-toolchain).
- **Breaking:** in WORKSPACE mode, the local toolchain of `coco_local_repositories` must now be selected with
  `--@rules_coco//:version=local`, as with bzlmod. See
  [Using a local toolchain](docs/toolchains.md#using-a-local-toolchain).
- **Breaking:** `coco_repositories` and `coco_local_repositories` now reject unknown arguments, and `coco_repositories`
  fails when called twice.
- **Breaking:** WORKSPACE mode's generated toolchain repositories are now named as in bzlmod and registered with
  `@coco_toolchains//:all`.
- The documentation moved from the README into [guides](docs/README.md); the API reference moved to
  [`docs/reference/`](docs/reference/README.md).
- A missing Popili toolchain is now reported with the requested and registered versions, instead of Bazel's generic
  error.
- `coco.toolchain` and `coco_repositories` now reject `"local"` and `"default"` in `versions`. Register a local
  distribution with `coco.local_toolchain` or `local_popili` instead.

### Removed

- **Breaking:** `with_popili_version` has been removed. Use `popili_version` instead.
- **Breaking:** the `gmock` attribute of `coco_cc_test_library` and `coco_c_test_library` has been removed.
  `coco_c_test_library` no longer adds GoogleMock; add it to `deps` if your tests need it.
- **Breaking:** `@rules_coco//coco:current_popili_version` and its `$(POPILI)` and `$(POPILI_STARTUP_ARGS)` make
  variables have been removed.
- Intel macOS is no longer supported, as Popili dropped it in 1.5.0.

### Fixed

- Fixes an issue where Popili toolchains only resolved under bzlmod when the target platform matched the host, which
  prevented cross-compiling with `--platforms`.
- Fixes an issue where `local_user` licensing looked for the licence in the wrong directory and passed every Popili
  version the same licence file, which Popili 1.6 rejects. `POPILI_DATA` is now respected.
- Fixes crashes on remote executors with some older Popili versions, by running build actions with `HOME=/nonexistent`.
- Fixes an issue where a package with `test_srcs` failed under Bazel's sandbox with `could not open the directory`.
- Fixes an issue where the source root was derived from the shortest source path, which failed for some layouts.
- Fixes an issue where predicted output file names did not match Popili's for some `fileNameMangler` settings.
- Fixes an issue where `coco_verify_test`, `coco_fmt_test` and its `.format` binary could run a Popili built for another
  platform.
- Fixes an issue where cross-compiling between Windows and POSIX generated the wrong wrapper script flavour.
- Fixes an issue where environment values in wrapper scripts were not quoted. POSIX wrappers now run with `/bin/sh`.
- Fixes an issue where the local toolchain was not constrained to the host's OS and CPU.
- Fixes an issue where the C and C++ library macros rejected some `select()`s.
- Fixes an issue where `coco_generate`, the C and C++ library macros and `coco_fmt_test` failed with `tags = ["manual"]`
  or `testonly`.
- Fixes an issue where the runtimes of Popili releases newer than rules_coco could not be used. Their downloads are not
  checksum-verified.

## [0.3.0] - 2026-05-31

### Added

- Coco workspaces are now supported via the new `coco_workspace` rule and `workspace` attribute on `coco_package`.
- `coco.local_toolchain` allows you to point `rules_coco` at a `popili` on the local filesystem instead of a downloaded
  release. See [Using a local toolchain](docs/toolchains.md#using-a-local-toolchain).
- Documented how you can use `rules_coco` with your own `popili` toolchain obtained from other bazel rules. See
  [Bring your own toolchain](docs/toolchains.md#bring-your-own-toolchain).

### Changed

- The Coco wrapper macros (`coco_generate`, `coco_package`, `coco_fmt_test`, `coco_workspace`, `coco_verify_test`,
  `coco_state_diagram`, `coco_architecture_diagram`) are now Bazel symbolic macros, so their attributes and
  documentation appear in `bazel query` output and the generated reference docs.
- **Breaking:** the `coco_fmt_test` formatter binary is now named `<name>.format` (previously the test target name with
  the `_test` suffix stripped). Run it as e.g. `bazel run //pkg:foo_fmt_test.format`.

### Fixed

- `coco_verify_test` and `coco_fmt_test` now resolve `--package`/`--import-path` against the runfiles tree, so a package
  that depends on a `coco_package` in another Bazel repository verifies correctly, fixing errors such as
  `invalid import path; external/<repo> is not a directory`.

## [0.2.0] - 2026-04-20

### Added

- `coco.cc_runtime_deps` module-extension tag and `cc_runtime_extra_deps` keyword argument on `coco_repositories()` for
  injecting extra `cc_library` targets into the Coco C++ runtime. This can be used to wire up Boost libraries when
  building against libstdc++ older than GCC 5. See [Using an older C++ compiler](docs/old-compilers.md) for usage
  patterns. (#138)

## [0.1.1] - 2025-11-14

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

[Unreleased]: https://github.com/cocotec/rules_coco/compare/0.3.4...HEAD
[0.3.0]: https://github.com/cocotec/rules_coco/releases/tag/0.3.0
[0.2.0]: https://github.com/cocotec/rules_coco/releases/tag/0.2.0
[0.1.1]: https://github.com/cocotec/rules_coco/releases/tag/0.1.1
