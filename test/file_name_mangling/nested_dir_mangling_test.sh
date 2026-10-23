#!/usr/bin/env bash
# Checks that rules_coco predicts the *mangled* directory component for a source
# in a subdirectory, the way popili writes it.
#
# macOS and Windows have case-insensitive filesystems, so a wrongly-cased
# declared output still resolves there and the generate action appears to
# succeed. Both checks below are case-sensitive on every platform.

set -uo pipefail

# Generated includes are relative to the generate's include root, where the files sit (no includePrefix).
readonly GEN_DIR="test/file_name_mangling/_coco/file_name_mangling_test_cpp"
status=0

fail() {
  echo "FAIL: $*" >&2
  status=1
}

# 1. `ls` reports directory entries as they are stored, so this distinguishes
#    `geometry` from `Geometry` even on a case-insensitive filesystem.
entries="$(ls "${GEN_DIR}" 2>/dev/null)"
if ! grep -qx "geometry" <<<"${entries}"; then
  fail "expected mangled directory '${GEN_DIR}/geometry'; found: $(tr '\n' ' ' <<<"${entries}")"
fi
if grep -qx "Geometry" <<<"${entries}"; then
  fail "found unmangled directory '${GEN_DIR}/Geometry'; the mangler must be applied to directory components too"
fi

# 2. Check popili mangling via its generated `#include` statements
impl="$(find "${GEN_DIR}" -name "dims.cc" -print -quit 2>/dev/null)"
if [[ -z "${impl}" ]]; then
  fail "could not find the generated dims.cc under ${GEN_DIR}"
else
  expected='#include "geometry/dims.h"'
  if ! grep -qF "${expected}" "${impl}"; then
    fail "expected ${impl} to contain ${expected}; got: $(grep -m1 'dims.h' "${impl}")"
  fi
fi

exit "${status}"
