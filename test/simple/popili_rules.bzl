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

"""Rules defined with popili_rule, one of each flavour: an action, a test and a binary."""

# popili_rule is private to rules_coco; its own tests may load it.
load("@rules_coco//coco/private:coco.bzl", "popili_rule")  # buildifier: disable=bzl-visibility

def _popili_component_diagram_impl(ctx, popili):
    out = ctx.actions.declare_file(ctx.label.name + ".svg")
    popili.run(
        arguments = ["graph-component", "--component", ctx.attr.component, "--output", out.path],
        outputs = [out],
        progress_message = "Drawing %s of %s with popili %s" % (ctx.attr.component, popili.package.name, popili.version),
    )
    return [DefaultInfo(files = depset([out]))]

popili_component_diagram = popili_rule(
    implementation = _popili_component_diagram_impl,
    attrs = {"component": attr.string(mandatory = True)},
    package = True,
)

def _popili_typecheck_impl(ctx, popili):
    return DefaultInfo(
        executable = popili.script(["typecheck"]),
        runfiles = ctx.runfiles(transitive_files = popili.runfiles),
    )

popili_typecheck_test = popili_rule(
    implementation = _popili_typecheck_impl,
    package = True,
    test = True,
)

popili_typecheck = popili_rule(
    implementation = _popili_typecheck_impl,
    package = True,
    executable = True,
)
