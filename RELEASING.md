# Releasing rules_coco

Development happens on `main`; releases come from release branches.

- **Minor releases** (0.4.0, 0.5.0, …) are made from `main`. Each one creates a `release/X.Y` branch.
- **Patch releases** (0.4.1, 0.4.2, …) are made from their `release/X.Y` branch. They carry new Popili digests and
  backported fixes, never a `feat` or a breaking change.

So a new Popili release no longer ships whatever is on `main`. While rules_coco is at 0.x, a breaking change bumps
the minor version (commitizen's `major_version_zero`); see [Release 1.0.0](#how-to) for leaving 0.x.

## Workflows

All of them are started from the Actions tab or by approving a pull request.

- [**Prepare Release**](.github/workflows/prepare-release.yml): run it with "Use workflow from" set to `main` for the
  next minor, or to a `release/X.Y` branch for its next patch. It picks the version with
  [commitizen](https://commitizen-tools.github.io/commitizen/) from the commits since the previous release, bumps
  `version.bzl` and `MODULE.bazel`, moves `[Unreleased]` in CHANGELOG.md to it, and opens a `chore(release): X.Y.Z`
  pull request with auto-merge. Its `version` input [sets the version by hand](#how-to) instead.
- [**Release**](.github/workflows/release.yaml): runs when a change to `version.bzl` lands on `main` or `release/X.Y`,
  i.e. when a pull request from Prepare Release or Update Digests is merged. It checks the release policy, then tags,
  creates the GitHub release, uploads the archive to dl.cocotec.io and, for a release from `main`, creates
  `release/X.Y`. Run it by hand only from a branch: it refuses a tag, even one named `main`.
- [**Update Digests**](.github/workflows/update-digests.yml): run it from `main` after a Popili release. It opens two
  pull requests: the `release/X.Y` of the newest release gets the digests plus a patch bump, so approving it releases;
  `main` gets just the digests. Pass `branch` to pick another release branch. It skips a branch that still has an open
  pull request from an earlier run, and stops if the newest release has no release branch yet or if the release branch
  holds a version that is still to be released.
- [**PR Title**](.github/workflows/pr-title.yml): runs on every pull request. It checks the title is a conventional
  commit and that a pull request into `release/X.Y` is neither a `feat` nor breaking, in its title or its description.
  A pull request that changes `version.bzl` must also pass the release policy, so a release that the Release workflow
  would refuse is stopped before it merges. In the merge queue it checks the same of the squashed commits themselves,
  which is what the Release workflow reads.

The policy itself (which versions may come from which branch) is in [tools/release_policy.py](tools/release_policy.py).

## Pull request titles

Pull requests are squash-merged with their title as the commit subject, and commitizen reads those subjects to size
the next release. So titles must be [conventional commits](https://www.conventionalcommits.org/): `fix(rules): …`,
`feat(rules): …`, and `feat(rules)!: …` (or `fix!:`, `refactor!:`, …) for a breaking change. Mark every breaking
change with `!`: that is what keeps it out of patch releases. A revert is `revert: …` too: retitle the `Revert "…"`
that GitHub's Revert button proposes, which would hide what a revert of a revert brings back.

The description becomes the body of the squashed commit, and commitizen reads every line of it: a `BREAKING CHANGE:`
footer, or a line that starts like a `feat:` or `…!:` title, counts as if it were the title. PR Title therefore also
refuses such lines in pull requests into `release/X.Y`; it asks commitizen itself, so it refuses exactly what would
change the size of the release. Put commit subjects you quote in a list (`* feat: …`), where commitizen ignores them.

## How to

**Release the next minor.** Curate `[Unreleased]` in CHANGELOG.md on `main` (a minor release refuses an empty one), then
run Prepare Release on `main` and approve its pull request. The Release workflow publishes X.Y.0 and creates
`release/X.Y` once a maintainer approves the pending `release-branch` deployment (Actions → the Release run → Review
deployments → Approve; reviewers are notified). Should creating the branch fail, a maintainer can create it at the
released commit instead:

```sh
gh api -X POST repos/cocotec/rules_coco/git/refs -f ref=refs/heads/release/X.Y \
  -f sha="$(gh api repos/cocotec/rules_coco/commits/X.Y.0 --jq .sha)"
```

(or `git push origin X.Y.0^{commit}:refs/heads/release/X.Y`). Only the Release workflow, maintainers and admins may
create release branches; see [How release branches are created](#how-release-branches-are-created).

**Release new Popili digests.** Run Update Digests and approve both pull requests. If there is no release branch yet
(before 0.4.0) only the `main` pull request is opened, with a warning; the digests then ship with the next minor.

**Backport a fix.** Cherry-pick the squashed commit from `main` onto a branch off `release/X.Y`, add a CHANGELOG.md entry
under `[Unreleased]` there, and open a pull request into `release/X.Y` with a `fix` title. Then run Prepare Release on
`release/X.Y` (or let the next Update Digests release it).

**Fix a failed release.** Use "Re-run failed jobs" on the Release run: it finishes what is missing, whether or not the
tag and the GitHub release exist already (for instance when the upload to dl.cocotec.io or only `create-release-branch`
failed). While the tag does not exist, "Run workflow" on the same branch works too. Until the version is released,
Prepare Release and Update Digests refuse to bump it again, and say so. To give up on the version instead, revert its
pull request; PR Title lets a pull request through that takes `version.bzl` back to the previous release.

**Set the version by hand.** Run Prepare Release with `version` set to release that version instead of the one
commitizen derives. The branch must still be the right one for it (a minor or major from `main`, an X.Y.Z from
`release/X.Y`) and the version new. The pull request's description then ends in a `Release-As: X.Y.Z` footer; with it
in the squashed commit, PR Title and the Release workflow accept the version whatever the commits call for, so leave
the footer in.

**Release from a release branch that got a `feat` or a breaking change.** PR Title keeps these out, but should one land
anyway (say, while squash merges still used the commit subject), Prepare Release and Release refuse every release from
that branch and name the commits. Reverting does not help by itself, since commitizen sizes a release from the history,
which still holds them. So revert each one in a pull request into `release/X.Y`, then set the version by hand to the
next patch. That waives the check for everything since the previous release, not only for the reverted commits: the
pull request lists the commits concerned, so check each is reverted before approving. The release after it starts from
a clean history again.

**Release 1.0.0.** While [.cz.toml](.cz.toml) has `major_version_zero = true`, commitizen never proposes a major
version, so Prepare Release on `main` proposes 0.(Y+1).0 by itself. To leave 0.x:

1. Curate `[Unreleased]` in CHANGELOG.md as for a minor, run Prepare Release on `main` with `version` set to `1.0.0`,
   and approve. The Release workflow publishes 1.0.0 and creates `release/1.0`.
2. Open a pull request into `main` that sets `major_version_zero = false` in `.cz.toml` and drops the 0.x sentence from
   the top of this file, before the next release from `main`. From then on Prepare Release proposes a major release
   (2.0.0, …) when `main` has a breaking change since the last one, and a minor release otherwise. Leave the setting
   off: commitizen applies it at any version, so with it a breaking change would ship in a minor release again.

Nothing else changes. The `release/0.Y` branches keep their own `.cz.toml` and their patch releases; the rulesets, the
`release-branch` environment, the GCP condition and the licence connection match `release/X.Y` for any X; and "Latest"
goes to the highest version.

## Changelog

A minor release moves `[Unreleased]` on `main` into its `[X.Y.0]` section, which its release branch inherits. Patch
release sections exist only on their release branch; the GitHub release notes list their pull requests too. A
backported fix keeps its entry on `main`, so it shows up again in the next minor.

## Keeping old releases buildable

Each branch tests and releases with its own copy of the workflows and of `tools/`, so a `release/X.Y` branch keeps
working however much `main` changes. For that to hold:

- Runner images are pinned (`ubuntu-24.04`, `macos-26`, `windows-2025`) instead of `*-latest`. When GitHub retires an
  image, update the label on each release branch that still needs to ship.
- Bazel is pinned by `.bazelversion` and the CI matrix, dependencies by `MODULE.bazel.lock`, pre-commit hooks by `rev`,
  and the release tools, with everything they depend on and its hashes, by
  [tools/requirements-release.txt](tools/requirements-release.txt). That file is generated from
  [tools/requirements-release.in](tools/requirements-release.in), which says how.
- Renovate only updates `main`; release branches change only through their own pull requests. It regenerates
  `tools/requirements-release.txt` with its pip-compile manager, from the command in that file's header.
- Update Digests runs from `main` but calls `tools/update_digests.py`, `tools/release.py --bump patch` and
  `tools/release_policy.py current-version` and `check-version-released` of the release branch, so keep those four
  command lines working.
- Things outside the repository cannot be pinned: Popili archives on dl.cocotec.io, the licence server, the CI auth
  connection and the GCP identity. Each must keep accepting the branches that still release (see below).

## How release branches are created

A ruleset that requires pull requests only guards branches that already exist: anyone with write access can create a
new branch matching it, even with commits nobody reviewed (tested on a throwaway repository, 2026-11-12). Pushes to
`release/X.Y` run the workflow files of the pushed branch, and those workflows get release credentials (GCP trusts
`release/X.Y` branches), so creating a release branch is restricted by a ruleset of its own. Its bypass list holds
deploy keys, for the Release workflow, and maintainers and admins, as a fallback. A second ruleset, which nobody
bypasses, keeps everyone from changing an existing release branch other than through a reviewed pull request.

The `create-release-branch` job of the Release workflow pushes the new branch with a deploy key that has write access.
The key is a secret of the `release-branch` environment, which only `main` may use and which requires a maintainer's
approval. So only that job of a release from `main`, running code that was reviewed into `main`, ever sees it, only
after a maintainer approved it, and the job runs nothing but `actions/checkout` pinned to a commit.

**Risks of the deploy key.** Its exposure is limited, not zero:

- It never expires. A copy that leaks, for instance through a compromised `actions/checkout` or a runner, keeps working
  until an administrator removes the key. Rotate it now and then, and at once on any suspicion.
- A leaked key can do over git what the Write role can: push branches that no ruleset protects, and create tags (tag
  protection only stops updating and deleting them). It cannot push to `main` or to an existing release branch, and it
  cannot use the GitHub API, so it cannot create a GitHub release.
- It can also create a `release/*` branch, and that branch runs its own workflows with the repository's secrets and the
  GCP trust in `release/X.Y` branches: a leaked key is therefore a way to publish to dl.cocotec.io without review.
- The bypass is for _all_ deploy keys, so a second deploy key with write access would get it too.
- Anyone who can merge into `main` can add a job that uses the environment. That takes a reviewed pull request, the same
  bar as changing the release workflow itself.
- The approval gates when the key is used, not what a stolen copy can do: it protects against a reviewed-but-wrong
  change to `main` using the key, not against a leak.

**Possible improvement: a dedicated GitHub App instead of the deploy key.** The job would mint a token for an app on the
creation ruleset's bypass list instead:

- a new app (not cocotec-automation, whose tokens every pull-request-opening job mints) with only **Contents: Read and
  write**, installed only on rules_coco;
- its private key imported into Cloud KMS (and the downloaded `.pem` deleted), with `roles/cloudkms.signerVerifier` on
  that key granted only to the OIDC subject `repo:cocotec/rules_coco:environment:release-branch`;
- the same environment with required reviewers, so no token even exists before a maintainer approves.

That leaves no long-lived secret in GitHub (the key cannot be exported from KMS and tokens expire after an hour) and
names one app in the bypass list instead of every deploy key, at the cost of an app registration, a KMS key and an IAM
binding.

**Alternative: no automation, a maintainer creates the branch.** A maintainer already has to approve the
`release-branch` deployment for every minor release. They could instead run the `gh api` command under
[How to](#how-to) themselves. Then there is no deploy key, no environment and no deploy-key bypass (step 4 of the
settings below goes away, and the creation ruleset bypasses only Maintain and Admin), at the cost of one manual command
per minor release that is easy to forget until the next Update Digests stops because the newest release has no release
branch.

## Repository settings (for an administrator)

These settings cannot be changed from a pull request. Apply them in this order, after merging the pull request that
introduced this file.

1. **Squash merge commits use the pull request title.** Settings → General → Pull Requests → Allow squash merging →
   Default commit message: **Pull request title and description**. Today a single-commit pull request uses its commit's
   subject instead of its (checked) title; until this is set, PR Title in the merge queue refuses such a pull request
   when that subject is not a conventional commit, or does not fit the release branch.
2. **Ruleset protecting release branches.** Settings → Rules → Rulesets → New ruleset → Import a ruleset, and pick
   [.github/rulesets/release-branch-protection.json](.github/rulesets/release-branch-protection.json). It copies "Main
   branch protection" to `release/*` (restrict deletions, block force pushes, one approval, resolved conversations,
   merge queue) with these differences:
   - required checks `build` **and `pr-title`**, not required when a branch is created;
   - **approvals are dismissed when new commits are pushed**, since merging into a release branch can publish a
     release: an approved pull request cannot pick up unreviewed changes;
   - squash merges only;
   - no "Restrict creations" (that is the next ruleset), and an **empty bypass list**: nobody pushes to a release
     branch without a reviewed pull request.
3. **Ruleset restricting who creates release branches.** Import
   [.github/rulesets/release-branch-creation.json](.github/rulesets/release-branch-creation.json): only "Restrict
   creations" on `release/*` and `release/**/*`, bypassed (always) by **Deploy keys** (for the Release workflow) and the
   **Maintain** and **Admin** repository roles (as a fallback). If rules_coco's maintainers do not have the Maintain
   role, add their team instead. Keep both patterns: in rulesets `*` does not match `/`, so `release/*` alone lets anyone
   with write access create `release/0.4/x`. Keep this rule in a ruleset of its own: a bypass covers every rule of its
   ruleset, so a bypass on the protection ruleset would let its actors push to release branches without review.
4. **Deploy key for creating release branches, kept in an environment.** See
   [How release branches are created](#how-release-branches-are-created) for what it may do and its risks.
   1. Settings → Environments → New environment: name `release-branch`. Under Deployment branches and tags choose
      **Selected branches and tags** and add the branch rule `main` (nothing else). Tick **Required reviewers** and add
      the rules_coco maintainers (a team, or the individual people). Leave "Prevent self-review" unticked, so the
      maintainer who approved the release pull request can also approve the branch creation.
   2. Generate a key pair: `ssh-keygen -t ed25519 -N "" -C "rules_coco release branches" -f release_branch_key`.
   3. Settings → Deploy keys → Add deploy key: title `Release branch creation`, the contents of
      `release_branch_key.pub`, and tick **Allow write access**.
   4. Settings → Environments → `release-branch` → Environment secrets → Add secret: name `RELEASE_BRANCH_DEPLOY_KEY`,
      the contents of `release_branch_key`. Not a repository secret: those are visible to every workflow.
   5. Delete both local key files.
   6. Check Settings → Deploy keys has no other key with write access: the ruleset of step 3 lets every deploy key
      create release branches.
5. **Require `pr-title` on `main` too.** Settings → Rules → Rulesets → Main branch protection → Require status checks to
   pass → Add checks → `pr-title`. Do this once the check has run on a pull request (it runs on the pull request that
   introduced it), otherwise it cannot be found.
6. **GCP identity accepts release branches.** The Release workflow (upload to `cocotec-downloads`) and Prepare Release
   (signing the cocotec-automation token with Cloud KMS) now also run on `release/X.Y` branches. If the workload identity
   provider in `GCP_WORKLOAD_IDENTITY_PROVIDER`, or the IAM bindings of the service account in `GCP_SERVICE_ACCOUNT`
   and of the KMS key, only allow `refs/heads/main`, extend them to exactly those branches, e.g. the attribute condition
   `assertion.ref == 'refs/heads/main' || assertion.ref.matches('^refs/heads/release/[0-9]+[.][0-9]+$')`. Not a prefix
   such as `startsWith('refs/heads/release/')`: whoever can create a branch that matches it gets these credentials, so
   the condition must match no more than the creation ruleset of step 3 guards.
7. **CI licence connection accepts release branches.** CI authenticates to the Popili licence server through the
   External Auth Connection `6143ef52-0286-4d9e-9176-92ab2020bbd3`. If it restricts the GitHub OIDC `ref`/`sub` claim,
   also allow `refs/heads/release/X.Y` and the merge queue's `refs/heads/gh-readonly-queue/release/X.Y/…`.
8. **Recommended: pin GitHub Actions to commit SHAs.** Third-party actions are referenced by tag (`actions/checkout@v7`),
   and a tag can be moved to other code. Pinning to the full commit SHA guards against such supply-chain attacks and
   keeps old release branches running the exact actions they were tested with.
   1. Add `"helpers:pinGitHubActionDigests"` to `extends` in [renovate.json](renovate.json); Renovate then opens a pull
      request pinning every action (keeping the tag as a comment) and keeps the pins up to date.
   2. Once that is merged, enable Settings → Actions → General → **Require actions to be pinned to a full-length commit
      SHA**, so new unpinned references fail.

No change is needed to "Tag protection": it already stops released tags being moved or deleted, and still lets the
Release workflow create them.

### Checking the setup

The first release under this scheme is 0.4.0, since `main` already holds breaking changes.

1. Run Prepare Release on `main`. It should open `chore(release): 0.4.0`.
2. Approve it. The Release workflow should publish 0.4.0 and wait for approval of the `release-branch` deployment;
   approve it, and it should create `release/0.4`. If creating the branch fails with
   "Cannot create ref due to creations being restricted", step 3 or 4 is off; a maintainer can then create the branch
   as described under [How to](#how-to).
3. Someone with only the Write role should get the same error when trying to create, say, `release/0.99` or
   `release/0.4/x`.
4. The next Update Digests then opens pull requests on `release/0.4` (releasing 0.4.1) and on `main`.

## Open issues

- **A failed Release run when a release branch is created.** Pushing the new `release/X.Y` may start the Release
  workflow on it, depending on how GitHub applies the `version.bzl` path filter to a new branch. That run would stop at
  "Release X.Y.0 already exists" and publish nothing; it is noise, not a failure. Check this on the first release
  (0.4.0); if it happens, the workflow could skip runs whose `before` SHA is all zeros.
