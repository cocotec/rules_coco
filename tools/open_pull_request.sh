#!/bin/bash

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

# Commits the staged changes of the checkout in the working directory as
# cocotec-automation and opens a pull request for them that merges itself once
# it is approved and the checks pass. For the release workflows; see
# RELEASING.md.
#
# The commit gets the title and the body too, not only the pull request: a
# squash merge of a pull request with one commit may take that commit's
# message, and the release policy reads the body (the `Release-As` footer).
#
# Usage: GITHUB_TOKEN=<cocotec-automation token> open_pull_request.sh BASE BRANCH TITLE BODY
#
# The checkout needs no stored credentials (persist-credentials: false).

set -euo pipefail

base=$1 branch=$2 title=$3 body=$4

git config user.name "cocotec-automation[bot]"
git config user.email "244153713+cocotec-automation[bot]@users.noreply.github.com"
git checkout -b "$branch"
git commit --message "$title" --message "$body"
git push "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "$branch"

url=$(gh pr create --repo "$GITHUB_REPOSITORY" --base "$base" --head "$branch" --title "$title" --body "$body")

# Non-fatal: the pull request exists either way and can be merged by hand.
if merge_error=$(gh pr merge "$url" --auto --squash 2>&1); then
  echo "::notice::Auto-merge enabled on ${url}; merges once approved and the checks pass."
else
  echo "::warning::Could not enable auto-merge on ${url}: ${merge_error}"
fi

echo "Opened ${url}" >> "$GITHUB_STEP_SUMMARY"
