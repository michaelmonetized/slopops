#!/usr/bin/env bash
# Fleet probe: tailscale peers + TCP service checks.
# usage: fleet.sh [--ports "22,5900"] [--t3-port 3773]
set -u
PORTS="22,5900"
T3=3773
while [[ $# -gt 1 ]]; do
  case "$1" in
    --ports) PORTS="$2" ;;
    --t3-port) T3="$2" ;;
  esac
  shift 2
done
exec python3 - "$PORTS" "$T3" <<'PYEOF'
import json, socket, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

ports = [int(p) for p in sys.argv[1].split(",") if p.strip().isdigit()]
t3port = int(sys.argv[2]) if sys.argv[2].strip().isdigit() else 0

try:
    raw = subprocess.run(["tailscale", "status", "--json"],
                         capture_output=True, text=True, timeout=10)
    data = json.loads(raw.stdout or "{}")
except Exception as e:
    print(json.dumps({"error": f"tailscale status failed: {e}", "peers": []}))
    raise SystemExit

def probe(ip, port):
    try:
        s = socket.create_connection((ip, port), timeout=1.5)
        s.close()
        return True
    except Exception:
        return False

self_id = (data.get("Self") or {}).get("ID", "")
peers = [data.get("Self") or {}] + list((data.get("Peer") or {}).values())
seen = set()
out = []

for d in peers:
    pid = d.get("ID", "")
    if not d or pid in seen:
        continue
    seen.add(pid)
    ips = d.get("TailscaleIPs") or []
    ip = ips[0] if ips else ""
    online = bool(d.get("Online"))
    row = {
        "name": d.get("HostName") or (d.get("DNSName") or "?").split(".")[0],
        "ip": ip,
        "online": online,
        "self": pid == self_id,
        "services": {str(p): False for p in ports},
    }
    if online and ip:
        futures = {}
        with ThreadPoolExecutor(max_workers=max(2, len(ports) + 1)) as ex:
            for p in ports:
                futures[ex.submit(probe, ip, p)] = p
            if t3port > 0:
                futures[ex.submit(probe, ip, t3port)] = "t3"
            for f, key in futures.items():
                if key == "t3":
                    row["t3"] = f.result()
                else:
                    row["services"][str(key)] = f.result()
    elif t3port > 0:
        row["t3"] = False
    out.append(row)

out.sort(key=lambda r: (not r["online"], r["name"].lower()))
print(json.dumps({"peers": out}))
PYEOF
