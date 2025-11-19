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

## Configuration for Users with GitHub Access

If you can access GitHub, use this configuration:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "regexManagers": [
    {
      "fileMatch": ["^MODULE\\.bazel$"],
      "matchStrings": [
        "archive_override\\([\\s\\S]*?module_name\\s*=\\s*\"rules_coco\"[\\s\\S]*?urls\\s*=\\s*\\[[\\s\\S]*?releases/download/(?<currentValue>[^/\"]+)/"
      ],
      "datasourceTemplate": "github-releases",
      "depNameTemplate": "cocotec/rules_coco",
      "versioningTemplate": "semver"
    }
  ]
}
```

This configuration:
- Monitors your `MODULE.bazel` file for rules_coco versions.
- Uses GitHub releases as the datasource.
- Automatically creates PRs when new versions are available.

## Configuration for Users without GitHub Access

If you cannot access GitHub but can access `dl.cocotec.io`, use this configuration:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "regexManagers": [
    {
      "fileMatch": ["^MODULE\\.bazel$"],
      "matchStrings": [
        "archive_override\\([\\s\\S]*?module_name\\s*=\\s*\"rules_coco\"[\\s\\S]*?urls\\s*=\\s*\\[[\\s\\S]*?\"https://dl\\.cocotec\\.io/rules_coco/rules_coco_(?<currentValue>[^\"]+)\\.tar\\.gz\""
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
- Monitors your `MODULE.bazel` file for rules_coco versions from dl.cocotec.io
- Uses the custom version manifest instead of GitHub
- Works entirely without GitHub access

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

**Important:** If you're using the offline configuration, ensure the `dl.cocotec.io` URL appears in your `urls` list so Renovate can detect it.

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
      "digest": "4a930cb5a775e4b3b06938d87d5aa20123c553ebe931343be2dd8c7a99237e97"
    },
    {
      "version": "0.1.1",
      "releaseTimestamp": "2024-11-14T10:00:00Z",
      "changelogUrl": "https://github.com/cocotec/rules_coco/releases/tag/0.1.1",
      "digest": "..."
    }
  ]
}
```

This manifest is automatically updated whenever a new version is released.
