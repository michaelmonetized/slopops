#!/usr/bin/env bash
# Promote a Sentry issue to a GitHub issue.
# usage: promote.sh <repo> <title> <url> <culprit> <level> <count>
set -u
REPO="$1"; TITLE="$2"; URL="$3"; CULPRIT="$4"; LEVEL="$5"; COUNT="$6"

BODY=$(printf '%s\n\n' "**Sentry → GitHub**" \
  "- Events: **$COUNT**" \
  "- Level: $LEVEL" \
  "- Culprit: \`$CULPRIT\`" \
  "- Sentry report: $URL")

if gh issue create -R "$REPO" -t "$TITLE" -b "$BODY" > /dev/null 2>&1; then
  notify-send -a "Ops" "Sentry promoted" "Issue created in $REPO"
else
  notify-send -a "Ops" "Promote failed" "Could not create issue in $REPO — check gh auth / repo"
fi
