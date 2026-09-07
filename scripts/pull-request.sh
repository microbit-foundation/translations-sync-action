#!/usr/bin/env bash
# (c) 2026, Micro:bit Educational Foundation and contributors
# SPDX-License-Identifier: MIT
#
# Commits whatever the download changed, force-pushes it to the sync branch
# with the App token, and opens or refreshes the pull request.
# Inputs: GH_TOKEN, APP_SLUG, BRANCH, BASE, TITLE, BODY, REVIEWER, I18N_SUMMARY.
set -euo pipefail

# Staged first so a new language's file counts as a change.
git add -A
if git diff --cached --quiet; then
  echo "No translation changes."
  exit 0
fi

bot="${APP_SLUG}[bot]"
bot_id=$(gh api "/users/${bot}" --jq .id)
git config user.name "${bot}"
git config user.email "${bot_id}+${bot}@users.noreply.github.com"
git checkout -B "${BRANCH}"
git commit -m "${TITLE}"

# actions/checkout leaves GITHUB_TOKEN in an http.extraheader, which git
# would send in preference to the token in the URL, and a push under
# GITHUB_TOKEN starts no workflows. Recent checkouts keep that header in an
# included file rather than .git/config, so it cannot be unset in place; an
# empty value on the command line resets the header list wherever it lives.
git -c "http.${GITHUB_SERVER_URL}/.extraheader=" push --force \
  "${GITHUB_SERVER_URL/:\/\//://x-access-token:${GH_TOKEN}@}/${GITHUB_REPOSITORY}.git" "${BRANCH}"

body_file="${RUNNER_TEMP}/pr-body.md"
{
  echo "${BODY}"
  if [ -f "${I18N_SUMMARY}" ]; then
    echo
    cat "${I18N_SUMMARY}"
  fi
} > "${body_file}"

if gh pr view "${BRANCH}" --json state --jq .state 2>/dev/null | grep -q OPEN; then
  gh pr edit "${BRANCH}" --body-file "${body_file}"
  echo "Updated the open pull request."
else
  gh pr create --base "${BASE}" --head "${BRANCH}" --title "${TITLE}" --body-file "${body_file}"
  if [ -n "${REVIEWER}" ]; then
    # Through the REST endpoint, which takes a team slug and needs only
    # pull-request write. gh's --reviewer resolves the team first, which
    # needs organisation Members read that the App token does not carry.
    number=$(gh pr view "${BRANCH}" --json number --jq .number)
    if [[ "${REVIEWER}" == */* ]]; then
      field="team_reviewers[]=${REVIEWER#*/}"
    else
      field="reviewers[]=${REVIEWER}"
    fi
    gh api -X POST "repos/${GITHUB_REPOSITORY}/pulls/${number}/requested_reviewers" \
      -f "${field}" --silent
  fi
fi
