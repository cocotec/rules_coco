# Using an older C++ compiler (Boost libraries)

Most users can skip this page. The Coco C++ runtime compiles cleanly on any toolchain that supports C++11 or
later. It also includes limited support for GCC 4.x but requires some Boost dependencies to support this compiler.

`rules_coco` does not supply its own `rules_boost`; instead you need to supply your own library targets if you want to
ensure compatibility with older compilers. In `rules_boost` terms the two targets are `@boost//:integer` and
`@boost//:type_traits`.

## Every build uses GCC 4.x

Depend on Boost unconditionally:

```starlark
coco = use_extension("@rules_coco//coco:extensions.bzl", "coco")
coco.toolchain(versions = ["1.5.1"], cc = True)
coco.cc_runtime_deps(
    version = "1.5.1",
    deps = ["@boost//:integer", "@boost//:type_traits"],
)
```

`coco.cc_runtime_deps` is allowed only in the root module, so a library module cannot add Boost for its consumers.

## Some builds use GCC 4.x, some don't

`MODULE.bazel` is evaluated before `select()` fires, so the conditional lives in a target you own:

```starlark
# MODULE.bazel
coco.cc_runtime_deps(version = "1.5.1", deps = ["//third_party/boost_shim"])
```

```starlark
# third_party/boost_shim/BUILD.bazel
cc_library(name = "empty")
cc_library(
    name = "boost_bundle",
    deps = ["@boost//:integer", "@boost//:type_traits"],
)

alias(
    name = "boost_shim",
    actual = select({
        "//config:old_libstdcxx": ":boost_bundle",
        "//conditions:default": ":empty",
    }),
    visibility = ["//visibility:public"],
)
```

`//config:old_libstdcxx` is whatever `config_setting` you already use to identify old-compiler builds — typically a
platform constraint so the `select()` fires automatically off `--platforms`:

```starlark
# //config/BUILD.bazel
constraint_setting(name = "libstdcxx_era")
constraint_value(name = "pre_gcc5", constraint_setting = ":libstdcxx_era")
config_setting(name = "old_libstdcxx", constraint_values = [":pre_gcc5"])
```

## Same as above, and keep `rules_boost` out of modern-compiler workspaces

The shim above still pulls `rules_boost` into every workspace, because `@boost//:integer` is named in a `select()`
branch Bazel must load. A `label_flag` defers the reference until `.bazelrc` sets it:

```starlark
# third_party/boost_shim/BUILD.bazel
cc_library(name = "empty")
label_flag(
    name = "boost_shim",
    build_setting_default = ":empty",
    visibility = ["//visibility:public"],
)
```

```ini
# .bazelrc — only old-compiler configs set the flag
build:old_compiler --//third_party/boost_shim=@boost//:integer
```

In a real build, point the flag at an aggregate covering both `@boost//:integer` and `@boost//:type_traits`.

A `coco.local_toolchain` runtime is addressed as version `"local"`:

```starlark
coco.cc_runtime_deps(version = "local", deps = ["//third_party/boost_shim"])
```

## WORKSPACE mode

A flat list applies to every registered version:

```starlark
coco_repositories(
    versions = ["1.5.1"],
    cc = True,
    cc_runtime_extra_deps = ["@my_workspace//third_party/boost_shim"],
)
```

A dict targets one version at a time, mirroring bzlmod's per-version `coco.cc_runtime_deps` tag:

```starlark
coco_repositories(
    versions = ["1.5.1", "1.5.0"],
    cc = True,
    cc_runtime_extra_deps = {
        "1.5.1": ["@my_workspace//third_party/boost_shim"],
        "1.5.0": ["@my_workspace//third_party/boost_shim_old"],
    },
)
```

Naming a version that was not registered is an error. Unlike the bzlmod tag, these labels are not
resolved against your workspace before being written into the generated runtime repository, so
they must be repository-absolute (`@my_workspace//...`, not `//...`).

Which target you name is an independent choice: the three patterns above describe that, and all
three work here unchanged — Boost directly, a `cc_library` wrapping a `select()`, or a `label_flag`.
Only the spelling differs between the two modes.
