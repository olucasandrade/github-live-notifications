# PLAN — GitHub Live Notifications

macOS menu-bar app that polls GitHub every ~10 minutes and shows **filtered, useful** notifications. No backend, no webhooks.

**Repo:** https://github.com/olucasandrade/github-live-notifications  
**License:** MIT · **Deploy:** build-from-source (notarization later) · **macOS 13+**

## Deterministic check

```bash
bash scripts/check.sh
```

→ `scripts/xcode-check.sh` → `swift test` (Core). When `GitHubLiveNotifications.xcodeproj` exists, CI also runs `xcodebuild test` on `macos-14`.

## Locked decisions (from grill)

| Area | Decision |
|---|---|
| Auth | Classic PAT (`notifications`+`repo`+`read:user`), Keychain service `com.lucasandrade.GitHubLiveNotifications.pat` |
| Bundle ID | `com.lucasandrade.GitHubLiveNotifications` |
| App chrome | `LSUIElement` accessory; `MenuBarExtra` `.window`; Launch at Login via `SMAppService` |
| Stack | Swift 5.9 / Xcode 15+; **async/await** (no Combine unless required); SwiftUI |
| API | Single `GET /notifications?all=false` (≤2 pages / 100 threads), filter reasons client-side; ETag; honor `X-Poll-Interval` |
| Repo polls | stars + open PRs + open issues (skip issue PR dupes); ≤50 repos (default preselect ≤20 owned non-fork non-archived); concurrency 4 |
| Reasons | Full set, each toggleable — see sections below |
| Sections | My work / Activity / CI & security / New on my repos / Stars |
| Noise | Exclude self, bots list + `type==Bot`, drafts; Include bots/drafts checkboxes |
| Stars | Count delta only; no unstar banners; Stars **badge-only** by default |
| Baseline | Silent first fetch + summary “Now monitoring N repos…” |
| Mark read | PATCH threads; local dismiss for synthetic; Mark all does both |
| Banners | Global + per-category; high-signal ON; `comment`/`state_change`/`manual`/`subscribed`/`ci_activity`/Stars OFF |
| Cache | 1k thread IDs FIFO; 200 PR/issue IDs/repo; wipe on unselect/sign-out |
| Host | `api.github.com` only (pluggable base URL internal) |
| Privacy | No telemetry; redacted in-memory debug export |
| OSS docs | LICENSE, README, SECURITY.md, CONTRIBUTING.md |
| Sandbox | On |
| Tests | Unit tests for pure logic; no UI tests in v1 |
| UI | Follow `docs/UI-SPEC.md` |

### Menu sections ↔ reasons

- **My work:** `author`, `review_requested`, `assign`, `mention`, `team_mention`
- **Activity:** `comment`, `state_change`, `manual`, `subscribed`
- **CI & security:** `ci_activity`, `security_alert`
- **New on my repos** / **Stars:** synthetic diffs

### Polling

- Base interval 10 min + 0–30s jitter (scheduled only)
- Notifications additionally delayed by `X-Poll-Interval`
- Manual refresh: repo polls always; notifications only if interval allows
- Stale chip if no success in 20 min

### Built-in bots

`dependabot[bot]`, `renovate[bot]`, `github-actions[bot]`, `greenkeeper[bot]`, `imgbot[bot]`, `prettier[bot]`, `linkedin-app[bot]`, `codecov[bot]`, `sonarcloud[bot]`, `snyk-bot` + `user.type == Bot`

---

## Architecture

```
Package.swift                    # GHNCore library + GHNCoreTests
Sources/GHNCore/                 # models, filter, cache, API client, poller
Tests/GHNCoreTests/
GitHubLiveNotifications/         # macOS app (SwiftUI) — after M1
GitHubLiveNotifications.xcodeproj
docs/UI-SPEC.md
```

Rate-limit math (README): 1 notifications poll × 6/h + ≤50 repos × 3 × 6/h = ≤906/h worst case before ETag 304s; well under 5000.

---

## Milestones & tasks

### M0 — Core package skeleton

| ID | Task | Deps | Acceptance |
|---|---|---|---|
| T0.1 | Package.swift + empty `GHNCore` + `swift test` green | — | `swift test` exits 0 |
| T0.2 | Domain models: `NotificationReason`, `InboxSection`, `InboxItem`, `MonitoredRepo` | T0.1 | Codable/Equatable; unit tests for reason→section mapping |
| T0.3 | Bot list + noise predicates | T0.2 | Tests: self/bot/draft excluded; Include-bots flips |
| T0.4 | Cache store protocol + UserDefaults impl (IDs, stars, ETags, pruning) | T0.2 | Tests: FIFO 1k, 200/repo, wipe repo |

### M1 — GitHub API client

| ID | Task | Deps | Acceptance |
|---|---|---|---|
| T1.1 | `GitHubClient` URLSession + ETag + 304 + `X-Poll-Interval` parse | T0.1 | Fixture tests with `URLProtocol` stub |
| T1.2 | Auth header + 401/403 invalid-token + rate-limit backoff parse | T1.1 | Tests for error mapping |
| T1.3 | Endpoints: user, notifications (paginated ≤2), repos list, repo meta, pulls, issues | T1.1 | Stubbed success paths |
| T1.4 | `html_url` resolver + threadId cache | T1.3 | Tests for API→HTML fallback |

### M2 — Poller & diff engine

| ID | Task | Deps | Acceptance |
|---|---|---|---|
| T2.1 | Reason filter + enabled-toggles | T0.2 | Tests for kitchen-sink matrix |
| T2.2 | Baseline vs diff for threads, PR/issue IDs, star deltas | T0.4 T2.1 | First run silent; second run emits; decrease silent |
| T2.3 | `PollingService` schedule 10m + jitter + concurrency 4 + cancel | T1.3 T2.2 | Unit tests with fake clock/client |
| T2.4 | Mark-read + dismiss synthetic + mark-all | T1.3 T0.4 | Tests |

### M3 — App shell + Keychain

| ID | Task | Deps | Acceptance |
|---|---|---|---|
| T3.1 | Xcode macOS app target, sandbox entitlements, `LSUIElement`, bundle ID | T0.1 | `xcodebuild build` on CI |
| T3.2 | Keychain PAT store (`WhenUnlocked`) | T3.1 | Round-trip test or small integration harness |
| T3.3 | First-launch PAT sheet per UI-SPEC + `/user` validate | T3.2 T1.2 | Manual AC listed; compile |
| T3.4 | Update CI to `macos-14` + xcodebuild; wire check.sh | T3.1 | CI green on PR |

### M4 — Menu panel UI (UI-SPEC)

| ID | Task | Deps | Acceptance |
|---|---|---|---|
| T4.1 | Design tokens + double-bezel containers | T3.1 | Compiles; preview OK |
| T4.2 | `MenuBarExtra` window: header signal strip + footer | T4.1 T2.3 | Compiles; shows stale/error states |
| T4.3 | Sectioned inbox list (20 cap, empty state) | T4.2 T2.2 | Compiles; binds to store |
| T4.4 | Badge count 99+; row click open URL; mark read | T4.3 T1.4 T2.4 | Compiles |

### M5 — Settings + notifications + polish

| ID | Task | Deps | Acceptance |
|---|---|---|---|
| T5.1 | Settings window groups per UI-SPEC | T3.3 T4.1 | Compiles |
| T5.2 | Repo picker (filters, cap 50, defaults) | T5.1 T1.3 | Compiles |
| T5.3 | Banner toggles + `UserNotifications` bridge + defaults table | T5.1 T2.2 | Compiles; defaults match PLAN |
| T5.4 | Launch at Login, debug export redaction, About | T5.1 | Compiles; redaction tests for `ghp_` |
| T5.5 | README (architecture, rate math, PAT setup, troubleshoot) + LICENSE + SECURITY + CONTRIBUTING | T3.4 | Files present; links valid |

---

## Out of scope (v1)

Multi-account, Enterprise UI field, Sparkle, App Store, fine-grained PAT, follower alerts, UI tests, custom mute-list editor, resolving individual stargazers.
