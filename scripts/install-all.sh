#!/usr/bin/env bash
# Install or update all skills to the latest version.
# Resolves each repo to its latest git tag, or default-branch HEAD if untagged.
# Apple Xcode skills are exported from the active Xcode toolchain when available.
# Safe to re-run anytime — use this instead of a separate update step.
#
# Usage:
#   ./scripts/install-all.sh [agent] [scope]
#
# Examples:
#   ./scripts/install-all.sh              # cursor + user (defaults)
#   ./scripts/install-all.sh cursor user
#
# Optional pins (off by default — only for reproducible/CI installs):
#   AGENT_SKILLS_PIN=v1.0.0 SWIFTUI_EXPERT_PIN=4.0.0 ./scripts/install-all.sh
#
# Apple Xcode skills (optional):
#   SKIP_XCODE_SKILLS=1 ./scripts/install-all.sh
#   XCODE_SKILLS_SOURCE=mirror ./scripts/install-all.sh   # skip export, use GitHub mirror
#   XCODE_SKILLS_SOURCE=apple ./scripts/install-all.sh    # fail if export unavailable
#   XCODE_SKILLS_PIN=6f9ff8d ./scripts/install-all.sh     # pin mirror ref (mirror source only)

set -euo pipefail

AGENT="${1:-cursor}"
SCOPE="${2:-user}"

REPO_SLUG="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "dbmrq/agent-skills")"
XCODE_SKILLS_MIRROR="superagents-lab/xcode27-skills"

install_xcode_skills_from_mirror() {
  echo "→ Syncing Apple Xcode skills from ${XCODE_SKILLS_MIRROR} (mirror)"
  if [[ -n "${XCODE_SKILLS_PIN:-}" ]]; then
    gh skill install "$XCODE_SKILLS_MIRROR" --all \
      --agent "$AGENT" --scope "$SCOPE" --pin "$XCODE_SKILLS_PIN" --force
  else
    gh skill install "$XCODE_SKILLS_MIRROR" --all \
      --agent "$AGENT" --scope "$SCOPE" --force
  fi
}

install_xcode_skills() {
  local source="${XCODE_SKILLS_SOURCE:-auto}"

  if [[ "$source" != "auto" && "$source" != "apple" && "$source" != "mirror" ]]; then
    echo "✗ XCODE_SKILLS_SOURCE must be auto, apple, or mirror (got: $source)" >&2
    exit 1
  fi

  if [[ "$source" == "mirror" ]]; then
    install_xcode_skills_from_mirror
    return
  fi

  if ! command -v xcrun >/dev/null 2>&1; then
    if [[ "$source" == "apple" ]]; then
      echo "✗ xcrun not found; cannot export Apple Xcode skills" >&2
      exit 1
    fi
    echo "⚠ xcrun not found; falling back to ${XCODE_SKILLS_MIRROR}" >&2
    install_xcode_skills_from_mirror
    return
  fi

  local export_dir
  export_dir="$(mktemp -d -t xcode-skills-export.XXXXXX)"
  cleanup_export() { rm -rf "$export_dir"; }
  trap cleanup_export RETURN

  echo "→ Exporting Apple Xcode skills from toolchain (xcrun agent skills export)"
  if xcrun agent skills export --output-dir "$export_dir" --replace-existing; then
    echo "→ Installing exported Apple Xcode skills"
    gh skill install "$export_dir" --all --from-local \
      --agent "$AGENT" --scope "$SCOPE" --force
    return
  fi

  if [[ "$source" == "apple" ]]; then
    echo "✗ xcrun agent skills export failed (XCODE_SKILLS_SOURCE=apple)" >&2
    echo "  Ensure Xcode 26+ is installed and selected in Settings → Locations → Command Line Tools." >&2
    exit 1
  fi

  echo "⚠ Export failed; falling back to ${XCODE_SKILLS_MIRROR}" >&2
  trap - RETURN
  cleanup_export
  install_xcode_skills_from_mirror
}

echo "→ Syncing skills from ${REPO_SLUG} (agent=${AGENT}, scope=${SCOPE}, latest)"
if [[ -n "${AGENT_SKILLS_PIN:-}" ]]; then
  gh skill install "$REPO_SLUG" --all --agent "$AGENT" --scope "$SCOPE" --pin "$AGENT_SKILLS_PIN" --force
else
  gh skill install "$REPO_SLUG" --all --agent "$AGENT" --scope "$SCOPE" --force
fi

echo "→ Syncing swiftui-expert-skill from avdlee/swiftui-agent-skill (latest)"
if [[ -n "${SWIFTUI_EXPERT_PIN:-}" ]]; then
  gh skill install avdlee/swiftui-agent-skill swiftui-expert-skill \
    --agent "$AGENT" --scope "$SCOPE" --pin "$SWIFTUI_EXPERT_PIN" --force
else
  gh skill install avdlee/swiftui-agent-skill swiftui-expert-skill \
    --agent "$AGENT" --scope "$SCOPE" --force
fi

if [[ "${SKIP_XCODE_SKILLS:-0}" != "1" ]]; then
  install_xcode_skills
else
  echo "→ Skipping Apple Xcode skills (SKIP_XCODE_SKILLS=1)"
fi

echo "✓ All skills up to date. List installed: gh skill list"
