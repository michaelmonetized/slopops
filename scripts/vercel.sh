#!/usr/bin/env bash
# Vercel deployments grouped by project, most recent first.
# Projects with ERROR deployments since their last successful one are pinned.
# usage: vercel.sh [--team-id <id>]
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$DIR/../secrets.env" ]] && . "$DIR/../secrets.env"

TEAM_ID="${VERCEL_TEAM_ID:-}"
while [[ $# -gt 1 ]]; do
  case "$1" in --team-id) TEAM_ID="$2" ;; esac
  shift 2
done

if [[ -z "${VERCEL_TOKEN:-}" ]]; then
  echo '{"error":"No VERCEL_TOKEN — copy secrets.env.example to secrets.env","rows":[]}'
  exit 0
fi

API="https://api.vercel.com"
TQ=""; [[ -n "$TEAM_ID" ]] && TQ="&teamId=$TEAM_ID"

P=$(curl -fsS --max-time 10 -H "Authorization: Bearer $VERCEL_TOKEN" \
  "$API/v9/projects?limit=100$TQ" 2>/dev/null || echo '{}')
D=$(curl -fsS --max-time 20 -H "Authorization: Bearer $VERCEL_TOKEN" \
  "$API/v6/deployments?limit=300&target=production$TQ" 2>/dev/null || echo '{}')

python3 - "$P" "$D" <<'PYEOF'
import json, sys, time

def human(ms):
    if not ms: return ""
    s = max(0, time.time() - ms / 1000)
    if s < 60: return f"{int(s)}s"
    if s < 3600: return f"{int(s // 60)}m"
    if s < 86400: return f"{int(s // 3600)}h"
    return f"{int(s // 86400)}d"

try:
    projects = json.loads(sys.argv[1]).get("projects", [])
except Exception:
    projects = []
try:
    deployments = json.loads(sys.argv[2]).get("deployments", [])
except Exception:
    deployments = []

names = {p.get("id"): p.get("name") or p.get("slug") or p.get("id") for p in projects}

by_project = {}
for d in deployments:
    by_project.setdefault(d.get("projectId") or d.get("name"), []).append(d)

rows = []
for pid, deps in by_project.items():
    deps.sort(key=lambda x: x.get("createdAt") or 0, reverse=True)
    latest = deps[0]
    last_ok = next((x.get("createdAt") or 0 for x in deps
                    if (x.get("state") or "").upper() == "READY"), None)
    errs_since = sum(1 for x in deps
                     if (x.get("state") or "").upper() == "ERROR"
                     and (last_ok is None or (x.get("createdAt") or 0) > last_ok))
    rows.append({
        "name": names.get(pid) or latest.get("name") or "?",
        "state": (latest.get("state") or "?").upper(),
        "when": human(latest.get("createdAt")),
        "ts": latest.get("createdAt") or 0,
        "url": f"https://{latest['url']}" if latest.get("url") else "",
        "errs": errs_since,
        "pinned": errs_since > 0,
    })

rows.sort(key=lambda r: (not r["pinned"], -r["ts"]))
print(json.dumps({"rows": rows}))
PYEOF
