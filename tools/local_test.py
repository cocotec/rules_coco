#!/usr/bin/env python3
"""Run the CI test matrix locally, including e2e tests."""

import os
import subprocess
import sys


def run_bazel_test(name, bazel_version, build_system, cwd=None):
    """Run bazel test for a given configuration."""
    print(f"\n{'=' * 70}")
    print(f"Testing {name}: Bazel {bazel_version} with {build_system} mode")
    print('=' * 70)

    env = os.environ.copy()
    env['USE_BAZEL_VERSION'] = bazel_version
    cmd = ['bazel', 'test', f'--config={build_system}', '//...']

    result = subprocess.run(cmd, env=env, cwd=cwd)
    status = "✓ PASSED" if result.returncode == 0 else "✗ FAILED"
    print(f"\n{status}: {name} with Bazel {bazel_version} and {build_system}")

    return result.returncode == 0


def discover_e2e_dirs():
    """Discover all e2e test directories."""
    if not os.path.isdir('e2e'):
        return []
    return sorted([
        os.path.join('e2e', d)
        for d in os.listdir('e2e')
        if os.path.isdir(os.path.join('e2e', d))
    ])


def main():
    """Run all test configurations."""
    configs = [
        ('8.4.2', 'workspace'),
        ('8.4.2', 'bzlmod'),
        ('9.0.0rc2', 'bzlmod'),
    ]

    e2e_dirs = discover_e2e_dirs()
    passed = 0

    for version, mode in configs:
        # Run root workspace and all e2e tests
        test_dirs = [('root workspace', None)] + [(d, d) for d in e2e_dirs]

        if all(run_bazel_test(name, version, mode, cwd) for name, cwd in test_dirs):
            passed += 1
        else:
            print("\nStopping due to failure.")
            break

    failed = len(configs) - passed
    print(f"\n{'=' * 70}")
    print(f"Summary: {passed} configurations passed, {failed} failed")
    print('=' * 70)

    sys.exit(0 if failed == 0 else 1)


if __name__ == '__main__':
    main()
