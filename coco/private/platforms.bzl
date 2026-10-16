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

def host_platform(os_name, os_arch):
    """Returns the platform Bazel runs on, spelled like `COCO_TOOLCHAIN_PLATFORMS`.

    Not limited to the platforms popili is published for: a local toolchain on, say, an
    Intel Mac yields ("osx", "x86_64").

    Args:
      os_name: `repository_ctx.os.name`, e.g. "mac os x", "linux" or "windows 11".
      os_arch: `repository_ctx.os.arch`, e.g. "aarch64", "arm64", "amd64" or "x86_64".

    Returns:
      An (os, arch) pair naming `@platforms//os:<os>` and `@platforms//cpu:<arch>`.
    """
    os_name = os_name.lower()
    if os_name.startswith("windows"):
        os = "windows"
    elif os_name.startswith("mac") or os_name == "darwin":
        os = "osx"
    else:
        os = os_name.split(" ")[0]

    os_arch = os_arch.lower()
    arch = {
        "amd64": "x86_64",
        "arm64": "aarch64",
        "i386": "x86_32",
        "i686": "x86_32",
        "x86": "x86_32",
    }.get(os_arch, os_arch)

    return (os, arch)

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
