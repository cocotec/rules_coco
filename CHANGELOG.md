# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- The Popili version is now a property of a package: set `popili_version` on a `coco_package` or
  `coco_workspace` (inherited by member packages and nested workspaces), and every rule using the
  package uses that version, including the runtime linked by `coco_cc_library` / `coco_c_library`.
  Different parts of a repository can use different registered versions. See the README section
  "Popili Version".
  - A pinned package ignores `--@rules_coco//:version`, unless the new
    `--@rules_coco//:force_version` is also set. `with_popili_version` overrides the pins in the
    target it wraps.
  - A package pinning a different version from its workspace is an error. A dependency pinning a
    different version prints a warning, and its pin is ignored there, as in Popili itself.
  - Builds without pins behave as before.
- Naming an unregistered Popili version now fails with a message listing the registered versions,
  instead of Bazel's `No matching toolchains found`.
- `coco_toolchain` has an optional `version` attribute, for the Popili version the toolchain
  provides. A bring-your-own toolchain declaring it can satisfy a matching pin.
- Builds using several Popili versions, including a local toolchain, now get a valid license for
  each. With `local_acquire`, only the licenses of the versions a build uses are acquired, and
  versions that can share a license share one.
- A warning is printed for a registered Popili version newer than this rules_coco release knows.
- `CocoWorkspaceInfo` has new optional fields for a workspace's `popili_version`. Existing rules
  returning `CocoWorkspaceInfo(files = ...)` keep working.
- WORKSPACE mode now supports multiple Popili versions, like bzlmod already did.
  `coco_repositories(versions = ["1.5.1", "1.5.0"])` registers a toolchain per version, selected
  per package with `popili_version` (see above) or with `--@rules_coco//:version=1.5.0`. The first
  entry is used when neither is set.
- `coco_repositories` gained `local_popili`, `local_cc_runtime` and `local_c_runtime`, so a Popili
  distribution on the local filesystem can be registered alongside downloaded releases and selected
  with `--@rules_coco//:version=local`. This is the WORKSPACE equivalent of combining
  `coco.toolchain` with `coco.local_toolchain`.
- `cc_runtime_extra_deps` now accepts a dict mapping a version to its labels, in addition to a flat
  list applied to every registered version.
- Remote execution on mixed platforms: every rule using a `coco_package` runs the package's Popili
  version built for the platform the rule executes on, and only the versions and platforms a build
  uses are downloaded. See the README section "Remote execution".

### Changed

- **Breaking:** rules_coco's default toolchain (`stable` with the C and C++ runtimes) is now used
  only when no module declares `coco.toolchain`. If yours declares one, you get only what it lists,
  so add `c = True` / `cc = True` for the runtimes you use. Modules that don't declare
  `coco.toolchain` are unaffected and still get `stable` with both runtimes.
- `coco_cc_library` and `coco_c_library` now always link the runtime of the Popili version the code
  was generated with.
- **Breaking:** the local toolchain registered by `coco_local_repositories()` in WORKSPACE mode is
  now selected by `--@rules_coco//:version=local` and is no longer active by default, matching the
  bzlmod `coco.local_toolchain` tag. Add `common --@rules_coco//:version=local` to your `.bazelrc`
  to keep using it.
- **Breaking:** the generated per-platform repositories are now version-mangled, matching bzlmod:
  `io_cocotec_coco_<os>_<arch>` became `io_cocotec_coco_<os>_<arch>__<version>`, and the local one
  became `io_cocotec_coco_local` (previously `coco_local`). The `io_cocotec_coco_<os>_<arch>_toolchains`
  proxy repositories are gone; every `toolchain()` is now declared in the `@coco_toolchains` hub and
  registered with a single `@coco_toolchains//:all`. These names are implementation details, only
  reachable via `--extra_toolchains` or `--override_repository`.
- **Breaking:** `coco_repositories` and `coco_local_repositories` take explicit named parameters
  instead of `**kwargs`, so an unrecognised argument is now an error rather than being silently
  ignored. Arguments that were previously only accepted by keyword remain keyword-only, so only
  `version` (and `path`, `cc_runtime_path` and `c_runtime_path` for `coco_local_repositories`)
  may be passed positionally.
- `coco_repositories` now fails with a clear message if called more than once, instead of producing
  duplicate-repository warnings and a silently wrong configuration.
- `"local"` and `"default"` are rejected as version strings; they name the hub's own
  `config_setting`s.
- Coco targets now build for any target platform, including when cross-compiling with
  `--platforms`. Before, bzlmod required the target platform to match the host.
- A missing Coco toolchain, such as `--@rules_coco//:version=local` without a local toolchain, or
  Popili running on a platform it isn't published for, is now reported with an error naming the
  target, instead of Bazel's `No matching toolchains found`.
- Using the Coco toolchain no longer requires a C++ toolchain for the platform Popili runs on.
- Using the local toolchain on an execution platform other than the host is now reported up front,
  instead of failing during execution.
- With `license_source` `local_acquire` or `local_user`, running Popili on an execution platform
  other than the host is now reported as an error, instead of passing the host's license to it.

### Removed

- The macOS Intel (`osx`/`x86_64`) toolchain is no longer supported, as Popili dropped Intel macOS with
  1.5.0.

### Fixed

- `local_user` now uses the license of the Popili version in use, instead of the first one it found.
- With `local_acquire` and a remote execution platform registered, the license could be acquired
  with a licensing server that can't run on the host.
- `local_user` now finds the license in the correct directory (`XDG_DATA_HOME` or
  `%LOCALAPPDATA%`), and respects the `POPILI_DATA` override.
- Wrapping a `coco_package` in `with_popili_version` had no effect on the Popili used to verify or
  generate code from it.
- `coco_repositories(versions = [...])` was accepted but silently ignored in WORKSPACE mode, so a
  workspace following the README's "Popili Version" section got `stable` instead of the versions it
  asked for. It is now honoured — check that your default version has not moved.
- When cross-compiling with `--platforms`, the generated `.bat`/`.sh` scripts followed the target
  platform instead of the platform they run on.
- `coco_generate`, the C/C++ library macros and `coco_fmt_test` now work with `tags = ["manual"]` and `testonly`.

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
