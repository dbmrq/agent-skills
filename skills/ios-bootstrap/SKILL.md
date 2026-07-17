---
name: ios-bootstrap
description: >-
  Bootstrap a new or empty iOS/macOS app repo: XcodeGen project.yml, folder
  layout, ai-rules-ios (SwiftLint/SwiftFormat/Periphery), warnings-as-errors,
  and CI/preBuild quality wiring. Use when creating a new iOS project, starting
  a greenfield SwiftUI app, scaffolding project.yml from scratch, onboarding a
  repo that lacks .ai-rules, or when the user asks to set up lint/format/deadcode
  gates. For XcodeGen-only debugging of an existing spec, use xcodegen. For
  finishing work on an already-bootstrapped app, use ios-quality-gate.
---

# iOS bootstrap

Greenfield and onboarding path for Leio-style apps. One plug-in for all apps — never fork Melvil-only / Gregor-only lint scripts.

**Related skills:** [xcodegen](../xcodegen/SKILL.md) (deep `project.yml` traps) · [ios-quality-gate](../ios-quality-gate/SKILL.md) (run gates later) · [swiftui-project-structure](../swiftui-project-structure/SKILL.md) (folder/architecture layout)

## Agent workflow (new repo)

1. **Create git root** if needed; stay at the app root for all commands.
2. **Layout** — feature-first folders under `Sources/<App>/` and optional `Packages/` (see swiftui-project-structure). Prefer XcodeGen + `project.yml` over hand-maintained `.xcodeproj`.
3. **Write `project.yml`** — start from [references/starter-project.yml](references/starter-project.yml); adjust bundle id, deployment target, schemes. Then `xcodegen generate`.
4. **Install quality + AI rules** (requires clean git tree for `subtree add` — stash first if dirty):
   ```bash
   curl -fsSL https://raw.githubusercontent.com/dbmrq/ai-rules-ios/main/install.sh | bash -s -- --non-interactive --no-commit
   ```
5. **Overlay Periphery** — edit `.periphery.yml`: `project`, `schemes`. **Do not** add `baseline:` or write a baseline file. Fix unused code until `./scripts/deadcode.sh` is clean (`--strict`).
6. **Narrow lint paths** if needed in root `.swiftlint.yml` (`included` / `excluded`) so `Packages/**/.build` is never scanned. Keep `parent_config: .ai-rules/quality/.swiftlint.yml`.
7. **Wire XcodeGen quality** (required):
   - App target `preBuildScripts`: run `./scripts/check.sh` (see `.ai-rules/quality/xcodegen/quality-prebuild.yml`).
   - App target settings: `ENABLE_USER_SCRIPT_SANDBOXING: NO` (so the script can run).
   - **All targets / project:** `SWIFT_TREAT_WARNINGS_AS_ERRORS: "YES"` (see `.ai-rules/quality/xcodegen/settings-strict.yml`).
8. **Xcode Cloud** (if used): fold `.ai-rules/quality/ci/ci_pre_snippet.sh` and `ci_post_snippet.sh` into `ci_scripts/`.
9. **Verify:**
   ```bash
   ./scripts/format.sh --fix
   ./scripts/check.sh
   xcodebuild -scheme <App> -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO
   ./scripts/deadcode.sh   # or --skip-build --index-store-path … after a build
   ```
10. Commit plug-in + overlays when the user asks. Later work: **ios-quality-gate**.

## Existing repo (missing `.ai-rules` only)

Skip scaffolding. Run install (step 4), then steps 5–9. Use **xcodegen** if `project.yml` already exists and only needs quality settings / `preBuildScripts`.

## Hard requirements (non-negotiable)

| Requirement | Detail |
|-------------|--------|
| Warnings as errors | `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` on every target that compiles Swift |
| No force unwraps | SwiftLint `force_unwrapping` / `force_try` / `force_cast` / `implicitly_unwrapped_optional` are **errors** |
| No Periphery baselines | Never commit `.periphery.baseline.json` or `baseline:` — delete dead code |
| Shared plug-in only | Scripts live under `.ai-rules/quality/`; apps keep thin wrappers in `./scripts/` |
| Sandbox off for Quality Check | `ENABLE_USER_SCRIPT_SANDBOXING: NO` on the app target that runs `preBuildScripts` |

## Curated SwiftLint set (shared)

Canonical file: [ai-rules-ios `quality/.swiftlint.yml`](https://github.com/dbmrq/ai-rules-ios/blob/main/quality/.swiftlint.yml). All listed rules are **errors** (including length ceilings). Summary:

- **Foot-guns:** `force_cast`, `force_try`, `force_unwrapping`, `implicitly_unwrapped_optional`
- **Size:** `file_length` (400), `type_body_length` (250), `function_body_length` (50), `function_parameter_count` (7), `cyclomatic_complexity` (15), `nesting`
- **Empty / redundancy:** `empty_count`, `empty_string`, `redundant_nil_coalescing`, `unused_optional_binding`, `contains_over_filter_count`, `first_where`
- **Idioms:** `unavailable_condition`, `optional_data_string_conversion`
- **Custom:** `no_observable_object` (prefer `@Observable` over `ObservableObject` / `@Published`)

Do not maintain a second rule file. Extend only via upstream ai-rules-ios (then sync). Historical debt: `.ai-rules/quality/debt/RATCHET.md`.

## Starter settings snippet

```yaml
settings:
  base:
    SWIFT_TREAT_WARNINGS_AS_ERRORS: "YES"
    # App target that runs Quality Check also needs:
    # ENABLE_USER_SCRIPT_SANDBOXING: NO
```

Full starter spec: [references/starter-project.yml](references/starter-project.yml). XcodeGen traps: **xcodegen** skill.

## Hard-won traps

- `git subtree add` fails on a dirty worktree — stash or commit first.
- XcodeGen `type: aggregate` is **unsupported** in some versions — do not rely on a Quality aggregate target; use `preBuildScripts` + CI.
- After adding files under `Sources/`, run `xcodegen generate`.
- Periphery `build-for-testing` compiles tests; if tests are broken, `xcodebuild … build` then `./scripts/deadcode.sh --skip-build --index-store-path …`.
- Install with `--non-interactive` so agents are not blocked on `read -p`.
