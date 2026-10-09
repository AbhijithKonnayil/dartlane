#!/usr/bin/env bash
# Creates the Dartlane labels, milestones and issues on GitHub from docs/github-plan.md.
#
# Requirements: GitHub CLI (`gh`), authenticated: `gh auth login`
# Usage:
#   DRY_RUN=1 ./tool/create_github_issues.sh   # print what would be created
#   ./tool/create_github_issues.sh             # create labels, milestones, issues
#   PLAN=path/to/plan.md ./tool/create_github_issues.sh
# Safe to re-run: issues whose exact title already exists are skipped.
# The plan format is described at the top of the plan file.

set -euo pipefail

REPO="${REPO:-AbhijithKonnayil/dartlane}"
DRY_RUN="${DRY_RUN:-0}"
PLAN="${PLAN:-$(cd "$(dirname "$0")/.." && pwd)/docs/github-plan.md}"

[ -f "$PLAN" ] || { echo "Plan file not found: $PLAN"; exit 1; }

if [ "$DRY_RUN" != "1" ]; then
  command -v gh >/dev/null || { echo "gh CLI not found. Install it from https://cli.github.com"; exit 1; }
  gh auth status >/dev/null 2>&1 || { echo "Run 'gh auth login' first."; exit 1; }
  EXISTING="$(gh issue list --repo "$REPO" --state all --limit 1000 --json title --jq '.[].title')"
else
  EXISTING=""
fi

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  printf '%s' "${s%"${s##*[![:space:]]}"}"
}

label() { # name color description
  [ "$DRY_RUN" = "1" ] && { echo "label: $1"; return; }
  gh label create "$1" --color "$2" --description "$3" --force --repo "$REPO" >/dev/null
}

milestone() { # title description
  [ "$DRY_RUN" = "1" ] && { echo "milestone: $1"; return; }
  gh api "repos/$REPO/milestones" -f title="$1" -f description="$2" >/dev/null 2>&1 || true
}

issue() { # milestone labels title body
  local ms="$1" labels="$2" title="$3" body="$4"
  if [ "$DRY_RUN" = "1" ]; then echo "[$ms] ($labels) $title"; return; fi
  if printf '%s\n' "$EXISTING" | grep -Fxq -- "$title"; then echo "skip (exists): $title"; return; fi
  gh issue create --repo "$REPO" --title "$title" --body "$body" --label "$labels" --milestone "$ms" >/dev/null
  echo "created: $title"
}

section="" ms="" title="" labels="" body=""

flush_issue() {
  [ -n "$title" ] && issue "$ms" "$labels" "$title" "$body"
  title="" labels="" body=""
}

parse_row() { # sets F1 F2 F3 from "- a | b | c"
  local a b c
  IFS='|' read -r a b c <<<"${1#- }"
  F1="$(trim "$a")" F2="$(trim "$b")" F3="$(trim "${c:-}")"
}

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    "#### "*) flush_issue; title="${line#\#\#\#\# }"; title="${title#\#[0-9]* }" ;;
    "### "*)  flush_issue; ms="${line#\#\#\# }" ;;
    "## "*)   flush_issue; section="${line#\#\# }" ;;
    "- "*)
      case "$section" in
        Labels)     parse_row "$line"; label "$F1" "$F2" "$F3"; continue ;;
        Milestones) parse_row "$line"; milestone "$F1" "$F2"; continue ;;
      esac
      [ -n "$title" ] && body+="$line"$'\n'
      ;;
    *)
      [ "$section" = "Issues" ] && [ -n "$title" ] || continue
      if [ -z "$labels" ] && [[ "$line" == "Labels: "* ]]; then
        labels="$(trim "${line#Labels: }")"
      elif [ -n "$body" ] || [ -n "$line" ]; then
        body+="$line"$'\n'
      fi
      ;;
  esac
done <"$PLAN"
flush_issue

echo "done."
