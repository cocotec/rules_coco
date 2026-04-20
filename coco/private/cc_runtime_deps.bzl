# Copyright 2025 Cocotec Limited
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

"""Helper for aggregating coco.cc_runtime_deps tags across modules."""

def _collect_cc_runtime_extra_deps(tag_entries, registered_versions, resolve_version):
    """Merge and validate coco.cc_runtime_deps tags.

    Only root-module tags are accepted: which deps are needed depends on the
    compiler the root build is using, so transitive deps must not speak for
    it. Returns (deps_by_version, error); deps_by_version is empty on error.
    """
    result = {}
    for entry in tag_entries:
        if not entry.is_root:
            return {}, (
                "Module %r called coco.cc_runtime_deps, but only the root module " % entry.module_name +
                "may use that tag. cc_runtime_deps carries configuration specific to the " +
                "compiler the root build uses (e.g. Boost libraries for old libstdc++) " +
                "and cannot be set by transitive dependencies."
            )
        resolved = resolve_version(entry.version)
        if resolved not in registered_versions:
            return {}, (
                "coco.cc_runtime_deps version %r does not match any registered Coco version. " % entry.version +
                "Registered versions (after alias resolution): %s" % sorted(registered_versions.keys())
            )
        bucket = result.setdefault(resolved, [])
        for dep in entry.deps:
            if dep not in bucket:
                bucket.append(dep)
    return result, None

collect_cc_runtime_extra_deps = _collect_cc_runtime_extra_deps
