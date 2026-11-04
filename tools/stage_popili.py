#!/usr/bin/env python3
"""Shared helper for the e2e stage.py hooks to fake a local popili toolchain.

Downloads the archives for the version rules_coco pins as `stable` and lays the
binaries (and optionally the C++ runtime) on disk, preserving executable bits.
Restages when `stable` has moved on since the last run.
"""

import argparse
import os
import platform
import shutil
import sys
import urllib.request
import zipfile

_HERE = os.path.dirname(os.path.abspath(__file__))
_VERSION_ALIASES_BZL = os.path.join(_HERE, "..", "coco", "private", "version_aliases.bzl")
_LICENSE_VERSIONS_BZL = os.path.join(_HERE, "..", "coco", "private", "license_versions.bzl")

# Records the staged version in the binary dir, so a rerun can tell whether it is stale.
_VERSION_FILE = ".version"


def _load_bzl(path):
    """Evaluates a data-only .bzl file (no load statements) and returns its globals."""
    namespace = {}
    exec(open(path).read(), namespace)
    return namespace


def stable_version():
    return _load_bzl(_VERSION_ALIASES_BZL)["VERSION_ALIASES"]["stable"]


def _version_key(version):
    """Mirrors version_key() in coco/private/version_resolution.bzl."""
    release, separator, pre_release = version.partition("-")
    release = tuple(int(part) for part in release.split("."))
    if not separator:
        return (release, (1,))
    identifiers = [(0, int(part)) if part.isdigit() else (1, part) for part in pre_release.split(".")]
    return (release, (0,) + tuple(identifiers))


def license_protocol_version(version):
    """Mirrors license_protocol_version() in coco/private/version_resolution.bzl."""
    table = _load_bzl(_LICENSE_VERSIONS_BZL)["LICENSE_PROTOCOL_VERSIONS"]
    protocol = next(iter(table.values()))
    for earliest, entry in table.items():
        if _version_key(earliest) > _version_key(version):
            break
        protocol = entry
    return protocol


def _os_token(system):
    return {"Darwin": "darwin", "Linux": "linux", "Windows": "windows"}.get(system)


def _arch_token(machine):
    machine = machine.lower()
    if machine in ("arm64", "aarch64"):
        return "arm64"
    if machine in ("x86_64", "amd64"):
        return "amd64"
    return None


def popili_archive():
    """Returns the popili binary archive name for the host platform."""
    os_token = _os_token(platform.system())
    arch_token = _arch_token(platform.machine())
    if not os_token or not arch_token:
        sys.exit(f"Unsupported host platform: {platform.system()}/{platform.machine()}.")
    return f"popili_{os_token}_{arch_token}.zip"


def _download_and_extract(base_url, archive, dest, tmp_dir):
    """Downloads base_url/archive and extracts it into dest, preserving modes."""
    url = f"{base_url}/{archive}"
    tmp = os.path.join(tmp_dir, archive)
    print(f"Downloading {url}")
    urllib.request.urlretrieve(url, tmp)

    os.makedirs(dest, exist_ok=True)
    with zipfile.ZipFile(tmp) as zf:
        for info in zf.infolist():
            extracted = zf.extract(info, dest)
            mode = info.external_attr >> 16
            if mode:
                os.chmod(extracted, mode)
    os.remove(tmp)


def stage(dest_dir, binary_subdir="popili", with_cpp_runtime=False, force=False):
    """Stages popili binaries under dest_dir/<binary_subdir> (+ cpp-runtime if asked).

    Returns the staged popili version.
    """
    version = stable_version()
    binary_dir = os.path.join(dest_dir, binary_subdir)
    version_file = os.path.join(binary_dir, _VERSION_FILE)
    if os.path.isfile(version_file) and open(version_file).read() == version and not force:
        print(f"popili {version} already staged in {binary_dir}; skipping (pass force=True to refresh).")
        return version

    # Never remove dest_dir itself.
    shutil.rmtree(binary_dir, ignore_errors=True)
    runtime_dir = os.path.join(dest_dir, "cpp-runtime")
    if with_cpp_runtime:
        shutil.rmtree(runtime_dir, ignore_errors=True)
    os.makedirs(dest_dir, exist_ok=True)

    base_url = f"https://dl.cocotec.io/popili/archive/{version}"
    _download_and_extract(base_url, popili_archive(), binary_dir, dest_dir)
    if with_cpp_runtime:
        _download_and_extract(base_url, "coco-cpp-runtime.zip", runtime_dir, dest_dir)
    with open(version_file, "w") as f:
        f.write(version)

    print(f"Staged popili {version} into {dest_dir}")
    return version


def main(dest_dir, binary_subdir="popili", with_cpp_runtime=False):
    """CLI entrypoint for the e2e stage.py shims; adds a --force flag. Returns the staged version."""
    parser = argparse.ArgumentParser(description="Stage a popili toolchain for an e2e test.")
    parser.add_argument("--force", action="store_true", help="Re-download even if already staged.")
    return stage(dest_dir, binary_subdir=binary_subdir, with_cpp_runtime=with_cpp_runtime, force=parser.parse_args().force)
