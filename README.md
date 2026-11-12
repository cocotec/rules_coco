# rules_coco

[![CI](https://github.com/cocotec/rules_coco/actions/workflows/continuous-integration.yml/badge.svg?branch=main)](https://github.com/cocotec/rules_coco/actions/workflows/continuous-integration.yml?query=branch%3Amain)
[![Links](https://github.com/cocotec/rules_coco/actions/workflows/links.yml/badge.svg)](https://github.com/cocotec/rules_coco/actions/workflows/links.yml)

[Bazel](https://github.com/bazelbuild/bazel) rules for the [Coco language](https://cocotec.io/popili/coco/) that can
use [Popili](https://cocotec.io/popili/) to:

- Generate code from Coco packages.
- Run verification on Coco packages as part of Bazel test.

The rules are fully compatible with remote caching and execution.

## Requirements

- Bazel 8.0.0 or higher. `WORKSPACE` mode needs 8.3.0 or higher.
- Popili 1.5.0 or higher; see its [release notes](https://cocotec.io/popili/doc/stable/release_notes.html) and
  [version numbers](https://cocotec.io/popili/doc/stable/versioning.html#popili-version).
- A valid Coco/Popili licence.

## Documentation

- [Getting started](docs/getting-started.md)
- [Documentation](docs/README.md)
- [API reference](docs/reference/README.md)
- [Changelog](CHANGELOG.md)
- [Contributing](CONTRIBUTING.md)

## Licence

Copyright 2019- Cocotec Limited. Licensed under the Apache License, Version 2.0.
