#!/usr/bin/env bash
# Deterministic gate for GitHub Live Notifications.
# M0+: `swift test` on the Core package (works with CLT).
# After the app target exists, CI also runs xcodebuild (see AGENTS.md).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> swift test (Core)"
swift test --package-path .

if [[ -d GitHubLiveNotifications.xcodeproj ]]; then
  if xcodebuild -version >/dev/null 2>&1; then
    echo "==> xcodebuild test (App)"
    xcodebuild \
      -project GitHubLiveNotifications.xcodeproj \
      -scheme GitHubLiveNotifications \
      -destination 'platform=macOS' \
      -quiet \
      test
  elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "error: Xcode.app required in CI but xcodebuild is unavailable" >&2
    exit 1
  else
    echo "warning: Xcode.app not available locally; skipping app build (CI will run it)"
  fi
fi
