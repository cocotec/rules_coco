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
- `coco_package` attributes `source_roots` and `test_source_roots`, mirroring `package.sources` and
  `package.testSources` in `Coco.toml`. They are inferred from `srcs`/`test_srcs` when omitted; set them when a
  package has several source roots or all sources sit in a subdirectory of the root.
- `coco_cc_library`, `coco_c_library` and their test-library variants accept `library_rule`, the rule or macro
  that compiles the library, for projects that wrap `cc_library` in a macro of their own. The default is
  rules_cc's `cc_library`.
- `coco_generate` attribute `include_prefix`, mirroring `generator.cpp.includePrefix` / `generator.c.includePrefix`
  in `Coco.toml` like the other generator settings. Set it to the package's effective value, including one inherited
  from a workspace or received through `exportConfig`; the default `""` is popili's default too. Not allowed for C#.
- `coco_toolchain` gained an optional `popili_version` attribute, exposed as the `popili_version` field of the
  toolchain. The toolchains rules_coco generates set it to their Popili version (`local` for a
  local distribution); a bring-your-own toolchain may leave it empty when the version is unknown.
- `coco_toolchain`, `coco.local_toolchain` and `coco_local_repositories` gained an optional
  `license_protocol_version`: the licence protocol version the toolchain's Popili reads, which picks
  its licence file under `local_user`. Set it when that differs from the newest protocol version
  rules_coco knows of.

### Changed

- **Breaking:** rules_coco's default toolchain (`stable` with the C and C++ runtimes) is now used
  only when no module declares `coco.toolchain`. If yours declares one, you get only what it lists,
  so add `c = True` / `cc = True` for the runtimes you use. Modules that don't declare
  `coco.toolchain` are unaffected and still get `stable` with both runtimes.
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
- **Breaking:** `coco_repositories` and `coco_local_repositories` take explicit named parameters
  instead of `**kwargs`, so an unrecognised argument is now an error rather than being silently
  ignored. Arguments that were previously only accepted by keyword remain keyword-only, so only
  `version` (and `path`, `cc_runtime_path` and `c_runtime_path` for `coco_local_repositories`)
  may be passed positionally.
- `coco_repositories` now fails with a clear message if called more than once, instead of producing
  duplicate-repository warnings and a silently wrong configuration.
- `"local"` and `"default"` are rejected as version strings; they name the hub's own
  `config_setting`s.
- The generated `toolchain()` declarations no longer set `target_compatible_with`. Popili runs on
  the exec platform and the runtime it provides is source, so the toolchain now resolves for any
  target platform, including when cross-compiling with `--platforms`. Before, bzlmod required the
  target platform to match the host; WORKSPACE mode never had the constraint.
- **Breaking:** `coco_generate` now writes all generated code, test code and mocks included, below a directory of
  its own, `bazel-bin/<package>/_coco/<name>/`, and generated headers are included the way popili's own generated
  code includes them: by module path below the source root, behind the package's `includePrefix` if it has one.
  `pkg/src/Foo.coco` is included as `#include "Foo.h"` rather than `#include "pkg/src/Foo.h"`, wherever the package
  lives, and as `#include "motor/Foo.h"` if its `Coco.toml` sets `includePrefix = "motor"`. rules_coco no longer
  passes `--include-prefix` to popili. To migrate:

  - in hand-written code, include generated headers as `"Foo.h"` instead of `"pkg/src/Foo.h"`, or as
    `"<includePrefix>/Foo.h"` when the package's `Coco.toml` sets one. To keep `#include "pkg/src/Foo.h"`, set
    `include_prefix` and `includePrefix` to `"pkg/src"`;
  - set `include_prefix` on every `coco_generate` whose package has a non-empty effective `includePrefix`;
  - remove `includes` entries that only made generated headers reachable. `includes` no longer applies below the
    generated files' include root, so a nested one such as `includes = ["pkg/sub"]` becomes part of the include,
    `#include "sub/Bar.h"`;
  - drop the package directory from `public_hdrs` path suffixes (`"src/IApi.h"` becomes `"IApi.h"` or
    `"sub/IApi.h"`). A suffix with a directory now matches whole path components of the header's include path, so
    `"api/IApi.h"` no longer selects `xapi/IApi.h`;
  - replace a plain `cc_library` compiling a `coco_generate`'s sources by `coco_cc_library` or `coco_c_library`,
    passing a wrapper of `cc_library` as `library_rule` if you use one;
  - update paths to generated C# files, now `bazel-bin/<package>/_coco/<name>/<module path>.cs`;
  - on Windows, run `bazel clean` once, so that files left at the old paths cannot be included by mistake.

  Two `coco_generate` targets over one `coco_package` no longer conflict, and generated paths are shorter, which
  helps against Windows path length limits.

### Removed

- The macOS Intel (`osx`/`x86_64`) toolchain is no longer supported, as Popili dropped Intel macOS with
  1.5.0.

### Fixed

- `local_user` licensing passes each popili version the licence file it reads, instead of the first
  one found, which popili 1.6 rejects.
- `coco_cc_library` and `coco_c_library` no longer fail to find generated headers when their
  `coco_generate` is built with a different Popili version, for example through `with_popili_version`,
  nor pick up a copy of them built at another version (an undeclared inclusion, on Windows).
- `local_user` now finds the license in the correct directory (`XDG_DATA_HOME` or
  `%LOCALAPPDATA%`), and respects the `POPILI_DATA` override.
- The local toolchain (`coco.local_toolchain` in bzlmod, `coco_local_repositories` in WORKSPACE) is
  now constrained to the host's OS and CPU.
- `coco_repositories(versions = [...])` was accepted but silently ignored in WORKSPACE mode, so a
  workspace following the README's "Popili Version" section got `stable` instead of the versions it
  asked for. It is now honoured — check that your default version has not moved.
- The `.bat`/`.sh` wrapper and typecheck scripts followed the target platform instead of the exec
  platform the popili binary was resolved for. Cross-compiling with `--platforms` for Windows from
  a Linux or macOS host emitted a `.bat` for a POSIX executor, and vice versa. The flavour is now
  derived from the resolved toolchain's binary: `popili.exe` means Windows.
- `coco_generate`, the C/C++ library macros and `coco_fmt_test` now work with `tags = ["manual"]` and `testonly`.
- `coco_generate` with `language = "c"` and `mocks = True` now fails with a clear error, since C mocks are not
  supported.
- `coco_generate` no longer derives the source root from the shortest source path, which depended on file order and
  failed for a source file next to `Coco.toml` with others in subdirectories, for sibling subdirectories, and for
  several source roots.
- Generated test code and mocks of a package with `test_srcs` are written next to the regular generated code, so
  their `#include`s resolve and mocks are declared where popili writes them.
- The `.coco` files in `test_srcs` are now inputs of the popili actions, so a package with `testSources` no longer
  fails with `could not open the directory ...` under Bazel's sandbox.
- `coco_verify_test` and `coco_fmt_test` resolved popili for the default execution platform while Bazel ran
  the test on its `test` execution group, so with several execution platforms the test could run on a platform
  the popili in its wrapper script was not built for. The toolchain is now resolved on the `test` execution
  group, and the test runs where that popili runs. On Bazel 9 and later that is an execution platform matching
  the target platform, as Bazel places tests by default; Bazel 8 lacks the default test toolchain type this
  relies on, so there the test runs on the first execution platform that has a popili.
- Popili releases newer than your rules_coco can now be used with the C and C++ rules. Their
  downloads are not checksum-verified.

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
