#!/usr/bin/env bash
# Install or update all skills to the latest version.
# Resolves each repo to its latest git tag, or default-branch HEAD if untagged.
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

set -euo pipefail

AGENT="${1:-cursor}"
SCOPE="${2:-user}"

REPO_SLUG="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "dbmrq/agent-skills")"

AGENT_SKILLS_PIN_ARGS=()
SWIFTUI_EXPERT_PIN_ARGS=()
[[ -n "${AGENT_SKILLS_PIN:-}" ]] && AGENT_SKILLS_PIN_ARGS=(--pin "$AGENT_SKILLS_PIN")
[[ -n "${SWIFTUI_EXPERT_PIN:-}" ]] && SWIFTUI_EXPERT_PIN_ARGS=(--pin "$SWIFTUI_EXPERT_PIN")

echo "→ Syncing skills from ${REPO_SLUG} (agent=${AGENT}, scope=${SCOPE}, latest)"
gh skill install "$REPO_SLUG" --all \
  --agent "$AGENT" --scope "$SCOPE" \
  "${AGENT_SKILLS_PIN_ARGS[@]}" \
  --force

echo "→ Syncing swiftui-expert-skill from avdlee/swiftui-agent-skill (latest)"
gh skill install avdlee/swiftui-agent-skill swiftui-expert-skill \
  --agent "$AGENT" --scope "$SCOPE" \
  "${SWIFTUI_EXPERT_PIN_ARGS[@]}" \
  --force

echo "✓ All skills up to date. List installed: gh skill list"
