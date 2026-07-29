# Security Policy

## Reporting a vulnerability

**Do not open a public issue for security reports.** Use GitHub's private advisory flow instead:

- Open a private report at <https://github.com/olucasandrade/github-live-notifications/security/advisories/new>

We'll acknowledge and respond as quickly as we can. Reports affecting the handling of personal access tokens are treated with the highest priority.

## Personal access token (PAT) handling

The app requires a **classic PAT** with `notifications` + `repo` + `read:user` scopes. How it is protected:

- Stored only in the macOS Keychain, service `com.lucasandrade.GitHubLiveNotifications.pat`, with `WhenUnlocked` accessibility — never on disk in plaintext, never in UserDefaults, never in logs.
- Sent only in the `Authorization` header to `api.github.com`. There is no backend and no third-party endpoint.
- Never logged. `Authorization` headers, PATs, and notification bodies must never appear in log output — contributions that add logging must respect this (see [CONTRIBUTING.md](CONTRIBUTING.md)).
- The in-memory debug export redacts `ghp_`, `gho_`, and `github_pat_` values.

If you believe a token has leaked through this app (in logs, exports, crash reports, or anywhere else), revoke it immediately at <https://github.com/settings/tokens> and report it via the advisory path above.

## Scope

This repository is the only supported deployment: build-from-source on macOS 13+. There are no versioned releases yet; security fixes land on `main`.

## Privacy posture

- No telemetry, analytics, or crash-reporting SDKs.
- The only network traffic is HTTPS to `api.github.com`.
- The app runs sandboxed.
