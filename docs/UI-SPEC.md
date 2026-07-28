# UI-SPEC — GitHub Live Notifications

> **Design read:** native macOS menu-bar utility for developers, calm Primer-adjacent developer-tool language, single signal-green accent, SF Pro + SF Mono, materials — not a web landing page.
>
> **Dials (adapted from design-taste for a dense inbox utility):** `DESIGN_VARIANCE: 5` · `MOTION_INTENSITY: 4` · `VISUAL_DENSITY: 7`

Web landing archetypes (heroes, bento, marquees) are **out of scope**. Apply taste as: anti-slop color/type/motion, one accent, no purple glow, no emoji, real empty/loading/error states, motivated micro-motion only.

---

## 1. Visual system

### 1.1 Color tokens (SwiftUI / Asset Catalog)

| Token | Light | Dark | Role |
|---|---|---|---|
| `surface.canvas` | `NSColor.windowBackgroundColor` | same (system) | Panel + Settings root |
| `surface.elevated` | white 92% / material | black elev. material | Nested groups (double-bezel inner) |
| `surface.hairline` | black 8% | white 10% | Separators, outer bezel ring |
| `text.primary` | label | label | Titles |
| `text.secondary` | secondaryLabel | secondaryLabel | Repo · reason · relative time |
| `text.tertiary` | tertiaryLabel | tertiaryLabel | Meta, “stale” |
| `accent.signal` | `#1A7F37` | `#3FB950` | Single accent: unread pip, primary buttons, focus |
| `state.danger` | system red | system red | Invalid token, rate-limit hard fail |
| `state.warn` | system orange | system orange | Stale chip |

**Banned:** purple/violet accents, neon glows, rainbow per-category colors, pure `#000` / `#FFF` fills.

Categories differentiate with **SF Symbol + weight**, not a rainbow.

### 1.2 Typography

| Role | Font | Size / weight |
|---|---|---|
| Brand (Settings header only) | SF Pro Rounded | 22 semibold |
| Panel title / section | SF Pro | 13 semibold |
| Row title | SF Pro | 13 regular |
| Meta (repo, reason) | SF Pro | 11 regular, secondary |
| Counts / timestamps / badge | **SF Mono** | 11 medium |
| Empty-state headline | SF Pro | 15 medium |

No Inter/Geist bundling — system fonts are the premium native choice.

### 1.3 Shape & material

- **Corner radius scale (one system):** panel outer `14`, inner groups `10`, pills/chips `6`, icon wells `7`.
- **Double-bezel** for the menu panel chrome and each Settings group:
  - Outer: hairline ring + 1.5pt pad + soft fill
  - Inner: `.regularMaterial` (panel) / `.ultraThinMaterial` (header strip)
- **No card stacks** for notification rows — use `Divider` / hairline `List` rows.
- Menu bar icon: SF Symbol `bell.fill` (template); badge via `MenuBarExtra` label count.

### 1.4 Motion (motivated only)

| Event | Motion |
|---|---|
| Panel open | Content fade+rise 12pt, 280ms, `spring(response: 0.32, dampingFraction: 0.86)` |
| New row insert | Asymmetric transition; respect `accessibilityReduceMotion` → opacity only |
| Badge count change | Content transition on the numeric Text |
| Polling | Header “signal” pip breathes opacity 0.4↔1 while `isPolling` (disable under reduce motion) |
| Button press | `scaleEffect(0.98)` on press |

No perpetual marquees, no parallax, no custom cursors.

---

## 2. Menu bar panel (`MenuBarExtra` `.window`)

**Size:** width `360`, height min `280` / max `520` (scroll).

### 2.1 Header (signal strip)

```
[●] Updated 3m ago          [↻]
    or: Stale · 23m ago
    or: Invalid token
    or: Rate limited · resumes 14:02
```

- Leading **signal pip** (accent) — breathing while polling.
- Trailing refresh (disabled with tooltip if notifications `X-Poll-Interval` blocks).
- One line of status copy; never two competing banners.

### 2.2 Body sections (hide if empty)

Order:

1. **My work** — `author`, `review_requested`, `assign`, `mention`, `team_mention`
2. **Activity** — `comment`, `state_change`, `manual`, `subscribed`
3. **CI & security** — `ci_activity`, `security_alert`
4. **New on my repos**
5. **Stars**

Section header: symbol + title + mono count. Max **20 rows**; then “N more on GitHub…”.

**Row anatomy (single line + meta):**

```
● Title of the PR or issue
  owner/repo · mention · 2m
```

- Leading unread pip (accent) only if unread/undismissed.
- Hover/focus: subtle elevated fill (not a heavy shadow).
- Click → open `html_url` in browser.
- Thread rows: context menu / trailing “Mark read”.

### 2.3 Footer

```
[ Open GitHub ]     Settings…  ·  Quit
```

Hairline above. Quiet tertiary actions — Settings/Quit as borderless buttons.

### 2.4 Empty state

Centered, airy (density exception):

- Symbol `bell.slash` (secondary)
- “You’re caught up”
- “New signals will land here when something needs you.”

No illustration kits, no emoji.

### 2.5 Badge

Menu bar label shows unread count; display **`99+`** when > 99.

---

## 3. Settings window

Independent `Window` / `Settings` scene, ~`520×640`, not jammed into the panel.

### 3.1 Structure (Form + double-bezel groups)

1. **Account** — avatar initials or login from `/user`; “Signed in as **login**”; Replace token…; Sign out
2. **Repositories** — searchable list, Owned/Collaborator/Org filters, steppers; hard cap **50** with inline warning at 40+
3. **Notification types** — toggles for every reason + synthetic sources; nested “Deliver banner” checkbox per row (disabled if global banners off)
4. **Banners** — global master toggle; short explanation
5. **Noise** — Include bots; Include draft PRs
6. **General** — Launch at Login; Export debug log…
7. **About** — version `1.0.0-dev`; link to GitHub Releases

Primary destructive actions (Sign out) use role `.destructive`.

### 3.2 First-launch PAT sheet

Full-bleed quiet sheet (not a tiny alert):

- Brand wordmark (SF Rounded)
- One sentence value prop (≤20 words)
- SecureField for PAT
- Link: “Create a classic token” → GitHub token docs
- Scopes callout (mono): `notifications` · `repo` · `read:user`
- Continue (accent) disabled until non-empty; validates via `/user`

On success: silent baseline + one summary notification: “Now monitoring N repos…”

---

## 4. Native UserNotifications

- Request permission after successful PAT (not before).
- If denied: banner toggles disabled with footnote “Badge-only mode”.
- Notification title = section-appropriate short label; body = item title; click → same URL resolver as rows.

**Factory banner defaults:** see `docs/PLAN.md` (Stars OFF; noisy reasons OFF; high-signal ON).

---

## 5. Anti-slop checklist (native)

- [ ] One accent (`signal` green) everywhere
- [ ] No purple / glow / emoji
- [ ] SF Pro + SF Mono only
- [ ] Double-bezel on panel + settings groups; rows are not cards
- [ ] Empty / loading / error / stale / rate-limit / invalid-token all distinct
- [ ] Reduce-motion honored
- [ ] Light + dark both readable (system semantic colors)
- [ ] No fake screenshots or decorative locale/version strips in the panel
