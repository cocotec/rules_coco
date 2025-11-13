#!/usr/bin/env python3
"""Run the CI test matrix locally, including e2e tests."""

import os
import subprocess
import sys


def run_test(bazel_version, build_system):
    """Run tests for a specific Bazel version and build system."""
    print(f"\n{'=' * 70}")
    print(f"Testing root workspace: Bazel {bazel_version} with {build_system} mode")
    print('=' * 70)

    env = os.environ.copy()
    env['USE_BAZEL_VERSION'] = bazel_version

    cmd = ['bazel', 'test', f'--config={build_system}', '//...']

    result = subprocess.run(cmd, env=env)

    if result.returncode != 0:
        print(f"\n✗ FAILED: Root workspace with Bazel {bazel_version} and {build_system}")
        return False

    print(f"\n✓ PASSED: Root workspace with Bazel {bazel_version} and {build_system}")
    return True


def run_e2e_test(directory, bazel_version, build_system):
    """Run e2e tests in a specific directory."""
    print(f"\n{'=' * 70}")
    print(f"Testing {directory}: Bazel {bazel_version} with {build_system} mode")
    print('=' * 70)

    env = os.environ.copy()
    env['USE_BAZEL_VERSION'] = bazel_version

    cmd = ['bazel', 'test', f'--config={build_system}', '//...']

    result = subprocess.run(cmd, cwd=directory, env=env)

    if result.returncode != 0:
        print(f"\n✗ FAILED: {directory} with Bazel {bazel_version} and {build_system}")
        return False

    print(f"\n✓ PASSED: {directory} with Bazel {bazel_version} and {build_system}")
    return True


def main():
    """Run all test configurations."""
    configs = [
        ('8.4.2', 'workspace'),
        ('8.4.2', 'bzlmod'),
        ('9.0.0rc2', 'bzlmod'),
    ]

    passed = 0
    failed = 0

    for version, mode in configs:
        # Run root workspace tests
        if not run_test(version, mode):
            failed += 1
            print(f"\nStopping due to failure.")
            break

        # Run e2e/smoke tests
        if not run_e2e_test('e2e/smoke', version, mode):
            failed += 1
            print(f"\nStopping due to failure.")
            break

        # Run e2e/multi_version tests
        if not run_e2e_test('e2e/multi_version', version, mode):
            failed += 1
            print(f"\nStopping due to failure.")
            break

        passed += 1

    print(f"\n{'=' * 70}")
    print(f"Summary: {passed} configurations passed, {failed} failed")
    print('=' * 70)

    sys.exit(0 if failed == 0 else 1)


if __name__ == '__main__':
    main()
