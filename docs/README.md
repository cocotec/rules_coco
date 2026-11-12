# rules_coco documentation

## Guides

- [Getting started](getting-started.md): a first package, from install to verified, generated and built C++.
- [Setup](setup.md): bzlmod and `WORKSPACE` installation.
- [Licensing](licensing.md): license modes for local builds, CI and remote execution.
- [Defining packages](packages.md): `coco_package`, dependencies, typechecking, where generated code goes.
- [Generating code](code-generation.md): C++, C and C# generation, mirroring `Coco.toml` output settings.
- [Verification](verification.md): `coco_verify_test` and the verification backend.
- [Formatting and diagrams](formatting-and-diagrams.md): `coco_fmt_test`, architecture, state and counterexample
  diagrams.
- [Popili versions](popili-versions.md): registering several versions, pinning targets, version flags.
- [Custom toolchains](toolchains.md): a local popili distribution, or a toolchain of your own.
- [Older C++ compilers](old-compilers.md): supplying Boost for GCC 4.x.
- [Using Renovate](renovate.md): automatic rules_coco updates, also behind a firewall.

## Reference

The [API reference](reference/README.md) is generated from the `.bzl` sources with Stardoc and lists every rule,
macro and attribute.
