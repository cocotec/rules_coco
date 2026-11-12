# Build flags

rules_coco reads these flags. Set them on the command line or in a `.bazelrc`, for example
`build --@rules_coco//:license_source=action_environment`.

| Flag                                                                                          | Values                                                                      | When unset                                          |
| --------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | --------------------------------------------------- |
| [`--@rules_coco//:version`](popili-versions.md#selecting-the-version-for-a-whole-build)       | a registered version, or `local`                                            | each target's pin, else the default version         |
| [`--@rules_coco//:force_version`](popili-versions.md#selecting-the-version-for-a-whole-build) | boolean                                                                     | pins win over `version`                             |
| [`--@rules_coco//:license_source`](licensing.md#selecting-a-mode)                             | `action_environment`, `action_file`, `local_acquire`, `local_user`, `token` | the toolchain's `license_source`, else `local_user` |
| [`--@rules_coco//:license_token`](licensing.md#licence-modes)                                 | the token, for `token` mode                                                 | the toolchain's `license_token`                     |
| [`--@rules_coco//:auth_token_path`](licensing.md#licence-modes)                               | a path on the executor, for `action_file` mode                              | the toolchain's `auth_token_path`                   |
| [`--@rules_coco//:verification_backend`](verification.md#verification-backend)                | `local`, `remote`, `attempt-remote`                                         | Popili's own default                                |

## Config settings

`@rules_coco//config/license_source:<mode>` is a `config_setting` for each licence mode. It matches when
`--@rules_coco//:license_source` is set to that mode, not when the mode comes from a toolchain default.
