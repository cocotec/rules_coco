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

def platform_key(os, arch):
    """Returns the name of a toolchain platform, as recorded in `coco_toolchain.platform`.

    Args:
      os: The toolchain OS ("osx", "linux" or "windows").
      arch: The toolchain CPU ("aarch64" or "x86_64").

    Returns:
      A string such as "linux_x86_64".
    """
    return "%s_%s" % (os, arch)

# Every platform key, in COCO_TOOLCHAIN_PLATFORMS order: the platforms popili is published for.
EXEC_PLATFORM_KEYS = [platform_key(os, arch) for (os, arch) in COCO_TOOLCHAIN_PLATFORMS]

def host_platform(ctx):
    """Returns the host as a toolchain platform, e.g. ("osx", "aarch64").

    Args:
      ctx: A repository or module context.

    Returns:
      The (os, arch) pair, or None when no popili toolchain is published for the host,
      including hosts popili was once published for, such as Intel Macs.
    """
    name = ctx.os.name.lower()
    if "mac" in name or "os x" in name:
        os = "osx"
    elif "windows" in name:
        os = "windows"
    elif "linux" in name:
        os = "linux"
    else:
        return None
    arch = {
        "aarch64": "aarch64",
        "amd64": "x86_64",
        "arm64": "aarch64",
        "x86_64": "x86_64",
    }.get(ctx.os.arch)
    if (os, arch) not in COCO_TOOLCHAIN_PLATFORMS:
        return None
    return (os, arch)
