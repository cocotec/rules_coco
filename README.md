# rules_coco

[![CI](https://github.com/cocotec/rules_coco/actions/workflows/continuous-integration.yml/badge.svg?branch=main)](https://github.com/cocotec/rules_coco/actions/workflows/continuous-integration.yml?query=branch%3Amain)
[![Links](https://github.com/cocotec/rules_coco/actions/workflows/links.yml/badge.svg)](https://github.com/cocotec/rules_coco/actions/workflows/links.yml)

[Bazel](https://github.com/bazelbuild/bazel) rules for the [Coco language](https://cocotec.io/popili/coco/) that can
use [Popili](https://cocotec.io/popili/) to:

- Generate code from Coco packages.
- Run verification on Coco packages as part of Bazel test.

The rules are fully compatible with remote caching and execution.

## Requirements

- Bazel 8.0.0 or higher (`WORKSPACE` mode: Bazel 8 only).
- Popili 1.5.0 or higher.
- A valid Coco/Popili license.

## Documentation

| Guide                                                      | Covers                                                                |
| ---------------------------------------------------------- | --------------------------------------------------------------------- |
| [Getting started](docs/getting-started.md)                 | A first package: install, verify, generate and build C++              |
| [Setup](docs/setup.md)                                     | bzlmod and `WORKSPACE` installation, staying up to date with Renovate |
| [Licensing](docs/licensing.md)                             | License modes for local builds, CI and remote execution               |
| [Defining packages](docs/packages.md)                      | `coco_package`, dependencies, typechecking, where generated code goes |
| [Generating code](docs/code-generation.md)                 | C++, C and C# generation, mirroring `Coco.toml` output settings       |
| [Verification](docs/verification.md)                       | `coco_verify_test` and the verification backend                       |
| [Formatting and diagrams](docs/formatting-and-diagrams.md) | `coco_fmt_test`, architecture, state and counterexample diagrams      |
| [Popili versions](docs/popili-versions.md)                 | Registering several versions, pinning targets, version flags          |
| [Custom toolchains](docs/toolchains.md)                    | A local popili distribution, or a toolchain of your own               |
| [Older C++ compilers](docs/old-compilers.md)               | Supplying Boost for GCC 4.x                                           |
| [Using Renovate](docs/renovate.md)                         | Automatic rules_coco updates, also behind a firewall                  |

The [API reference](docs/reference/README.md) lists every rule, macro and attribute. Changes between releases are in
the [changelog](CHANGELOG.md), and [CONTRIBUTING.md](CONTRIBUTING.md) explains how to work on rules_coco itself.

## License

Copyright 2019- Cocotec Limited. Licensed under the Apache License, Version 2.0.
