# slopops

Tabbed ops panel for the Omarchy bar: one icon, five tabs.

| Tab | Data | Needs |
|---|---|---|
| **Fleet** | Every device on your tailnet with status lights: online, per-port reachability (default `22`, `5900`) and t3 serve | `tailscale` on PATH |
| **Deploys** | All Vercel projects by most recent production deploy; projects with ERROR deploys since their last good one are pinned on top | `VERCEL_TOKEN` |
| **Sentry** | Unresolved issues (24h) grouped by project; `+ issue` button promotes a report into a GitHub issue | `SENTRY_TOKEN`, `SENTRY_ORG`, `gh` |
| **Traffic** | PostHog all-time event total + 30-day daily chart; per-project totals down the right side | `POSTHOG_KEY` |
| **Issues** | GitHub issues matching a search scope (default `assignee:@me`) | `gh auth login` |

The badge dot on the bar: red = failing deployments or Sentry events, yellow = missing tokens / offline peers, green = nominal.

## Setup

```bash
cp secrets.env.example secrets.env
chmod 600 secrets.env        # fill in what you use; tabs degrade gracefully
```

GitHub uses your existing `gh` CLI login — run `gh auth login` once if needed.

## Configuration (per widget)

Everything is a widget setting so one build fits many machines:

```bash
omarchy bar set slopops fleetPorts "22,5900" --json
omarchy bar set slopops t3Port 3773          # 0 hides the t3 light
omarchy bar set slopops sentryOrg acme
omarchy bar set slopops sentryUrl https://sentry.selfhosted.example   # self-hosted
omarchy bar set slopops posthogUrl https://eu.posthog.com
omarchy bar set slopops vercelTeamId team_xxx
omarchy bar set slopops issueRepo me/infra   # where promoted Sentry issues land
omarchy bar set slopops issuesScope "author:@me state:open"
omarchy bar set slopops refreshSeconds 120
```

### Fleet: live T3 Code environments + quick shell

The Fleet tab runs `scripts/t3envs`. Machines come from `tailscale status --json`;
each online machine is asked for its T3 Code status through **that machine's own
T3 MCP server** (streamable HTTP at `<origin>/mcp`, origin read from
`~/.t3/userdata/server-runtime.json`; tools `t3_environment_read`,
`t3_project_list`, `t3_thread_list`). T3 binds loopback, so the MCP call runs on the
machine itself over `ssh -o BatchMode=yes` (locally for this machine) — nothing new
is exposed on the tailnet. The old tab probed port 3773 over the tailnet IP, which
is always closed because T3 listens on 127.0.0.1; that is why the light never worked.

Each row shows online state, `N running · M projects` (threads in
preparing/queued/starting/running/waiting), and lights per port plus `t3`
(green idle, yellow running or needs credential, red down). **Click a row** for a
quick shell: a new terminal (`xdg-terminal-exec`, `$TERMINAL`, ghostty, alacritty,
kitty or foot) with `ssh -t <machine>`, or a local shell for this machine.

```sh
scripts/t3envs list                 # table
scripts/t3envs list --json          # what the tab reads
scripts/t3envs shell m1pro13        # ssh in here
scripts/t3envs shell m1pro13 naarchy  # ssh in and cd to that T3 project's workspace
scripts/t3envs open intelpro        # same, in a new terminal window
```

Credential: a read-only MCP client session (`orchestration:read`, subject
`mcp-client`) stored per machine in `~/.config/slopops/t3-mcp-token` (0600). When it
is missing or rejected, the probe mints one once with
`t3 auth session issue --scope orchestration:read --subject mcp-client --ttl 90d --token-only`.
Pass `--no-mint` (or `T3ENVS_NO_MINT=1`) to only report "needs credential".

SSH: the machine name is tried first (so `~/.ssh/config` Host entries apply), then
its tailnet IP (covers Host entries pinned to a stale LAN address). The probe needs
`python3` on the target, or Node 18+ where python3 is just the Xcode stub (stock macOS).

`t3Port 0` hides the t3 column and skips the probe (the port itself is now read
from each machine's `server-runtime.json`).

## Files

- `Ops.qml` — bar button + tabbed popup
- `tabs/*.qml` — one file per tab
- `scripts/*.sh` — data fetchers (curl / tailscale / gh), JSON out
- `scripts/t3envs` — tailnet machines + live T3 Code status via each machine's MCP server; quick shell
- `secrets.env` — tokens, gitignored, chmod 600

Adding a probe port is a settings change, not a code change: `fleetPorts "22,5900,3389"`.
