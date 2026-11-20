# Copyright 2019 Cocotec Limited
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""The platforms popili is published for.

This file deliberately loads nothing, so both the repository layer and the rule layer can
agree on the platform list without one loading the other.
"""

# Every (os, arch) pair a published popili release is available for, in the vocabulary of
# `@platforms//os` and `@platforms//cpu`.
COCO_TOOLCHAIN_PLATFORMS = [
    ("osx", "aarch64"),
    ("linux", "aarch64"),
    ("linux", "x86_64"),
    ("windows", "x86_64"),
]

def platform_constraints(os, arch):
    """Returns the platform constraints for a Coco toolchain platform.

    Args:
      os: The toolchain OS ("osx", "linux" or "windows").
      arch: The toolchain CPU ("aarch64" or "x86_64").

    Returns:
      A list of constraint value label strings.
    """
    return [
        "@platforms//os:%s" % os,
        "@platforms//cpu:%s" % arch,
    ]

def archive_platform(os, arch):
    """Returns how popili's release archives spell a toolchain platform.

    Args:
      os: The toolchain OS ("osx", "linux" or "windows").
      arch: The toolchain CPU ("aarch64" or "x86_64").

    Returns:
      An (os, arch) pair as it appears in archive names, e.g. ("darwin", "arm64").
    """
    return (
        {"osx": "darwin"}.get(os, os),
        {"aarch64": "arm64", "x86_64": "amd64"}.get(arch, arch),
    )

def platform_binary_ext(os):
    """Returns the file extension of executables on a toolchain OS.

    Args:
      os: The toolchain OS ("osx", "linux" or "windows").

    Returns:
      ".exe" on Windows, "" elsewhere.
    """
    if os == "windows":
        return ".exe"
    return ""

# Repository rules only: they can't see constraints, and common_repositories.bzl can't load
# HOST_CONSTRAINTS in WORKSPACE mode. Elsewhere, use host.bzl's host_popili_platform.
def repository_host_os(os_name):
    """Returns the OS of COCO_TOOLCHAIN_PLATFORMS a repository rule's host runs.

    Args:
      os_name: The host's `repository_ctx.os.name`, e.g. "mac os x", "linux" or "windows 11".

    Returns:
      "osx", "windows" or "linux", or None for another OS.
    """
    os_name = os_name.lower()
    if "mac" in os_name or "darwin" in os_name:
        return "osx"
    if "windows" in os_name:
        return "windows"
    if "linux" in os_name:
        return "linux"
    return None

def repository_host_platform(os_name, os_arch):
    """Returns which of COCO_TOOLCHAIN_PLATFORMS a repository rule's host is.

    Args:
      os_name: The host's `repository_ctx.os.name`, e.g. "mac os x", "linux" or "windows 11".
      os_arch: The host's `repository_ctx.os.arch`, e.g. "aarch64", "amd64" or "x86_64".

    Returns:
      An (os, arch) pair of COCO_TOOLCHAIN_PLATFORMS, or None when popili is not published for
      the host.
    """
    os = repository_host_os(os_name)
    arch = {"aarch64": "aarch64", "amd64": "x86_64", "arm64": "aarch64", "x86_64": "x86_64"}.get(os_arch.lower())
    if (os, arch) not in COCO_TOOLCHAIN_PLATFORMS:
        return None
    return (os, arch)
