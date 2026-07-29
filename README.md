# GitHub Live Notifications

A macOS menu-bar app that polls GitHub every ~10 minutes and shows **filtered, useful** notifications. No backend, no webhooks — your token never leaves your Mac.

- **macOS 13+** · Swift 5.9 · SwiftUI · async/await
- **License:** [MIT](LICENSE) · **Deploy:** build from source (notarization later)
- **Privacy:** no telemetry; the PAT lives in the Keychain

## Features

- **Filtered inbox, not a firehose.** Notifications are grouped into sections — *My work*, *Activity*, *CI & security*, *New on my repos*, and *Stars* — and each GitHub notification reason (`author`, `review_requested`, `assign`, `mention`, `team_mention`, `comment`, `state_change`, `manual`, `subscribed`, `ci_activity`, `security_alert`) is individually toggleable.
- **Noise suppression by default.** Your own activity, a built-in bot list (`dependabot[bot]`, `renovate[bot]`, `github-actions[bot]`, … plus `user.type == Bot`), and draft PRs are excluded. Bots and drafts can be re-enabled with checkboxes.
- **Repo diffs for your own repos.** Star-count deltas (badge-only by default — no unstar banners) and new PR/issue detection across up to 50 monitored repos.
- **Respectful polling.** Base interval 10 minutes + 0–30 s jitter, ETag/304 caching, and honoring GitHub's `X-Poll-Interval`. A stale chip appears if no successful fetch in 20 minutes.
- **Silent baseline.** The first fetch never notifies — it just establishes a baseline and shows "Now monitoring N repos…".

## Requirements

- macOS 13 or later
- Xcode 15+ (or Command Line Tools for the Core package only)

## Architecture

```
Package.swift                    # GHNCore library + GHNCoreTests
Sources/GHNCore/                 # models, filter, cache, API client, poller
Tests/GHNCoreTests/
GitHubLiveNotifications/         # macOS app (SwiftUI, MenuBarExtra .window)
GitHubLiveNotifications.xcodeproj
docs/UI-SPEC.md
```

All logic — models, reason filtering, diffing, caching, the GitHub API client, and the polling service — lives in the SPM package `GHNCore` so it is testable with plain `swift test`. The app target is a thin SwiftUI shell (`LSUIElement` accessory app, `MenuBarExtra` with `.window` style, Launch at Login via `SMAppService`).

```
┌─────────────────────────────────────────────────────┐
│ GitHubLiveNotifications (SwiftUI app shell)         │
│  MenuBarExtra · Settings · banners (UserNotifications)│
└───────────────────────┬─────────────────────────────┘
                        │ pure Swift types
┌───────────────────────▼─────────────────────────────┐
│ GHNCore (SPM package, fully unit-tested)            │
│  PollingService → GitHubClient (ETag, 304,          │
│  X-Poll-Interval) → diff engine → cache store       │
│  (UserDefaults: 1k thread IDs FIFO, 200 IDs/repo)   │
└───────────────────────┬─────────────────────────────┘
                        │ HTTPS
                  api.github.com
```

The GitHub client makes a single `GET /notifications?all=false` (at most 2 pages / 100 threads) and filters reasons client-side. Repo polls fetch stars + open PRs + open issues per monitored repo with concurrency 4.

## Rate-limit math

Worst case per hour, before ETag 304s:

```
1 notifications poll × 6/h        =   6 requests
≤50 repos × 3 endpoints × 6/h     ≤ 900 requests
                                  ─────────────
                                    ≤ 906/h
```

Well under the 5,000 requests/hour authenticated limit — and ETag caching plus `X-Poll-Interval` make the real number far lower.

## Personal access token (PAT) setup

1. Go to <https://github.com/settings/tokens> → **Generate new token (classic)**.
2. Select exactly these scopes: **`notifications`**, **`repo`**, **`read:user`**.
3. On first launch, paste the token into the app's setup sheet. It is validated with `GET /user` and stored in the Keychain (service `com.lucasandrade.GitHubLiveNotifications.pat`, `WhenUnlocked` accessibility).

The token is used only for the `Authorization` header against `api.github.com`. It is never logged, never sent anywhere else, and `ghp_` / `gho_` / `github_pat_` values are redacted in the in-memory debug export. Fine-grained PATs are out of scope for v1.

## Build & run

```bash
# Core package (logic + tests)
swift test

# Full app (after the .xcodeproj exists)
open GitHubLiveNotifications.xcodeproj
```

The deterministic check that decides whether work is done:

```bash
bash scripts/check.sh
```

This runs `swift test` on the Core package, and `xcodebuild test` for the app target when the `.xcodeproj` exists.

## Troubleshooting

- **"Invalid token" after pasting the PAT.** The app validates with `GET /user`. Re-check that the token is a *classic* PAT with `notifications` + `repo` + `read:user` scopes, hasn't expired, and was pasted without whitespace. Deleting the token in Settings and re-entering it resets the state.
- **No notifications appear on first launch.** That's by design: the first fetch is a silent baseline. New items appear from the second poll onward.
- **Stale chip in the header.** No successful fetch in 20 minutes. Check network connectivity; if GitHub rate-limited the app, polling backs off automatically (rate-limit backoff is parsed from response headers) and resumes.
- **Updates seem delayed.** GitHub's `X-Poll-Interval` header can delay the notifications poll beyond the 10-minute base interval; manual refresh re-fetches repo data but only polls notifications when the interval allows.
- **Too noisy / too quiet.** Every notification reason and banner category is individually toggleable in Settings; bots and drafts are excluded unless you opt in.
- **Repo diffs missing for a repo.** Only ≤50 repos can be monitored (≤20 owned, non-fork, non-archived are preselected). Unselecting a repo wipes its cached diff state.

## Docs

- Product decisions: [docs/PLAN.md](docs/PLAN.md) (locked)
- UI spec: [docs/UI-SPEC.md](docs/UI-SPEC.md)
- Contributing: [CONTRIBUTING.md](CONTRIBUTING.md)
- Security: [SECURITY.md](SECURITY.md)
