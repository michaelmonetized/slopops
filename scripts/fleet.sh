#!/usr/bin/env bash
# Back-compat shim: the Fleet tab now uses scripts/t3envs (tailnet + live T3 MCP status).
# usage: fleet.sh [--ports "22,5900"] [--t3-port N]   (N=0 skips the T3 probe)
set -u
PORTS="22,5900"; T3=3773
while [[ $# -gt 1 ]]; do
  case "$1" in --ports) PORTS="$2" ;; --t3-port) T3="$2" ;; esac
  shift 2
done
extra=(); [[ "$T3" == 0 ]] && extra=(--no-t3)
exec python3 "$(dirname "$0")/t3envs" list --json --ports "$PORTS" "${extra[@]}"
