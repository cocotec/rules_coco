#!/usr/bin/env python3
"""Stage ./rules_coco_unaware for the forward_compat e2e (see MODULE.bazel).

Fails if MODULE.bazel, WORKSPACE and .bazelrc disagree on the versions, or if the source
tree does not know the newest one, since the strip would then be a no-op.
"""

import os
import re
import shutil
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.normpath(os.path.join(_HERE, "..", ".."))
_DEST = os.path.join(_HERE, "rules_coco_unaware")
_KNOWN_SHAS = os.path.join("coco", "private", "known_shas.bzl")


def _read(name):
    with open(os.path.join(_HERE, name)) as f:
        return f.read()


def _registered_versions(name):
    match = re.search(r"versions = \[(.*?)\]", _read(name), re.S)
    if not match:
        sys.exit(f"{name}: no `versions = [...]` found.")
    return re.findall(r'"([^"]+)"', match.group(1))


def _selected_version():
    match = re.search(r"^common --@rules_coco//:version=(\S+)$", _read(".bazelrc"), re.M)
    if not match:
        sys.exit(".bazelrc: no `common --@rules_coco//:version=...` line found.")
    return match.group(1)


def _strip_version(known_shas, version):
    lines = known_shas.splitlines(keepends=True)
    kept = [line for line in lines if not line.lstrip().startswith(f'"{version}/')]
    if len(kept) == len(lines):
        sys.exit(f"{_KNOWN_SHAS} has no entries for {version}; nothing to strip.")
    return "".join(kept)


def main():
    versions = _registered_versions("MODULE.bazel")
    if versions != _registered_versions("WORKSPACE"):
        sys.exit("MODULE.bazel and WORKSPACE register different versions.")
    newest = versions[-1]
    if _selected_version() != newest:
        sys.exit(f".bazelrc must select {newest}, the last version registered in MODULE.bazel.")

    with open(os.path.join(_ROOT, _KNOWN_SHAS)) as f:
        stripped = _strip_version(f.read(), newest)

    shutil.rmtree(_DEST, ignore_errors=True)
    shutil.copytree(_ROOT, _DEST, ignore=shutil.ignore_patterns(".git", "bazel-*", "e2e"))
    with open(os.path.join(_DEST, _KNOWN_SHAS), "w") as f:
        f.write(stripped)
    print(f"Staged rules_coco without {newest} checksums into {_DEST}")


if __name__ == "__main__":
    main()
