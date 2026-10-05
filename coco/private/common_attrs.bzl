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

"""Forwarding of common attrs from a macro's main target to its companion targets."""

# Common attrs that decide whether a target is built at all (tags = ["manual"],
# target_compatible_with, ...) or may depend on testonly targets. A companion target
# depends on the same inputs as the macro's main target, so it needs the same values.
_COMPANION_ATTRS = (
    "compatible_with",
    "exec_compatible_with",
    "restricted_to",
    "tags",
    "target_compatible_with",
    "testonly",
)

def companion_attrs(kwargs, extra_tags = []):
    """Returns the common attrs in kwargs that a companion target should also get.

    Args:
        kwargs: The macro's kwargs. Other attrs in it are ignored.
        extra_tags: Tags the companion always gets, on top of any forwarded tags.

    Returns:
        A dict to pass as **kwargs to the companion target's rule.
    """
    attrs = {attr: kwargs[attr] for attr in _COMPANION_ATTRS if attr in kwargs}
    if extra_tags:
        attrs["tags"] = (attrs.get("tags") or []) + extra_tags
    return attrs
