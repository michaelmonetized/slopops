#!/usr/bin/env bash
# PostHog traffic: all-time event totals + 30-day daily series per project.
# usage: posthog.sh [--url https://us.posthog.com]
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$DIR/../secrets.env" ]] && . "$DIR/../secrets.env"

HOST="${POSTHOG_URL:-https://us.posthog.com}"
while [[ $# -gt 1 ]]; do
  case "$1" in --url) HOST="$2" ;; esac
  shift 2
done

if [[ -z "${POSTHOG_KEY:-}" ]]; then
  echo '{"error":"No POSTHOG_KEY — copy secrets.env.example to secrets.env","projects":[],"total":0,"series":[]}'
  exit 0
fi

exec python3 - "$HOST" "${POSTHOG_KEY}" <<'PYEOF'
import json, sys, urllib.request

host = sys.argv[1].rstrip("/")
key = sys.argv[2]

def api(path, body=None):
    req = urllib.request.Request(
        host + path,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        method="POST" if body is not None else "GET",
    )
    with urllib.request.urlopen(req, timeout=25) as r:
        return json.loads(r.read().decode())

def q(pid, sql):
    res = api(f"/api/projects/{pid}/query/", {"query": {"kind": "HogQLQuery", "query": sql}})
    return res.get("results") or []

try:
    projects = (api("/api/projects/") or {}).get("results") or []
except Exception as e:
    print(json.dumps({"error": f"posthog projects failed: {e}", "projects": [], "total": 0, "series": []}))
    raise SystemExit

out = []
series = []
grand = 0
for p in projects[:12]:
    pid, name = p.get("id"), p.get("name") or str(p.get("id"))
    try:
        total = int(q(pid, "SELECT count() FROM events")[0][0])
        days = q(pid, "SELECT toDate(timestamp) d, count() c FROM events "
                      "WHERE timestamp >= now() - INTERVAL 30 DAY GROUP BY d ORDER BY d")
        daily = {str(r[0]): int(r[1]) for r in days}
        for d, c in daily.items():
            found = False
            for s in series:
                if s["date"] == d:
                    s["count"] += c
                    found = True
                    break
            if not found:
                series.append({"date": d, "count": c})
        grand += total
        out.append({"name": name, "total": total})
    except Exception as e:
        out.append({"name": name, "total": 0, "error": str(e)})

series.sort(key=lambda s: s["date"])
out.sort(key=lambda x: -x.get("total", 0))
print(json.dumps({"projects": out, "total": grand, "series": series}))
PYEOF
