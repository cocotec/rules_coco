# Multi-Version Example

This example demonstrates how to use multiple versions of the Coco/Popili toolchain in the same build.

## Usage

1. **Register multiple versions** in your `MODULE.bazel`:

   ```python
   coco.toolchain(
       versions = ["1.5.0", "1.4.7"],
       cc = True,
   )
   ```

2. **Wrap targets with specific versions** using `with_popili_version()`:

   ```python
   coco_package(
       name = "modern_package",
       srcs = [...],
       package = "Coco.toml",
   )

   with_popili_version(
       name = "modern_v150",
       target = ":modern_package",
       version = "1.5.0",
   )
   ```

3. **Build targets** - each uses its specified version:
   ```bash
   bazel build //:modern_v150
   ```

See the working example in `e2e/multi_version/BUILD.bazel` for a complete demonstration.
