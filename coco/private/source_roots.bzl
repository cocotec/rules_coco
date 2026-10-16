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

"""Source roots of a Coco package.

popili derives a module's path from its .coco file's path relative to the source root that contains it
(`sources = [...]` in Coco.toml), and writes the generated files for that module at that path below the
output directory. Starlark cannot read Coco.toml, so coco_package either takes the roots as attributes or infers
a single root from the source files. Roots are relative to the Coco.toml directory; popili also accepts
roots outside it, so those are handled too. The functions here are pure so that tests.bzl can cover them.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")

def relative_path(path, start):
    """Expresses a path relative to a directory, which need not contain it.

    Unlike `paths.relativize`, this returns `..` segments when path is not below start, so that sources
    in a root outside the Coco.toml directory get a path relative to it.

    Args:
        path: A relative path, e.g. "external_sources/MyPort.coco".
        start: A relative directory, e.g. "Main". "" is the workspace root.

    Returns:
        path relative to start, e.g. "../external_sources/MyPort.coco", or "" when they are equal.
    """
    path_segments = [s for s in paths.normalize(path).split("/") if s and s != "."]
    start_segments = [s for s in paths.normalize(start).split("/") if s and s != "."]
    shared = 0
    for a, b in zip(path_segments, start_segments):
        if a != b:
            break
        shared += 1
    return "/".join([".."] * (len(start_segments) - shared) + path_segments[shared:])

def leaves_directory(relative):
    """Whether a path relative to a directory points outside it.

    Args:
        relative: A normalised relative path.

    Returns:
        True if it is ".." or starts with "../".
    """
    return relative == ".." or relative.startswith("../")

def normalize_root(root, attr = "root"):
    """Normalises a directory given relative to the Coco.toml directory.

    Args:
        root: The directory as written in a BUILD file. "", "." and "./" all mean the Coco.toml directory.
        attr: Attribute name for error messages.

    Returns:
        The directory without a trailing slash, or "" for the Coco.toml directory itself. It may start
        with ".." for a root outside the Coco.toml directory.
    """
    if paths.is_absolute(root):
        fail("%s: '%s' must be relative to the directory containing Coco.toml" % (attr, root))
    normalized = paths.normalize(root)
    if normalized == ".":
        return ""
    return normalized

def infer_source_root(relative_paths):
    """Infers a single source root from source paths relative to the Coco.toml directory.

    Returns the longest directory that contains every file. This does not depend on the order of the
    paths. It cannot tell `sources = ["src"]` apart from `sources = ["src/a"]` when every file lives in
    `src/a`, and cannot express several roots; those cases need `source_roots`.

    Args:
        relative_paths: Source file paths relative to the Coco.toml directory.

    Returns:
        The common directory, or "" for files beside Coco.toml or an empty list.
    """
    common = None
    for path in relative_paths:
        segments = paths.dirname(path).split("/") if paths.dirname(path) else []
        if common == None:
            common = segments
            continue
        shared = 0
        for a, b in zip(common, segments):
            if a != b:
                break
            shared += 1
        common = common[:shared]
    return "/".join(common) if common else ""

def source_root_for(relative_path, roots, attr = "source_roots", label = None):
    """Picks the source root that contains a file.

    Args:
        relative_path: Source file path relative to the Coco.toml directory.
        roots: Normalised source roots (see normalize_root). "" matches every file.
        attr: Attribute the roots came from, "source_roots" or "test_source_roots", for the error message.
        label: Package label for the error message, if any.

    Returns:
        The longest root that is an ancestor of relative_path.
    """
    best = None
    for root in roots:
        if root != "" and not paths.starts_with(relative_path, root):
            continue
        if best == None or len(root) > len(best):
            best = root
    if best == None:
        fail("%s is not below any of the source roots %s%s; %s must match `%s` in Coco.toml" % (
            relative_path,
            roots,
            " of %s" % label if label else "",
            attr,
            "testSources" if attr == "test_source_roots" else "sources",
        ))
    return best

def resolve_source_roots(package_dir, files, explicit_roots, attr = "source_roots", label = None):
    """Resolves the source roots of a package from its attributes.

    Args:
        package_dir: Directory containing Coco.toml.
        files: List of source Files.
        explicit_roots: The value of the source_roots / test_source_roots attribute.
        attr: Attribute name for error messages.
        label: Package label for error messages, if any.

    Returns:
        A list of normalised roots: the explicit ones, or a single inferred root.
    """
    relative_paths = [relative_path(f.path, package_dir) for f in files]
    if not explicit_roots:
        outside = [path for path in relative_paths if leaves_directory(path)]
        if outside:
            fail("%s: %s %s outside the directory containing Coco.toml%s; set %s to match Coco.toml" % (
                attr,
                outside,
                "is" if len(outside) == 1 else "are",
                " of %s" % label if label else "",
                attr,
            ))
        return [infer_source_root(relative_paths)]
    roots = [normalize_root(root, attr) for root in explicit_roots]
    for path in relative_paths:
        source_root_for(path, roots, attr, label)
    return roots
