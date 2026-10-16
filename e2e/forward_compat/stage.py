#!/usr/bin/env python3
"""Stage ./rules_coco_unaware for the forward_compat e2e (see MODULE.bazel)."""

import os
import shutil

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.normpath(os.path.join(_HERE, "..", ".."))
_DEST = os.path.join(_HERE, "rules_coco_unaware")
_KNOWN_SHAS = os.path.join("coco", "private", "known_shas.bzl")


def main():
    shutil.rmtree(_DEST, ignore_errors=True)
    shutil.copytree(_ROOT, _DEST, ignore=shutil.ignore_patterns(".git", "bazel-*", "e2e"))
    with open(os.path.join(_DEST, _KNOWN_SHAS), "w") as f:
        f.write('"""Emptied by e2e/forward_compat/stage.py."""\n\nFILE_KEY_TO_SHA = {}\n')
    print(f"Staged rules_coco without checksums into {_DEST}")


if __name__ == "__main__":
    main()
