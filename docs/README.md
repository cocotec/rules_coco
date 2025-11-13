# rules_coco API Documentation

This directory contains auto-generated API documentation for rules_coco, created using [Stardoc](https://github.com/bazelbuild/stardoc).

## Available Documentation

All API documentation is auto-generated from the source .bzl files:

- [defs.md](defs.md) - Main public API (coco_package, coco_generate, coco_verify_test, etc.)
- [c.md](c.md) - C integration rules (coco_c_library, coco_c_test_library, etc.)
- [cc.md](cc.md) - C++ integration rules (coco_cc_library, coco_cc_test_library, etc.)
- [repositories.md](repositories.md) - Repository setup rules (coco_repositories, etc.)

## Regenerating Documentation

To regenerate the documentation after making changes to `.bzl` files:

```bash
# Generate and copy documentation
./tools/update_docs.sh
```

## CI Checks

The CI pipeline checks that documentation is up-to-date. If you modify any `.bzl` files that have stardoc documentation, make sure to regenerate and commit the updated documentation.
