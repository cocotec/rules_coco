#!/usr/bin/env bash
# Runs popili generate-cpp on a fixture the way coco_generate does, and compares what popili wrote with
# the layout in layouts.bzl.
#
# Usage: popili_layout_test.sh <package dir> <expected layout file> <popili command...>

set -euo pipefail

readonly package_dir="$1"
readonly expected="$2"
shift 2

out="${TEST_TMPDIR}/out"
rm -rf "${out}"

"$@" --package "${package_dir}" generate-cpp \
  --output "${out}/out" \
  --test-output "${out}/test" \
  --include-prefix INC \
  --output-empty-files \
  --output-runtime=false

actual="${TEST_TMPDIR}/actual.txt"
(
  cd "${out}"
  find . -type f | sed 's|^\./||' | while read -r f; do
    echo "${f%%/*} ${f#*/}"
    grep -o '#include "INC/[^"]*"' "${f}" | sed -E 's|#include "INC/(.*)"|include '"${f}"' \1|' || true
  done
) | sort >"${actual}"

if ! diff -u <(sort "${expected}") "${actual}"; then
  echo "FAIL: popili's layout for ${package_dir} differs from layouts.bzl (- expected, + popili)" >&2
  exit 1
fi
