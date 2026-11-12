# Verification

`coco_verify_test` creates a test target that runs verification on a package when `bazel test` is executed.

```starlark
load("@rules_coco//coco:defs.bzl", "coco_verify_test")

coco_verify_test(
    name = "my_package_test",
    package = ":my_package",
)
```

## Verification backend

The verification backend can be selected using the `--@rules_coco//:verification_backend` option:

- `local`: Local verification (default). Runs on the build executor.
- `remote`: Remote verification: uses the configured remote verification service.
- `attempt-remote`: Attempt remote, fallback to local if it's not available.

For example:

```bash
bazel build --@rules_coco//:verification_backend=remote //...
```
