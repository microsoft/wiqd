#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#
# wiqd — Public feedback label provisioner
#
# Creates (or updates, via --force) the fixed set of labels that
# `wiqd feedback submit` applies to issues it creates. Safe to re-run: every
# label is created with --force, so an existing label is just updated in
# place rather than causing an error.
#
# Usage:
#   ./provision-labels.sh                     # provisions microsoft/wiqd
#   ./provision-labels.sh --repo owner/name   # provisions a different repo
#   ./provision-labels.sh --dry-run           # prints the plan, runs nothing
#
# Requires: gh (GitHub CLI), authenticated with repo-admin access to the
# target repo (`gh auth status`).

set -euo pipefail

repo="microsoft/wiqd"
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      repo="$2"
      shift 2
      ;;
    --repo=*)
      repo="${1#--repo=}"
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--repo owner/name] [--dry-run]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

echo ""
echo "wiqd feedback label provisioner"
echo "  Target repo: ${repo}"

if ! command -v gh >/dev/null 2>&1; then
  echo "  ERROR: GitHub CLI (gh) was not found on PATH. Install it from https://cli.github.com and re-run." >&2
  exit 2
fi

# name|color|description — kept in sync with the label set that
# packages/wiqd-ext-github/src/feedback-submit.ts passes to `gh issue create`.
labels=(
  "feedback|006B75|Feedback submitted via wiqd feedback submit"
  "cli-submitted|5319E7|Submitted automatically by the wiqd CLI"
  "bug|D73A4A|Something is not working"
  "feature-request|1D76DB|Request for a new feature or capability"
  "enhancement|A2EEEF|Improvement to existing functionality"
  "question|D876E3|Question about wiqd usage or behavior"
  "documentation|0075CA|Improvement or correction to documentation"
  "performance|FBCA04|Performance or responsiveness issue"
  "sentiment:positive|0E8A16|Positive sentiment reported with the feedback"
  "sentiment:negative|B60205|Negative sentiment reported with the feedback"
)

if [[ "${dry_run}" -eq 1 ]]; then
  echo "  Dry run: no changes will be made."
  echo ""
  for entry in "${labels[@]}"; do
    IFS='|' read -r name color description <<<"${entry}"
    echo "    would create/update '${name}' (color #${color}): ${description}"
  done
  exit 0
fi

# Only stdout is redirected here — stderr flows to the terminal so real gh
# error text (e.g. an expired token) is never hidden from the operator.
if ! gh auth status --hostname github.com >/dev/null; then
  echo "  ERROR: gh is not authenticated. Run 'gh auth login' first, then re-run this script." >&2
  exit 1
fi

failure_count=0
for entry in "${labels[@]}"; do
  IFS='|' read -r name color description <<<"${entry}"
  if gh label create "${name}" --repo "${repo}" --color "${color}" --description "${description}" --force >/dev/null; then
    echo "  Provisioned '${name}'"
  else
    echo "  ERROR: Failed to provision '${name}'" >&2
    failure_count=$((failure_count + 1))
  fi
done

if [[ "${failure_count}" -gt 0 ]]; then
  echo "  ERROR: ${failure_count} of ${#labels[@]} labels failed to provision." >&2
  exit 1
fi

echo ""
echo "All ${#labels[@]} feedback labels are provisioned on ${repo}."
exit 0
