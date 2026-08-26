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

`t3Port` probes each peer's t3 Code server over its tailnet IP (the light is green
when `t3 serve`/connect is reachable from this machine).

## Files

- `Ops.qml` — bar button + tabbed popup
- `tabs/*.qml` — one file per tab
- `scripts/*.sh` — data fetchers (curl / tailscale / gh), JSON out
- `secrets.env` — tokens, gitignored, chmod 600

Adding a probe port is a settings change, not a code change: `fleetPorts "22,5900,3389"`.
