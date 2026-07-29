# Contributing

Thanks for helping out. This project follows a strict, test-first workflow — please read this before opening a PR.

## Requirements

- macOS 13+
- **Xcode 15+** (Command Line Tools are enough for the `GHNCore` package; the app target needs full Xcode)
- Swift 5.9

## The deterministic check

The command that decides whether work is done:

```bash
bash scripts/check.sh
```

Exit 0 means done. CI runs the same script on every PR, so a PR that doesn't pass it locally won't pass in CI. Never edit `scripts/check.sh` to make work pass.

## TDD protocol

All logic changes are test-driven:

1. Before implementing, write a failing test that encodes the acceptance criteria.
2. Run it and confirm it fails for the **right** reason.
3. Implement the minimum to pass. Run the full suite (`swift test`), not just the new test.
4. Refactor only on green.
5. Never edit a test to make it pass unless the test itself is the bug — and say so explicitly if you believe it is.
6. Done = full suite green + `bash scripts/check.sh` exit 0.

## Workflow

- **Issues are the queue.** An issue labeled `agent:ready` carries acceptance criteria — execute those decisions instead of re-litigating them. If a decision is missing, stop and ask on the issue.
- One issue, one branch (`agent/issue-<N>`), one PR with `Closes #N`. Keep PRs small and scoped to the paths listed in the issue.
- Read the locked product decisions in [docs/PLAN.md](docs/PLAN.md) before changing behavior, and [docs/UI-SPEC.md](docs/UI-SPEC.md) before any SwiftUI work.

## Project conventions

- Core logic lives in the SPM package `GHNCore` (`Sources/GHNCore/`, `Tests/GHNCoreTests/`); the app target under `GitHubLiveNotifications/` is a thin SwiftUI shell.
- async/await only — no Combine unless a system API forces it.
- Unit tests for pure logic; no UI tests in v1.
- **Never log PATs, `Authorization` headers, or notification bodies.** Redact `ghp_` / `gho_` / `github_pat_` in the debug export (see [SECURITY.md](SECURITY.md)).
- No telemetry or new third-party dependencies without discussion on an issue first.

## Reporting security issues

Do not open public issues for vulnerabilities — use the private advisory path described in [SECURITY.md](SECURITY.md).
