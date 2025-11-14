#!/bin/bash
# Update all generated documentation files

set -e

cd "$(dirname "$0")/.."

echo "Building documentation..."
bazel build //docs:docs

echo "Copying generated documentation to docs/..."
cp -f bazel-bin/docs/*.md docs

echo ""
echo "✓ Documentation updated successfully!"
echo ""
echo "Updated files:"
echo "  - docs/c.md"
echo "  - docs/cc.md"
echo "  - docs/defs.md"
echo "  - docs/repositories.md"
