# rules_coco API Documentation

This directory contains auto-generated API documentation for rules_coco, created using [Stardoc](https://github.com/bazelbuild/stardoc).

## Available Documentation

All API documentation is auto-generated from the source .bzl files:

- [defs.md](defs.md) - Main public API (coco_package, coco_package_generate, coco_package_verify_test, etc.)
- [cc.md](cc.md) - C++ integration rules (coco_cc_library, coco_cc_test_library, etc.)
- [repositories.md](repositories.md) - Repository setup rules (coco_repositories, etc.)

## Regenerating Documentation

To regenerate the documentation after making changes to `.bzl` files:

```bash
# Generate all documentation
bazel build //docs:docs

# Copy generated files back to source
cp -f bazel-bin/docs/*.md docs/
```

## CI Checks

The CI pipeline checks that documentation is up-to-date. If you modify any `.bzl` files that have stardoc documentation, make sure to regenerate and commit the updated documentation.
