#!/usr/bin/env bash
# Checks the include strings popili writes when rules_coco passes no --include-prefix: a package's own
# generated code includes its headers below the includePrefix from its Coco.toml ("core" for base), and a
# dependant's generated code includes the dependency's headers below the dependency's prefix, and its
# own below its own (none for app).

set -uo pipefail

readonly BASE_DIR="test/cpp_include_prefix_deps/_coco/base_cpp/core"
readonly APP_DIR="test/cpp_include_prefix_deps/_coco/app_cpp"
status=0

fail() {
  echo "FAIL: $*" >&2
  status=1
}

# expect_include <file> <include path>: the file has #include "<include path>".
expect_include() {
  if [[ ! -f "$1" ]]; then
    fail "missing generated file $1"
  elif ! grep -qF "#include \"$2\"" "$1"; then
    fail "expected $1 to contain #include \"$2\"; its includes: $(grep -F '#include' "$1" | tr '\n' ' ')"
  fi
}

# reject_include <file> <include path>: the file has no #include "<include path>".
reject_include() {
  if [[ -f "$1" ]] && grep -qF "#include \"$2\"" "$1"; then
    fail "expected $1 not to contain #include \"$2\""
  fi
}

# base's own code, written to <root>/core, includes its headers as "core/...".
expect_include "${BASE_DIR}/BaseComp.cc" "core/BaseComp.h"
expect_include "${BASE_DIR}/BaseComp.h" "core/IBase.h"
expect_include "${BASE_DIR}/IBaseMock.h" "core/IBase.h"

# app's code includes base by base's prefix and its own headers by bare module path.
expect_include "${APP_DIR}/IApp.h" "core/IBase.h"
reject_include "${APP_DIR}/IApp.h" "IBase.h"

exit "${status}"
