#!/usr/bin/env bash
# Writes code=true|false to $GITHUB_OUTPUT: false only when a pull request or push changes nothing but documentation
# (docs/**, Markdown files, issue templates, LICENSE). Expensive jobs use it in their `if`; a job skipped by its `if`
# reports success, so required status checks still pass (a workflow-level path filter would leave them pending).
#
# Needs a checkout with fetch-depth: 2. On pull_request, HEAD is the merge commit and HEAD^1 the tip of the base
# branch. On push, the diff runs against github.event.before (env BEFORE), so rebase merges count every commit.
# Any other event, a new branch or an unreadable base counts as a code change.
set -euo pipefail

DOCS_ONLY='^(docs/|\.github/ISSUE_TEMPLATE/|LICENSE)|\.md$'

base=""
case "${GITHUB_EVENT_NAME:-}" in
  pull_request)
    base="HEAD^1"
    ;;
  push)
    if [[ -n "${BEFORE:-}" && ! "$BEFORE" =~ ^0+$ ]] && git fetch -q --depth=1 origin "$BEFORE"; then
      base="$BEFORE"
    fi
    ;;
esac

code=true
if [[ -n "$base" ]]; then
  changed="$(git diff --name-only "$base" HEAD)"
  printf 'Changed files:\n%s\n' "$changed"
  if [[ -n "$changed" ]] && ! grep -qvE "$DOCS_ONLY" <<<"$changed"; then
    code=false
    echo "Documentation-only change: build, test and image jobs are skipped." >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
  fi
fi

echo "code=$code" | tee -a "${GITHUB_OUTPUT:-/dev/null}"
