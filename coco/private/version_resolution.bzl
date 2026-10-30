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

"""Version strings: resolving them, parsing them, and the flags that select them.

This file loads only the data files `license_versions.bzl` and `version_aliases.bzl`, so it
can be used from build rules, repository rules, module extensions and WORKSPACE macros alike
without pulling either the rule layer or the repository layer into the other.
"""

load(":license_versions.bzl", "LICENSE_PROTOCOL_VERSIONS")
load(":version_aliases.bzl", "VERSION_ALIASES")

# The build setting that selects which registered Coco version a build uses.
VERSION_FLAG = "@rules_coco//:version"

# The boolean flag that makes VERSION_FLAG apply everywhere, ignoring every `popili_version` pin.
FORCE_VERSION_FLAG = "@rules_coco//:force_version"

# The version a popili distribution on the local filesystem is registered as.
LOCAL_VERSION = "local"

# Version strings the hub uses for its own config_settings, so they cannot also name
# a popili release. validate_minimum_version() waves them through because they contain
# no ".", and "default" would otherwise emit a duplicate config_setting.
RESERVED_VERSIONS = [LOCAL_VERSION, "default"]

_MINIMUM_VERSION = (1, 5, 0)

def resolve_version_alias(version):
    """Resolves a version alias (like "stable") to the version it points at.

    Args:
        version: A version string as written by the user: an alias such as "stable", or
            an explicit version such as "1.5.1".

    Returns:
        The version the alias points at, or `version` unchanged when it is not an alias.
    """
    if version in VERSION_ALIASES:
        return VERSION_ALIASES[version]
    return version

def version_tuple(version):
    """Parses the release part of a version string, ignoring any pre-release suffix.

    Args:
        version: A version string such as "1.5.0" or "1.6.0-alpha.15899".

    Returns:
        A tuple of integers such as (1, 6, 0), or None if the string isn't a version.
    """
    base_version = version.split("-")[0]
    result = []
    for part in base_version.split("."):
        if not part or not part.isdigit():
            return None
        result.append(int(part))
    return tuple(result) if result else None

def version_key(version):
    """Returns a key that sorts version strings by semantic versioning precedence.

    A release sorts after its pre-releases, and pre-release identifiers compare numerically
    when they are numbers ("beta.10" after "beta.2") and before alphanumeric ones.

    Args:
        version: A version string such as "1.5.0" or "1.6.0-beta.3".

    Returns:
        A tuple to compare with other keys, or None if the string isn't a version.
    """
    release = version_tuple(version)
    if release == None:
        return None
    _, separator, pre_release = version.partition("-")
    if not separator:
        return (release, (1,))

    # Tag each identifier so that numbers are never compared with strings.
    identifiers = [(0, int(part)) if part.isdigit() else (1, part) for part in pre_release.split(".")]
    return (release, (0,) + tuple(identifiers))

def license_protocol_version(version, table = LICENSE_PROTOCOL_VERSIONS):
    """Returns the licence protocol version a popili version reads.

    This is not a validity check: a version newer than every entry of the table, or one that
    isn't a version at all (a toolchain whose version is unknown), gets the newest protocol
    version, so that versions released after rules_coco keep working.

    Args:
        version: A popili version, e.g. "1.5.8" or "1.6.0-beta.3". May also be "local" or "".
        table: The earliest popili version of each protocol version, in ascending order;
            LICENSE_PROTOCOL_VERSIONS unless testing.

    Returns:
        The protocol version, an int: that of the last entry not newer than `version`, or of
        the first entry when `version` predates them all.
    """
    protocols = table.values()
    key = version_key(version)
    if key == None:
        return protocols[-1]
    protocol = protocols[0]
    for earliest, entry in table.items():
        if version_key(earliest) > key:
            break
        protocol = entry
    return protocol

def validate_minimum_version(version):
    """Validates that a version meets the minimum requirement of 1.5.0.

    Args:
        version: Version string to validate (e.g., "1.5.0", "1.4.9-rc.1")

    Returns:
        None if version is valid, error message string if version is too old
    """

    # Skip validation for version aliases (they're validated separately)
    if not version or "." not in version:
        return None

    parsed = version_tuple(version)
    if parsed == None:
        return "Invalid version string: %s" % version

    if parsed < _MINIMUM_VERSION:
        return (
            "Popili version %s is not supported. " % version +
            "rules_coco requires Popili 1.5.0 or higher. " +
            "Please upgrade to a newer version."
        )

    return None

def version_to_repo_suffix(version):
    """Converts a version string to a valid repository name suffix.

    Examples:
        "1.5.0" -> "1_5_0"
        "1.5.0-rc.3" -> "1_5_0_rc_3"
        "stable" -> "stable"

    Args:
        version: Version string to normalize

    Returns:
        Normalized version string suitable for use in repository names
    """
    return version.replace(".", "_").replace("-", "_")
