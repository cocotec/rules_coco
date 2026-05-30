#!/usr/bin/env python3
"""Stage popili into ./popili_dist/bin for the byo_toolchain e2e. See tools/stage_popili.py."""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, "..", "..", "tools"))
import stage_popili  # noqa: E402

stage_popili.main(os.path.join(_HERE, "popili_dist"), binary_subdir="bin")
