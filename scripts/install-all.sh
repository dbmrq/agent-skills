#!/usr/bin/env bash
# Install or update all skills to the latest version.
# Resolves each repo to its latest git tag, or default-branch HEAD if untagged.
# Apple Xcode skills are exported from the active Xcode toolchain when available.
# Safe to re-run anytime — use this instead of a separate update step.
#
# Usage:
#   ./scripts/install-all.sh [scope]
#   ./scripts/install-all.sh [agent] [scope]   # legacy: single agent
#
# Examples:
#   ./scripts/install-all.sh              # auto-detect targets + user scope
#   ./scripts/install-all.sh user
#   ./scripts/install-all.sh cursor user  # legacy: one agent dir only
#
# Install targets (AGENTS env var):
#   AGENTS=auto ./scripts/install-all.sh     # default — every agent dir already present
#   AGENTS=cursor,pi ./scripts/install-all.sh
#   AGENTS=all ./scripts/install-all.sh      # every gh agent user-dir (deduped)
#
# Skills land in shared ~/.agents/skills (Cursor/Copilot/Cline/Warp/Pi-compatible)
# plus agent-specific dirs (e.g. ~/.pi/agent/skills, ~/.claude/skills, ~/.codex/skills).
#
# Optional pins (off by default — only for reproducible/CI installs):
#   AGENT_SKILLS_PIN=v1.0.0 SWIFTUI_EXPERT_PIN=4.0.0 ./scripts/install-all.sh
#
# Apple Xcode skills (optional):
#   SKIP_XCODE_SKILLS=1 ./scripts/install-all.sh

set -euo pipefail

ALL_AGENTS="github-copilot,claude-code,cursor,codex,gemini-cli,antigravity,antigravity-cli,antigravity2.0,adal,amp,augment,bob,cline,codebuddy,command-code,continue,cortex,crush,deepagents,droid,firebender,goose,iflow-cli,junie,kilo,kimi-cli,kiro-cli,kode,mcpjam,mistral-vibe,mux,neovate,openclaw,opencode,openhands,pi,pochi,qoder,qwen-code,replit,roo,trae,trae-cn,universal,warp,windsurf,zencoder"

SCOPE="user"
AGENTS_CSV="${AGENTS:-auto}"
INSTALL_DIRS=()

is_scope() {
  [[ "$1" == "user" || "$1" == "project" ]]
}

is_known_agent() {
  local id="$1"
  [[ ",${ALL_AGENTS}," == *",${id},"* ]]
}

# gh skill registry user-scope skill directories (relative to $HOME).
agent_user_dir() {
  local agent="$1"
  case "$agent" in
    github-copilot) printf '%s/.copilot/skills' "$HOME" ;;
    claude-code)
      if [[ -n "${CLAUDE_CONFIG_DIR:-}" ]]; then
        printf '%s/skills' "$CLAUDE_CONFIG_DIR"
      else
        printf '%s/.claude/skills' "$HOME"
      fi
      ;;
    cursor) printf '%s/.cursor/skills' "$HOME" ;;
    codex) printf '%s/.codex/skills' "$HOME" ;;
    gemini-cli) printf '%s/.gemini/skills' "$HOME" ;;
    antigravity) printf '%s/.gemini/antigravity/skills' "$HOME" ;;
    antigravity-cli) printf '%s/.gemini/antigravity-cli/skills' "$HOME" ;;
    antigravity2.0) printf '%s/.gemini/config/skills' "$HOME" ;;
    adal) printf '%s/.adal/skills' "$HOME" ;;
    amp|kimi-cli|replit) printf '%s/.config/agents/skills' "$HOME" ;;
    augment) printf '%s/.augment/skills' "$HOME" ;;
    bob) printf '%s/.bob/skills' "$HOME" ;;
    cline|warp|universal) printf '%s/.agents/skills' "$HOME" ;;
    codebuddy) printf '%s/.codebuddy/skills' "$HOME" ;;
    command-code) printf '%s/.commandcode/skills' "$HOME" ;;
    continue) printf '%s/.continue/skills' "$HOME" ;;
    cortex) printf '%s/.snowflake/cortex/skills' "$HOME" ;;
    crush) printf '%s/.config/crush/skills' "$HOME" ;;
    deepagents) printf '%s/.deepagents/agent/skills' "$HOME" ;;
    droid) printf '%s/.factory/skills' "$HOME" ;;
    firebender) printf '%s/.firebender/skills' "$HOME" ;;
    goose) printf '%s/.config/goose/skills' "$HOME" ;;
    iflow-cli) printf '%s/.iflow/skills' "$HOME" ;;
    junie) printf '%s/.junie/skills' "$HOME" ;;
    kilo) printf '%s/.kilocode/skills' "$HOME" ;;
    kiro-cli) printf '%s/.kiro/skills' "$HOME" ;;
    kode) printf '%s/.kode/skills' "$HOME" ;;
    mcpjam) printf '%s/.mcpjam/skills' "$HOME" ;;
    mistral-vibe) printf '%s/.vibe/skills' "$HOME" ;;
    mux) printf '%s/.mux/skills' "$HOME" ;;
    neovate) printf '%s/.neovate/skills' "$HOME" ;;
    openclaw) printf '%s/.openclaw/skills' "$HOME" ;;
    opencode) printf '%s/.config/opencode/skills' "$HOME" ;;
    openhands) printf '%s/.openhands/skills' "$HOME" ;;
    pi) printf '%s/.pi/agent/skills' "$HOME" ;;
    pochi) printf '%s/.pochi/skills' "$HOME" ;;
    qoder) printf '%s/.qoder/skills' "$HOME" ;;
    qwen-code) printf '%s/.qwen/skills' "$HOME" ;;
    roo) printf '%s/.roo/skills' "$HOME" ;;
    trae) printf '%s/.trae/skills' "$HOME" ;;
    trae-cn) printf '%s/.trae-cn/skills' "$HOME" ;;
    windsurf) printf '%s/.codeium/windsurf/skills' "$HOME" ;;
    zencoder) printf '%s/.zencoder/skills' "$HOME" ;;
    *) return 1 ;;
  esac
}

canonical_dir() {
  local dir="$1"
  mkdir -p "$dir"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$dir"
  else
    (cd "$dir" && pwd -P)
  fi
}

add_install_dir() {
  local dir="$1"
  local canonical existing

  [[ -n "$dir" ]] || return 0
  canonical="$(canonical_dir "$dir")"

  for existing in "${INSTALL_DIRS[@]:-}"; do
    [[ "$existing" == "$canonical" ]] && return 0
  done

  INSTALL_DIRS+=("$canonical")
}

add_core_user_dirs() {
  add_install_dir "$HOME/.agents/skills"
  if [[ -d "$HOME/.pi" ]]; then
    add_install_dir "$HOME/.pi/agent/skills"
  fi
}

add_project_core_dir() {
  local root="${1:-}"
  if [[ -z "$root" ]]; then
    root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  fi
  add_install_dir "$root/.agents/skills"
}

detect_agents_from_gh() {
  if ! command -v gh >/dev/null 2>&1; then
    return 0
  fi
  gh skill list --scope "$SCOPE" --json agentHosts 2>/dev/null \
    | jq -r '[.[].agentHosts[]] | unique | .[]' 2>/dev/null \
    | grep -v '^published$' || true
}

detect_agents_from_homedir() {
  local agent dir parent
  local -a agents=()

  IFS=',' read -r -a agents <<< "$ALL_AGENTS"
  for agent in "${agents[@]}"; do
    dir="$(agent_user_dir "$agent" 2>/dev/null || true)"
    [[ -n "$dir" ]] || continue
    parent="$(dirname "$dir")"
    # Agent is "present" when its config/home dir already exists.
    if [[ -e "$parent" ]]; then
      printf '%s\n' "$agent"
    fi
  done
}

resolve_dirs_for_agents() {
  local agents_csv="$1"
  local agent

  if [[ "$agents_csv" == "all" ]]; then
    agents_csv="$ALL_AGENTS"
  fi

  IFS=',' read -r -a agents <<< "$agents_csv"
  for agent in "${agents[@]}"; do
    agent="${agent// /}"
    [[ -z "$agent" ]] && continue
    if ! is_known_agent "$agent"; then
      echo "✗ Unknown agent: $agent (see: gh skill install --help)" >&2
      exit 1
    fi
    add_install_dir "$(agent_user_dir "$agent")"
  done
}

resolve_install_dirs() {
  INSTALL_DIRS=()
  local agents_csv="$AGENTS_CSV"
  local detected agent

  if [[ "$SCOPE" == "project" ]]; then
    add_project_core_dir
    if [[ "$agents_csv" != "auto" ]]; then
      resolve_dirs_for_agents "$agents_csv"
    fi
    return
  fi

  if [[ "$agents_csv" == "auto" ]]; then
    add_core_user_dirs
    # Prefer filesystem presence (agents already on this machine). Merge with
    # gh skill list hosts so previously synced agents are not dropped.
    detected="$(
      { detect_agents_from_homedir; detect_agents_from_gh; } | awk 'NF && !seen[$0]++'
    )"
    while IFS= read -r agent; do
      [[ -z "$agent" ]] && continue
      is_known_agent "$agent" || continue
      add_install_dir "$(agent_user_dir "$agent")"
    done <<< "$detected"
    return
  fi

  if [[ "$agents_csv" == "all" ]]; then
    add_core_user_dirs
    resolve_dirs_for_agents "$ALL_AGENTS"
    return
  fi

  # Explicit agent list (legacy single-agent or custom CSV): those dirs only.
  resolve_dirs_for_agents "$agents_csv"
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    return
  fi

  if [[ $# -eq 1 ]]; then
    if is_scope "$1"; then
      SCOPE="$1"
      return
    fi
    if is_known_agent "$1"; then
      AGENTS_CSV="$1"
      return
    fi
    echo "✗ Unknown argument: $1 (expected scope, agent id, or omit for defaults)" >&2
    exit 1
  fi

  if [[ $# -eq 2 ]]; then
    if is_known_agent "$1" && is_scope "$2"; then
      AGENTS_CSV="$1"
      SCOPE="$2"
      return
    fi
  fi

  echo "✗ Usage: $0 [scope]" >&2
  echo "       $0 [agent] [scope]   # legacy single-agent form" >&2
  exit 1
}

parse_args "$@"
resolve_install_dirs

if [[ ${#INSTALL_DIRS[@]} -eq 0 ]]; then
  echo "✗ No install directories resolved (AGENTS=${AGENTS_CSV}, scope=${SCOPE})" >&2
  exit 1
fi

REPO_SLUG="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "dbmrq/agent-skills")"

targets_label() {
  local joined=""
  local dir
  for dir in "${INSTALL_DIRS[@]}"; do
    if [[ -n "$joined" ]]; then
      joined+=", "
    fi
    joined+="$dir"
  done
  printf '%s' "$joined"
}

# Copy skill folders produced by a staged gh install into a destination.
mirror_skills() {
  local src="$1"
  local dest="$2"
  local skill_path skill_name

  mkdir -p "$dest"
  shopt -s nullglob
  for skill_path in "$src"/*/; do
    skill_name="$(basename "$skill_path")"
    rm -rf "${dest}/${skill_name}"
    cp -R "$skill_path" "${dest}/${skill_name}"
  done
  shopt -u nullglob
}

# Fetch/install once, then mirror into every target dir.
# Re-running gh skill install per directory re-clones the same repos and can look
# like a stuck loop (and still prompts for agents on a TTY without --agent).
install_for_dirs() {
  local staging dir

  if [[ ${#INSTALL_DIRS[@]} -eq 0 ]]; then
    echo "✗ No install directories resolved" >&2
    return 1
  fi

  if [[ ${#INSTALL_DIRS[@]} -eq 1 ]]; then
    echo "  → ${INSTALL_DIRS[0]}"
    gh skill install "$@" \
      --agent universal \
      --scope "$SCOPE" \
      --dir "${INSTALL_DIRS[0]}" \
      --force
    return
  fi

  (
    set -euo pipefail
    staging="$(mktemp -d -t agent-skills-stage.XXXXXX)"
    trap 'rm -rf "$staging"' EXIT

    echo "  → fetch once, then mirror to ${#INSTALL_DIRS[@]} dirs"
    # --agent is required on a TTY even with --dir; otherwise gh prompts
    # "Select target agent(s)" on every install call.
    gh skill install "$@" \
      --agent universal \
      --scope "$SCOPE" \
      --dir "$staging" \
      --force

    for dir in "${INSTALL_DIRS[@]}"; do
      echo "  → ${dir}"
      mirror_skills "$staging" "$dir"
    done
  )
}

install_xcode_skills() {
  if ! command -v xcrun >/dev/null 2>&1; then
    echo "⚠ xcrun not found; skipping Apple Xcode skills." >&2
    echo "  Install Xcode 26+ and select it in Settings → Locations → Command Line Tools to export Apple skills." >&2
    return
  fi

  local export_dir
  export_dir="$(mktemp -d -t xcode-skills-export.XXXXXX)"
  cleanup_export() { rm -rf "$export_dir"; }
  trap cleanup_export RETURN

  echo "→ Exporting Apple Xcode skills from toolchain (xcrun agent skills export)"
  if ! xcrun agent skills export --output-dir "$export_dir" --replace-existing; then
    echo "⚠ xcrun agent skills export failed; skipping Apple Xcode skills." >&2
    echo "  Ensure Xcode 26+ is installed and selected in Settings → Locations → Command Line Tools." >&2
    return
  fi

  if ! find "$export_dir" -name SKILL.md -print -quit | grep -q .; then
    echo "⚠ xcrun agent skills export returned no skills; skipping Apple Xcode skills." >&2
    echo "  This commonly means the active Xcode toolchain doesn't include the exported Apple skills yet." >&2
    return
  fi

  echo "→ Installing exported Apple Xcode skills"
  install_for_dirs "$export_dir" --all --from-local
}

echo "→ Syncing skills from ${REPO_SLUG} (AGENTS=${AGENTS_CSV}, scope=${SCOPE}, latest)"
echo "  targets: $(targets_label)"
if [[ -n "${AGENT_SKILLS_PIN:-}" ]]; then
  install_for_dirs "$REPO_SLUG" --all --pin "$AGENT_SKILLS_PIN"
else
  install_for_dirs "$REPO_SLUG" --all
fi

echo "→ Syncing swiftui-expert-skill from avdlee/swiftui-agent-skill (latest)"
if [[ -n "${SWIFTUI_EXPERT_PIN:-}" ]]; then
  install_for_dirs avdlee/swiftui-agent-skill swiftui-expert-skill --pin "$SWIFTUI_EXPERT_PIN"
else
  install_for_dirs avdlee/swiftui-agent-skill swiftui-expert-skill
fi

if [[ "${SKIP_XCODE_SKILLS:-0}" != "1" ]]; then
  install_xcode_skills
else
  echo "→ Skipping Apple Xcode skills (SKIP_XCODE_SKILLS=1)"
fi

echo "✓ All skills up to date. List installed: gh skill list"
