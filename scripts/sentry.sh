#!/usr/bin/env bash
# Sentry unresolved issues (last 24h) grouped by project, loudest first.
# usage: sentry.sh [--org <slug>] [--url https://sentry.io]
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$DIR/../secrets.env" ]] && . "$DIR/../secrets.env"

ORG="${SENTRY_ORG:-}"
BASE="${SENTRY_URL:-https://sentry.io}"
BASE="${BASE%/}"
while [[ $# -gt 1 ]]; do
  case "$1" in --org) ORG="$2" ;; --url) BASE="$2" ;; esac
  shift 2
done

if [[ -z "${SENTRY_TOKEN:-}" || -z "$ORG" ]]; then
  echo '{"error":"Need SENTRY_TOKEN and SENTRY_ORG — see secrets.env.example","groups":[],"total":0}'
  exit 0
fi

DATA=$(curl -fsS --max-time 12 -H "Authorization: Bearer $SENTRY_TOKEN" \
  "$BASE/api/0/organizations/$ORG/issues/?query=is%3Aunresolved&statsPeriod=24h&limit=100&sort=freq" 2>/dev/null || echo '[]')

python3 - "$DATA" <<'PYEOF'
import json, sys, collections

try:
    issues = json.loads(sys.argv[1])
    if not isinstance(issues, list):
        issues = []
except Exception:
    issues = []

groups = collections.OrderedDict()
total = 0
for i in issues:
    proj = ((i.get("project") or {}).get("name")) or "?"
    item = {
        "title": i.get("title") or i.get("culprit") or "unknown",
        "count": int(i.get("count") or 0),
        "level": i.get("level") or "",
        "url": i.get("permalink") or "",
        "lastSeen": i.get("lastSeen") or "",
        "culprit": i.get("culprit") or "",
    }
    groups.setdefault(proj, []).append(item)
    total += item["count"]

out = [{"project": k, "issues": v} for k, v in groups.items()]
print(json.dumps({"groups": out, "total": total}))
PYEOF
