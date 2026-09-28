# Copyright 2026 Cocotec Limited
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""What popili writes for each fixture in this directory. See layout_test.bzl for the format.

Recorded from popili; <name>_popili_test fails if popili stops matching. Lines are
  "<out|test> <path>"          a file popili writes below --output (out) or --test-output (test)
  "include <file> <path>"      <file> contains #include "<--include-prefix>/<path>"
"""

def _unit(kind, directory, name, includes = []):
    """The .h/.cc pair for one module, plus the includes found in them."""
    stem = directory + "/" + name if directory else name
    lines = ["%s %s.h" % (kind, stem), "%s %s.cc" % (kind, stem)]
    for file, included in includes:
        lines.append("include %s/%s %s" % (kind, file, included))
    return lines

LAYOUTS = {
    "beside_manifest": (
        _unit("out", "", "Comp", [("Comp.cc", "Comp.h"), ("Comp.cc", "sub/Runnable.h")]) +
        _unit("out", "sub", "Runnable", [("sub/Runnable.cc", "sub/Runnable.h")])
    ),
    "deep_first": (
        _unit("out", "", "Comp", [("Comp.cc", "Comp.h"), ("Comp.cc", "Api/Runnable.h")]) +
        _unit("out", "Api", "Runnable", [("Api/Runnable.cc", "Api/Runnable.h")])
    ),
    "multi_root": (
        _unit("out", "", "Comp", [("Comp.cc", "Comp.h"), ("Comp.cc", "Runnable.h")]) +
        _unit("out", "", "Runnable", [("Runnable.cc", "Runnable.h")])
    ),
    "nested_only": (
        _unit("out", "a", "Comp", [("a/Comp.cc", "a/Comp.h"), ("a/Comp.cc", "a/Runnable.h")]) +
        _unit("out", "a", "Runnable", [("a/Runnable.cc", "a/Runnable.h")])
    ),
    "single_root": (
        _unit("out", "", "Comp", [("Comp.cc", "Comp.h"), ("Comp.cc", "Runnable.h")]) +
        _unit("out", "", "Runnable", [("Runnable.cc", "Runnable.h")])
    ),
    "test_root": (
        _unit("out", "", "Runnable", [("Runnable.cc", "Runnable.h")]) +
        _unit("test", "", "RunnableMock", [("RunnableMock.cc", "RunnableMock.h"), ("RunnableMock.h", "Runnable.h")]) +
        _unit("test", "", "Stopper", [("Stopper.cc", "Stopper.h"), ("Stopper.cc", "Runnable.h")])
    ),
}
