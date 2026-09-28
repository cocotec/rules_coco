# Using Renovate with rules_coco

This guide explains how to use [Renovate](https://docs.renovatebot.com/) to automatically update your rules_coco
dependency, especially for users who cannot access GitHub.

## Background

Renovate is a tool that automatically creates pull requests to update dependencies in your repositories. While
rules_coco releases are published to GitHub, some users operate behind corporate firewalls that block access to
github.com.

To support these users, rules_coco also publishes:
- Release tarballs to: `https://dl.cocotec.io/rules_coco/`
- A version manifest to: `https://dl.cocotec.io/rules_coco/renovate_versions.json`

## Why Custom Configuration is Needed

rules_coco uses `archive_override` in `MODULE.bazel` to fetch releases directly from URLs. While Renovate has built-in
support for Bazel's `MODULE.bazel` files, it does **not** automatically detect or update `archive_override`
declarations.

## Recommended Configuration

This configuration updates both the version and the `integrity` hash. It uses the version manifest on `dl.cocotec.io`,
so it works with or without GitHub access:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "customManagers": [
    {
      "customType": "regex",
      "managerFilePatterns": ["/(^|/)MODULE\\.bazel$/"],
      "matchStrings": [
        "archive_override\\(\\s*module_name\\s*=\\s*\"rules_coco\"[^)]*?urls\\s*=\\s*\\[[^\\]]*?\"https://dl\\.cocotec\\.io/rules_coco/rules_coco_(?<currentValue>[^\"]+)\\.tar\\.gz\"[^\\]]*\\][^)]*?integrity\\s*=\\s*\"(?<currentDigest>sha256-[A-Za-z0-9+/=]+)\""
      ],
      "datasourceTemplate": "custom.rules_coco",
      "depNameTemplate": "rules_coco",
      "versioningTemplate": "semver"
    }
  ],
  "customDatasources": {
    "rules_coco": {
      "defaultRegistryUrlTemplate": "https://dl.cocotec.io/rules_coco/renovate_versions.json",
      "format": "json"
    }
  }
}
```

This configuration:
- Monitors your `MODULE.bazel` file for the rules_coco `archive_override`.
- Uses the version manifest instead of GitHub, which also provides the `integrity` hash of each release.
- Updates every URL in the `urls` list, as well as `integrity`, in the same pull request.

## Configuration Using GitHub Releases

If you prefer GitHub releases as the datasource, use this configuration instead:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "customManagers": [
    {
      "customType": "regex",
      "managerFilePatterns": ["/(^|/)MODULE\\.bazel$/"],
      "matchStrings": [
        "archive_override\\(\\s*module_name\\s*=\\s*\"rules_coco\"[^)]*?urls\\s*=\\s*\\[[^\\]]*?\"https://github\\.com/cocotec/rules_coco/releases/download/(?<currentValue>[^/\"]+)/rules_coco_[^\"]+\\.tar\\.gz\"[^\\]]*\\]"
      ],
      "datasourceTemplate": "github-releases",
      "depNameTemplate": "cocotec/rules_coco",
      "versioningTemplate": "semver"
    }
  ]
}
```

**Important:** Renovate's `github-releases` datasource only knows the commit SHA of a release tag, not a hash of the
release archive, so this configuration only updates the `urls`. Don't capture `integrity` with it: Renovate would
replace the hash with the commit SHA. Bazel reports a checksum mismatch on the resulting pull request until you replace `integrity`
with the value from the [release notes](https://github.com/cocotec/rules_coco/releases). Use the
[recommended configuration](#recommended-configuration) to have `integrity` updated automatically.

## Example MODULE.bazel

Make sure your `MODULE.bazel` includes the dl.cocotec.io URL:

```starlark
bazel_dep(name = "rules_coco")

archive_override(
    module_name = "rules_coco",
    urls = [
        "https://github.com/cocotec/rules_coco/releases/download/0.1.3/rules_coco_0.1.3.tar.gz",
        "https://dl.cocotec.io/rules_coco/rules_coco_0.1.3.tar.gz",
    ],
    integrity = "sha256-...",
)
```

**Important:** The configurations above only recognise an `archive_override` laid out like this example:
- `module_name` must be the first argument.
- `urls` must include the URL for the configuration you use (`dl.cocotec.io` or `github.com`).
- For the recommended configuration, `integrity` must come after `urls`.

Renovate silently ignores an `archive_override` it does not recognise, so it will never propose an update for it.

## Version Manifest Format

The version manifest at `https://dl.cocotec.io/rules_coco/renovate_versions.json` follows Renovate's [custom datasource format](https://docs.renovatebot.com/modules/datasource/custom/):

```json
{
  "homepage": "https://github.com/cocotec/rules_coco",
  "sourceUrl": "https://github.com/cocotec/rules_coco",
  "releases": [
    {
      "version": "0.1.3",
      "releaseTimestamp": "2024-11-19T10:00:00Z",
      "changelogUrl": "https://github.com/cocotec/rules_coco/releases/tag/0.1.3",
      "digest": "sha256-SpMMtad15LOwaTjYfVqiASPFU+vpMTQ74t2Mepkjfpc="
    },
    {
      "version": "0.1.1",
      "releaseTimestamp": "2024-11-14T10:00:00Z",
      "changelogUrl": "https://github.com/cocotec/rules_coco/releases/tag/0.1.1",
      "digest": "sha256-..."
    }
  ]
}
```

Each `digest` is the SHA-256 of the release archive in the same `sha256-<base64>` form as the `integrity` attribute of
`archive_override`. The manifest is automatically updated whenever a new version is released.
