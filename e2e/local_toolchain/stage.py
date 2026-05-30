#!/usr/bin/env python3
"""Stage popili into ./staged for the local_toolchain e2e. See tools/stage_popili.py."""

import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, "..", "..", "tools"))
import stage_popili  # noqa: E402

stage_popili.main(os.path.join(_HERE, "staged"), binary_subdir="popili", with_cpp_runtime=True)
