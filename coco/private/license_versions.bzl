# Copyright 2026 Cocotec Limited
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

"""Which licence each popili version needs.

Popili versions can share a licence exactly when they use the same licence version (popili's
licensing protocol version). A licence of one version can only be acquired with a licensing
server of that version, and popili stores it as `licenses_<licence version>.lic`.

Licence versions are an implementation detail: they appear in generated repository and target
names only, never in anything users write or read.

This file loads only the version_resolution.bzl leaf, so it can be used from repository rules,
module extensions and rules alike.
"""

load(":version_resolution.bzl", "version_tuple")

# The first popili version of each licence version, oldest first. The last entry is
# open-ended, so versions newer than rules_coco knows get the newest licence version.
# Licence version 7 only ever shipped in 1.6.0 pre-releases, which are not supported.
LICENSE_VERSIONS = [
    ("1.5.0", 6),
    ("1.6.0", 8),
]

def license_version(version):
    """Returns the licence version a popili version needs.

    Args:
        version: A popili version string, e.g. "1.5.7" or "1.6.0-alpha.15899".

    Returns:
        The licence version as an int, or None if `version` isn't a version (e.g. "local")
        or predates every entry of LICENSE_VERSIONS.
    """
    parsed = version_tuple(version)
    if parsed == None:
        return None
    result = None
    for first_version, lv in LICENSE_VERSIONS:
        if parsed >= version_tuple(first_version):
            result = lv
    return result

def known_license_versions():
    """Returns every licence version in LICENSE_VERSIONS, ascending.

    A local toolchain's licence version is only found out when that toolchain is fetched, which
    happens only under --@rules_coco//:version=local. The licence repositories, fetched by every
    build, therefore provide a target for each of these, so whichever one the local popili turns
    out to need exists without asking it.
    """
    return sorted({lv: True for _, lv in LICENSE_VERSIONS}.keys())

def parse_version_json(text):
    """Extracts the version from the output of `popili --version-format=json --version`.

    Args:
        text: The command's standard output.

    Returns:
        The "version" field, e.g. "1.6.0-alpha.15899", or None if it can't be found.
    """
    text = text.strip()
    if not text.startswith("{"):
        return None
    decoded = json.decode(text, default = None)
    if type(decoded) != "dict":
        return None
    version = decoded.get("version")
    if type(version) != "string" or version_tuple(version) == None:
        return None
    return version

def is_newer_than_known(version, known_versions):
    """Returns whether a popili version is newer than every version rules_coco knows.

    Args:
        version: A popili version string.
        known_versions: Version strings rules_coco knows, e.g. those with known checksums.

    Returns:
        True if `version`'s release is newer than all of `known_versions` and every entry of
        LICENSE_VERSIONS.
    """
    parsed = version_tuple(version)
    if parsed == None:
        return False
    known = [version_tuple(v) for v in known_versions] + [version_tuple(v) for v, _ in LICENSE_VERSIONS]
    known = [k for k in known if k != None]
    return not [k for k in known if k >= parsed]

def license_representatives(versions):
    """Chooses, for each licence version, the popili version whose licensing server acquires it.

    The first entry of `versions` is the default, so it is preferred for its own licence
    version: it's the one most likely to be downloaded anyway. Other licence versions use their
    newest version.

    Args:
        versions: Resolved popili versions in priority order, the default first. Must not
            include "local".

    Returns:
        A dict from licence version (int) to popili version string.
    """
    representatives = {}
    for version in versions:
        lv = license_version(version)
        if lv == None:
            continue
        current = representatives.get(lv)
        if current == None:
            representatives[lv] = version
        elif current != versions[0] and version_tuple(version) > version_tuple(current):
            representatives[lv] = version
    return representatives
