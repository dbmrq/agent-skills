---
name: ios-quality-gate
description: >-
  Run the shared ai-rules-ios quality plug-in (scripts/check.sh, format,
  Periphery deadcode) before finishing iOS app work. Use when finishing
  features, refactors, removing APIs, cleanup, PRs, or Melvil/Gregor/Leio
  iOS changes that should stay lint-clean and free of unused code.
---

# iOS quality gate

Enforce the shared [ai-rules-ios](https://github.com/dbmrq/ai-rules-ios) plug-in before considering iOS work done.

## Agent workflow

1. Confirm the repo has `.ai-rules/quality/` and `./scripts/check.sh`. If missing, run install (see bootstrap-ios-repo) or:
   `curl -fsSL https://raw.githubusercontent.com/dbmrq/ai-rules-ios/main/install.sh | bash -s -- --non-interactive --no-commit`
2. Run `./scripts/format.sh --fix` if you touched Swift files.
3. Run `./scripts/check.sh` and fix any **errors** (warnings may remain on large legacy types).
4. After removing features, renaming APIs, or structural edits: build once, then `./scripts/deadcode.sh` (or `./scripts/check-all.sh`) and delete unused declarations Periphery reports.
5. Do not leave store/domain wrappers without callers.

## Hard-won rules

- Prefer the project wrappers (`./scripts/*`) — they fail loudly if the plug-in is missing.
- Do not invent a second lint stack; update `.ai-rules` via install/sync.
- Edit scheme-specific `.periphery.yml` only; keep shared SwiftLint in the plug-in.
- `xcodegen generate` after adding Sources files in XcodeGen apps.
