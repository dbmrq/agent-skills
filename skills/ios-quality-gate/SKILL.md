---
name: ios-quality-gate
description: >-
  Run the shared ai-rules-ios quality plug-in (scripts/check.sh, format,
  Periphery deadcode --strict) before finishing iOS app work. Use when finishing
  features, refactors, removing APIs, cleanup, PRs, or Melvil/Gregor/Leio iOS
  changes that must stay lint-clean with zero unused code and no force unwraps.
---

# iOS quality gate

Enforce the shared [ai-rules-ios](https://github.com/dbmrq/ai-rules-ios) plug-in before considering iOS work done. All SwiftLint severities in the shared config are **errors**; compiler warnings must also fail the build (`SWIFT_TREAT_WARNINGS_AS_ERRORS`).

If `.ai-rules/` is missing, run **[ios-bootstrap](../ios-bootstrap/SKILL.md)** (not an ad-hoc lint setup).

## Agent workflow

1. Confirm `.ai-rules/quality/` and `./scripts/check.sh` exist. If not:
   `curl -fsSL https://raw.githubusercontent.com/dbmrq/ai-rules-ios/main/install.sh | bash -s -- --non-interactive --no-commit`
   then complete ios-bootstrap wiring (Periphery scheme, warnings-as-errors, Quality Check script).
2. `./scripts/format.sh --fix` if you touched Swift files.
3. `./scripts/check.sh` — fix **every** violation (there is no warning-only debt in the shared config).
4. After removals / renames / structural edits: build, then `./scripts/deadcode.sh` or `./scripts/check-all.sh`. **No baselines** — delete unused declarations Periphery reports (`--strict`).
5. Do not leave store/domain wrappers without callers. Never reintroduce `!` / `as!`.
6. Optional: `.ai-rules/quality/scripts/debt-report.sh` for a count summary.

## Hard-won rules

- Prefer project wrappers (`./scripts/*`) — they fail if the plug-in is missing.
- Do not invent a second lint stack; sync `.ai-rules` via install/subtree.
- Edit scheme-specific `.periphery.yml` only; shared SwiftLint stays in the plug-in.
- `xcodegen generate` after adding `Sources/` files in XcodeGen apps.
- Confirm `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` remains on Swift targets.
