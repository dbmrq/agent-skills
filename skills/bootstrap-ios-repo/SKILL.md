---
name: bootstrap-ios-repo
description: >-
  Deprecated alias: use ios-bootstrap instead. Install ai-rules-ios and quality
  gates into an iOS app. Kept so older prompts that say bootstrap-ios-repo still
  resolve; prefer ios-bootstrap for new work.
---

# bootstrap-ios-repo (deprecated)

**Use [ios-bootstrap](../ios-bootstrap/SKILL.md)** for new and existing app onboarding (XcodeGen + ai-rules-ios + SwiftLint/SwiftFormat/Periphery + warnings-as-errors).

Quick install only (same as ios-bootstrap step 4):

```bash
curl -fsSL https://raw.githubusercontent.com/dbmrq/ai-rules-ios/main/install.sh | bash -s -- --non-interactive --no-commit
```

Then finish with the **ios-bootstrap** checklist (`.periphery.yml`, `SWIFT_TREAT_WARNINGS_AS_ERRORS`, Quality Check `preBuildScripts`, `./scripts/check.sh` / `deadcode.sh`). Ongoing work: **ios-quality-gate**.
