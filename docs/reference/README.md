# rules_coco API reference

Generated from the `.bzl` sources with [Stardoc](https://github.com/bazelbuild/stardoc). Do not edit these files by
hand: change the docstrings and run `./tools/update_docs.sh` (see [CONTRIBUTING.md](../../CONTRIBUTING.md#documentation)).

- [defs.md](defs.md): core rules and macros (`coco_package`, `coco_generate`, `coco_verify_test`, `coco_fmt_test`,
  `coco_workspace`, the diagram rules and `counterexample_options`) and the providers (`CocoPackageInfo`,
  `CocoWorkspaceInfo`, `CocoCcGeneratedInfo`, `CocoCSharpGeneratedInfo`).
- [cc.md](cc.md): C++ integration (`coco_cc_library`, `coco_cc_test_library`).
- [c.md](c.md): C integration (`coco_c_library`, `coco_c_test_library`).
- [extensions.md](extensions.md): the `coco` module extension (bzlmod setup).
- [repositories.md](repositories.md): repository rules (`WORKSPACE` setup).
- [toolchain.md](toolchain.md): `coco_toolchain`, for bringing your own popili.

The flags are listed in [Build flags](../flags.md).

For explanations and examples, see the [guides](../README.md).
