#!/bin/bash
# Finds all repos in the openshift GitHub org that have a top-level
# boilerplate/ directory, reads their update.cfg to determine which
# conventions they subscribe to, and outputs subscribers.yaml format.
#
# Requires: gh (GitHub CLI), authenticated
#
# Usage: ./find-subscribers.sh > subscribers.yaml

set -euo pipefail

echo "# List of repositories in openshift org with a boilerplate/ directory."
echo "# Generated on $(date +%Y-%m-%d)."
echo ""
echo "subscribers:"

# Page through all non-fork, non-archived repos in the org
gh repo list openshift --no-archived --source --limit 9999 --json name --jq '.[].name' | sort | while read -r repo; do
  # Check if a top-level boilerplate/ directory exists on the default branch
  if ! gh api "repos/openshift/${repo}/contents/boilerplate" --silent 2>/dev/null; then
    continue
  fi

  echo "  Found: openshift/${repo}" >&2

  # Fetch update.cfg to determine which conventions this repo subscribes to
  conventions=()
  cfg=$(gh api "repos/openshift/${repo}/contents/boilerplate/update.cfg" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null || true)

  if [[ -n "$cfg" ]]; then
    while read -r line; do
      # Strip comments and whitespace
      line="${line%%#*}"
      line="$(echo "$line" | xargs 2>/dev/null || true)"
      [[ -n "$line" ]] && conventions+=("$line")
    done <<< "$cfg"
  fi

  # If we couldn't read update.cfg or it was empty, mark as unknown
  if [[ ${#conventions[@]} -eq 0 ]]; then
    conventions=("unknown")
  fi

  echo "  - name: openshift/${repo}"
  echo "    conventions:"
  for conv in "${conventions[@]}"; do
    echo "      - name: ${conv}"
    echo "        status: manual"
  done
  echo ""
done
