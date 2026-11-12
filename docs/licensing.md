# Licensing

To use the rules, the host where the build actions executes will need to have a license. If the build runs locally,
then this means that local host requires a license. If remote execution is being used, then the remote executor will
need a license.

In CI you need a machine token: a Cocotec token that identifies a machine or CI job rather than a person, passed to
popili as `COCOTEC_AUTH_TOKEN`. You can get one in two ways:

- (Preferred) Using workload identity federation: in this, tokens from your existing identity provider can be used to
  authenticate to Cocotec. This works with AWS or any OIDC-compatible identity provider, such as Github Actions and
  Google Cloud.
- Using a secret API token for the Cocotec services.

Contact [Cocotec Support](https://cocotec.io/support/) to set this up or discuss options.

| Mode                   | Credentials                                                                                               | Remote execution |
| ---------------------- | --------------------------------------------------------------------------------------------------------- | ---------------- |
| `local_user` (default) | the license already activated on the machine running Bazel                                                | no               |
| `local_acquire`        | a token in `COCOTEC_AUTH_TOKEN` on the machine running Bazel, passed with `--repo_env=COCOTEC_AUTH_TOKEN` | no               |
| `action_environment`   | whatever popili finds in each action's environment, such as an injected `COCOTEC_AUTH_TOKEN`              | yes              |
| `action_file`          | a token file at `--@rules_coco//:auth_token_path` on every machine that runs actions                      | yes              |
| `token`                | a token passed with `--@rules_coco//:license_token`, for workload identity federation                     | yes              |

## License modes

`rules_coco` supports several different license modes:

- `action_environment`: rules_coco passes no credentials. popili finds them in the action's environment, for example
  where a remote execution service injects `COCOTEC_AUTH_TOKEN` into actions as a secret.

  This is the recommended mode when using remote execution, as it will not interfere with bazel's cache, and also keeps
  the license token most secure.

- `action_file`: An auth token file path is provided that is guaranteed to be available in the execution environment of
  each action (e.g., mounted on remote runners). The path must be specified via `--@rules_coco//:auth_token_path` or
  with `auth_token_path` on `coco.toolchain` or `coco_repositories`. Popili will be invoked with `--machine-auth-token`
  pointing to this file.

  This mode is suitable for remote execution environments where auth token files are pre-mounted or made available through
  other mechanisms. **Requires popili 1.5.2 or later.** rules_coco does not check either requirement: without an
  `auth_token_path`, popili runs with no token and fails to find a license.

- `local_acquire`: rules_coco acquires a license on the local machine with `COCOTEC_AUTH_TOKEN`. Bazel reads the
  token from your shell when it fetches the license repository, so export it and pass `--repo_env=COCOTEC_AUTH_TOKEN`;
  without it popili fails at its first action. Not compatible with remote execution.
- `local_user`: rules_coco reuses the license already activated on this machine, from popili's data directory:
  `~/Library/Application Support/Popili` on macOS, `%LOCALAPPDATA%\Popili` on Windows, or `$XDG_DATA_HOME/popili` (by
  default `~/.local/share/popili`) on Linux. `POPILI_DATA` overrides it. Not compatible with remote execution. A
  [local toolchain](toolchains.md#using-a-local-toolchain) may need `license_protocol_version`.
- `token`: The explicitly provided token should be used as `COCOTEC_AUTH_TOKEN`. In this case,
  `--@rules_coco//:license_token` must be set as well. This works with remote execution but it is only recommended when
  using workload identity federation as `COCOTEC_AUTH_TOKEN` is not a secret in that case.

## Selecting a mode

This can be configured in three ways (in order of precedence):

1. **Via command-line flag** (highest precedence):

   ```bash
   bazel build --@rules_coco//:license_source=local_acquire //...

   # For action_file mode, also specify the auth token path:
   bazel build --@rules_coco//:license_source=action_file --@rules_coco//:auth_token_path=/path/to/token //...
   ```

2. **In MODULE.bazel** (for bzlmod users):

   ```python
   coco = use_extension("@rules_coco//coco:extensions.bzl", "coco")
   coco.toolchain(
       versions = ["stable"],
       license_source = "local_acquire",  # Optional: set repository default
       # license_token = "...",  # Optional: only needed when license_source = "token"
       # auth_token_path = "/path/to/token",  # Optional: only needed when license_source = "action_file"
   )
   ```

3. **In WORKSPACE** (for WORKSPACE users):
   ```python
   coco_repositories(
       versions = ["stable"],
       license_source = "local_acquire",  # Optional: set repository default
       # license_token = "...",  # Optional: only needed when license_source = "token"
       # auth_token_path = "/path/to/token",  # Optional: only needed when license_source = "action_file"
   )
   ```

The repository-level configuration (MODULE.bazel or WORKSPACE) sets a default that applies to all builds, while the
command-line flag can be used to override it for specific builds. If neither is specified, the default is `local_user`.
A bring-your-own `coco_toolchain` ignores this default; see [Custom toolchains](toolchains.md#bring-your-own-toolchain).

> [!WARNING]
> The `license_token` parameter is available in repository configuration for convenience, but:
>
> - The `license_token` parameter should **only** be used in repository configuration when using workload identity
>   federation, where the token is not a secret.
> - For secret tokens, use the command-line flag instead: `--@rules_coco//:license_token=<token>`, or better yet ensure
>   that your bazel execution environment injects `COCOTEC_AUTH_TOKEN` directly into actions.
