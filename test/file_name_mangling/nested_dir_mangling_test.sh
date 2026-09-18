#!/usr/bin/env bash
# Checks that rules_coco predicts the *mangled* directory component for a source
# in a subdirectory, the way popili writes it.
#
# macOS and Windows have case-insensitive filesystems, so a wrongly-cased
# declared output still resolves there and the generate action appears to
# succeed. Both checks below are case-sensitive on every platform.

set -uo pipefail

readonly SRC_DIR="test/file_name_mangling/src"
status=0

fail() {
  echo "FAIL: $*" >&2
  status=1
}

# 1. `ls` reports directory entries as they are stored, so this distinguishes
#    `geometry` from `Geometry` even on a case-insensitive filesystem.
entries="$(ls "${SRC_DIR}" 2>/dev/null)"
if ! grep -qx "geometry" <<<"${entries}"; then
  fail "expected mangled directory '${SRC_DIR}/geometry'; found: $(tr '\n' ' ' <<<"${entries}")"
fi
if grep -qx "Geometry" <<<"${entries}"; then
  fail "found unmangled directory '${SRC_DIR}/Geometry'; the mangler must be applied to directory components too"
fi

# 2. Check popili mangling via its generated `#include` statements
impl="$(find "${SRC_DIR}" -name "dims.cc" -print -quit 2>/dev/null)"
if [[ -z "${impl}" ]]; then
  fail "could not find the generated dims.cc under ${SRC_DIR}"
else
  expected="#include \"${SRC_DIR}/geometry/dims.h\""
  if ! grep -qF "${expected}" "${impl}"; then
    fail "expected ${impl} to contain ${expected}; got: $(grep -m1 'dims.h' "${impl}")"
  fi
fi

exit "${status}"
