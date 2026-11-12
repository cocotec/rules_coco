#!/bin/bash
# Update all generated documentation files

set -e

cd "$(dirname "$0")/.."

# The Bazel version CI generates the reference with; newer versions add rows.
export USE_BAZEL_VERSION="${USE_BAZEL_VERSION:-8.4.2}"

echo "Building documentation..."
bazel build //docs:docs

echo "Copying generated documentation to docs/reference/..."
cp -f bazel-bin/docs/reference/*.md docs/reference

echo ""
echo "✓ Documentation updated successfully!"
