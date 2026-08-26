#!/usr/bin/env bash
# Cheap aggregate for the bar badge: error counts + which creds exist.
# usage: status.sh [--org <slug>] [--url <sentry url>]
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$DIR/../secrets.env" ]] && . "$DIR/../secrets.env"

ORG="${SENTRY_ORG:-}"; SURL="${SENTRY_URL:-}"
while [[ $# -gt 1 ]]; do
  case "$1" in --org) ORG="$2" ;; --url) SURL="$2" ;; esac
  shift 2
done

V=$("$DIR/vercel.sh")
S_ARGS=(); [[ -n "$ORG" ]] && S_ARGS=(--org "$ORG"); [[ -n "$SURL" ]] && S_ARGS+=(--url "$SURL")
S=$("$DIR/sentry.sh" ${S_ARGS[@]+"${S_ARGS[@]}"})

python3 - "$V" "$S" <<'PYEOF'
import json, sys, os

def load(s):
    try:
        return json.loads(s)
    except Exception:
        return {}

v, s = load(sys.argv[1]), load(sys.argv[2])
deploy_errors = sum(1 for r in (v.get("rows") or []) if r.get("pinned"))
sentry_errors = int(s.get("total") or 0)
home = os.path.expanduser("~")
print(json.dumps({
    "deployErrors": deploy_errors,
    "sentryErrors": sentry_errors,
    "creds": {
        "vercel": "error" not in v,
        "sentry": "error" not in s,
        "posthog": bool(os.getenv("POSTHOG_KEY")),
    },
}))
PYEOF
