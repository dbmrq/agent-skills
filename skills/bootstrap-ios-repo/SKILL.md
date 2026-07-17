---
name: bootstrap-ios-repo
description: >-
  Install the shared ai-rules-ios rules + quality plug-in into a new or existing
  iOS app (Melvil, Gregor, or others). Use when starting a new iOS project,
  onboarding a repo that lacks .ai-rules, forgetting AI rules, or setting up
  SwiftLint/SwiftFormat/Periphery scripts.
---

# Bootstrap iOS repo (ai-rules + quality)

Install [dbmrq/ai-rules-ios](https://github.com/dbmrq/ai-rules-ios) so every agent and CI share the same guidance and gates.

## Agent workflow

1. From the app git root, run:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/dbmrq/ai-rules-ios/main/install.sh | bash -s -- --non-interactive --no-commit
   ```
   If the tree is dirty, stash first — `git subtree add` refuses modified trees.
2. Edit `.periphery.yml`: set `project`, `schemes`, and `targets` for this app.
3. Narrow `.swiftlint.yml` `included` paths if `Packages/**/.build` would be scanned.
4. Wire XcodeGen `preBuildScripts` to `./scripts/check.sh` (see `.ai-rules/quality/xcodegen/`).
5. Point Xcode Cloud `ci_pre_xcodebuild.sh` / `ci_post_xcodebuild.sh` at `.ai-rules/quality/ci/` snippets.
6. Run `./scripts/format.sh --fix && ./scripts/check.sh`.
7. After a build, run `./scripts/deadcode.sh` and commit `.periphery.baseline.json` if needed.
8. Prefer finishing with the **ios-quality-gate** skill on later work.

## Hard-won rules

- One plug-in for all apps — never fork Melvil-only / Gregor-only lint scripts.
- Do not commit agent install mirrors under `.agents/`.
- Use `--non-interactive` so agents are not blocked on `read -p`.
