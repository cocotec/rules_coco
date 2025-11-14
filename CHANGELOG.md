# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
