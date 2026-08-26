#!/usr/bin/env bash
# GitHub open issues + PRs for an owner (user or org), via gh search.
# usage: issues.sh [--owner <login>]   (defaults to the authenticated user)
set -u
OWNER=""
while [[ $# -gt 1 ]]; do
  case "$1" in --owner) OWNER="$2" ;; esac
  shift 2
done

if [[ -z "$OWNER" ]]; then
  # tail -n 1: some shells emit tool-init noise (mise) on stdout
  OWNER=$(gh api user -q .login 2>/dev/null | tail -n 1)
fi
if [[ -z "$OWNER" ]]; then
  echo '{"error":"gh not authenticated — run gh auth login","rows":[]}'
  exit 0
fi

DATA=$(gh search issues --owner "$OWNER" --limit 100 --state open --include-prs \
  --json title,url,number,repository,updatedAt 2>/dev/null)

if [[ "$DATA" != *"["* ]]; then
  echo '{"error":"gh search failed — is gh authenticated (gh auth login)?","rows":[]}'
  exit 0
fi

python3 - "$DATA" <<'PYEOF'
import json, sys

raw = sys.argv[1]
# Some shells emit tool-init noise (e.g. mise) on stdout before the JSON.
lines = raw.splitlines()
start = next((i for i, l in enumerate(lines) if l.startswith("[")), None)
items = []
if start is not None:
    try:
        items = json.loads("\n".join(lines[start:]))
    except Exception:
        items = []

rows = [{
    "repo": (i.get("repository") or {}).get("nameWithOwner") or "?",
    "title": i.get("title") or "",
    "num": i.get("number") or 0,
    "url": i.get("url") or "",
    "updated": i.get("updatedAt") or "",
    "pr": "/pull/" in (i.get("url") or ""),
} for i in items]

rows.sort(key=lambda r: r["updated"], reverse=True)
print(json.dumps({"rows": rows}))
PYEOF
