#!/usr/bin/env bash
# (c) 2026, Micro:bit Educational Foundation and contributors
# SPDX-License-Identifier: MIT
#
# Runs the repository's download command, publishes its summary, and runs
# the post-download command when there is something to process.
# Inputs: DOWNLOAD, POST_DOWNLOAD, I18N_SUMMARY.
set -uo pipefail

bash -eo pipefail -c "${DOWNLOAD}"
status=$?
echo "status=${status}" >> "${GITHUB_OUTPUT}"

if [ -f "${I18N_SUMMARY}" ]; then
  cat "${I18N_SUMMARY}" >> "${GITHUB_STEP_SUMMARY}"
  if grep -q '^### Translations left out' "${I18N_SUMMARY}"; then
    echo "::warning::Some translations were left out for placeholder problems; see the summary."
  fi
fi

# 2 is a partial download: some files failed, the rest were written and are
# worth a pull request. Anything else non-zero is nothing usable.
if [ "${status}" -ne 0 ] && [ "${status}" -ne 2 ]; then
  echo "::error::The download failed with exit code ${status}."
  exit "${status}"
fi

if [ -n "${POST_DOWNLOAD}" ]; then
  bash -eo pipefail -c "${POST_DOWNLOAD}"
fi
