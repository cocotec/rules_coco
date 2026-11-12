# Verification

`coco_verify_test` creates a test target that runs
[verification](https://cocotec.io/popili/doc/stable/language/verification.html#verification) on a package when
`bazel test` is executed.

```starlark
load("@rules_coco//coco:defs.bzl", "coco_verify_test")

coco_verify_test(
    name = "my_package_test",
    package = ":my_package",
)
```

## Verification backend

`--@rules_coco//:verification_backend` sets Popili's
[`--backend`](https://cocotec.io/popili/doc/stable/tools/cli.html#cmdoption-coco-backend):

- `local`: verify inside the test action.
- `remote`: send verification to the remote verification service.
- `attempt-remote`: try the remote service, and fall back to local verification if it is unavailable.

When the flag is unset, rules_coco passes no backend and Popili's own default applies.

```bash
bazel test --@rules_coco//:verification_backend=remote //...
```
