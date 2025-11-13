#!/bin/bash
set -e

echo "Setting up rules_coco development environment..."

# Install Bazelisk (manages Bazel versions)
echo "Installing Bazelisk..."

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
  x86_64)
    BAZELISK_ARCH="amd64"
    ;;
  aarch64|arm64)
    BAZELISK_ARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo "Detected architecture: $ARCH (using bazelisk-linux-$BAZELISK_ARCH)"
sudo wget -O /usr/local/bin/bazel https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-$BAZELISK_ARCH
sudo chmod +x /usr/local/bin/bazel

# Install pre-commit
echo "Installing pre-commit..."
pip install --user pre-commit

# Install pre-commit hooks
echo "Setting up pre-commit hooks..."
pre-commit install

# Verify installation
echo "Verifying installation..."
bazel version
pre-commit --version

echo "Development environment setup complete!"
echo ""
echo "Try running:"
echo "  bazel test //..."
echo "  pre-commit run --all-files"
