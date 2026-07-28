# Agent instructions

Every agent working in this repo (Cursor, Kimi, Claude, or any other) follows this file. It is the single source of truth; skills, rules, and slash commands only point here.

## Deterministic check

The command that decides whether work is done is:

```bash
bash scripts/check.sh
```

Exit 0 means done. CI runs the same script on every PR — passing locally past a gate you didn't really meet is impossible. Never edit `scripts/check.sh` to make work pass.

## TDD protocol

1. Before implementing, write a failing test that encodes the acceptance criteria.
2. Run it and confirm it fails for the RIGHT reason. State the reason.
3. Implement the minimum to pass. Run the full suite, not just the new test.
4. Refactor only on green.
5. NEVER edit a test to make it pass unless the test itself is the bug —
   and say so explicitly if you believe it is.
6. Done = full suite green + lint clean. Report the actual command output.

## Working rules

- Issues are the queue. An issue labeled `agent:ready` has survived a grilling session and carries acceptance criteria; execute those decisions, don't remake them. If a decision is missing, stop and say so instead of guessing.
- One issue, one branch (`agent/issue-<N>`), one PR with `Closes #N`. Keep issues small: read only the paths listed under **Scope** in the issue body.
- Anything mechanical you solve (setup, codegen, migrations, release steps) gets saved as `scripts/*.sh` and referenced here. Re-running a script is free; re-deriving costs tokens.
