#!/bin/bash
#
# Ralph loop — run Cursor agents repeatedly against a Markdown checklist plan.
#
# Copy to scripts/ralph-loop.sh and customize defaults. Generated from the
# ralph-loop skill template.
#
# Usage:
#   ./scripts/ralph-loop.sh
#   ./scripts/ralph-loop.sh --plan-file docs/my-feature-plan.md --max-runs 30
#   ./scripts/ralph-loop.sh --dry-run
#
# Environment:
#   CURSOR_AGENT_BIN   Agent executable (auto-detect: agent, cursor-agent, cursor agent)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Customize defaults for your project ---
PLAN_FILE_REL="docs/PLAN.md"
MAX_RUNS=24
MAX_NO_CHANGE_RUNS=3
MAX_NO_PROGRESS_RUNS=3
MODEL="auto"
COMMIT_PREFIX="ralph-loop"
ALLOW_DIRTY=false
DRY_RUN=false
NUMBERED_ITEMS=true   # true: match **N.** items; false: any - [ ] line

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --plan-file <path>              Markdown checklist (default: $PLAN_FILE_REL)
  --max-runs <n>                  Hard cap on agent runs (default: $MAX_RUNS)
  --max-no-change-runs <n>        Stop after N runs with no file changes (default: $MAX_NO_CHANGE_RUNS)
  --max-no-progress-runs <n>      Stop after N runs that change files but not checkboxes (default: $MAX_NO_PROGRESS_RUNS)
  --model <model>                 Cursor model (default: $MODEL)
  --commit-prefix <text>          Commit message prefix (default: $COMMIT_PREFIX)
  --allow-dirty                   Allow unrelated dirty files at start
  --any-checkbox                  Match any "- [ ]" line, not only numbered items
  --dry-run                       Print first prompt and exit
  --help, -h                      Show this help

Environment:
  CURSOR_AGENT_BIN                Override agent executable
EOF
}

die() { echo "Error: $*" >&2; exit 1; }
log() { printf '[ralph-loop] %s\n' "$*"; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --plan-file) PLAN_FILE_REL="${2:?}"; shift 2 ;;
        --max-runs) MAX_RUNS="${2:?}"; shift 2 ;;
        --max-no-change-runs) MAX_NO_CHANGE_RUNS="${2:?}"; shift 2 ;;
        --max-no-progress-runs) MAX_NO_PROGRESS_RUNS="${2:?}"; shift 2 ;;
        --model) MODEL="${2:?}"; shift 2 ;;
        --commit-prefix) COMMIT_PREFIX="${2:?}"; shift 2 ;;
        --allow-dirty) ALLOW_DIRTY=true; shift ;;
        --any-checkbox) NUMBERED_ITEMS=false; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done

[[ "$MAX_RUNS" =~ ^[0-9]+$ && "$MAX_RUNS" -gt 0 ]] || die "--max-runs must be a positive integer"

cd "$REPO_ROOT"
git rev-parse --show-toplevel >/dev/null 2>&1 || die "not inside a git repository"

PLAN_FILE="$REPO_ROOT/$PLAN_FILE_REL"
[[ -f "$PLAN_FILE" ]] || die "plan file not found: $PLAN_FILE_REL"

GIT_DIR="$(git rev-parse --git-dir)"
[[ ! -f "$GIT_DIR/MERGE_HEAD" ]] || die "merge in progress"
[[ ! -d "$GIT_DIR/rebase-merge" && ! -d "$GIT_DIR/rebase-apply" ]] || die "rebase in progress"

detect_agent_mode() {
    if [[ -n "${CURSOR_AGENT_BIN:-}" ]]; then
        command -v "$CURSOR_AGENT_BIN" >/dev/null 2>&1 || [[ -x "$CURSOR_AGENT_BIN" ]] || die "CURSOR_AGENT_BIN not executable: $CURSOR_AGENT_BIN"
        echo "custom:$CURSOR_AGENT_BIN"
    elif command -v agent >/dev/null 2>&1; then echo "agent:agent"
    elif command -v cursor-agent >/dev/null 2>&1; then echo "cursor-agent:cursor-agent"
    elif command -v cursor >/dev/null 2>&1; then echo "cursor:cursor"
    else die "Cursor CLI agent not found. Set CURSOR_AGENT_BIN."
    fi
}

AGENT_MODE="$(detect_agent_mode)"

run_agent() {
    local prompt="$1" output_file="$2"
    local mode="${AGENT_MODE%%:*}" executable="${AGENT_MODE#*:}"
    case "$mode" in
        cursor) "$executable" agent -p "$prompt" --model "$MODEL" --output-format text 2>&1 | tee "$output_file" ;;
        *) "$executable" -p "$prompt" --model "$MODEL" --output-format text 2>&1 | tee "$output_file" ;;
    esac
}

status_snapshot() { git status --porcelain=v1 --untracked-files=all; }

dirty_paths() {
    git status --porcelain=v1 --untracked-files=all | while read -r line; do
        [[ -z "$line" ]] && continue
        local path="${line:3}"
        [[ "$path" == *" -> "* ]] && path="${path#* -> }"
        printf '%s\n' "$path"
    done
}

is_allowed_initial_dirty_path() {
    local path="$1"
    case "$path" in
        "$PLAN_FILE_REL"|"scripts/ralph-loop.sh"|".gitignore")
            return 0 ;;
        .ralph-loop/*)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

unchecked_count() {
    python3 - "$PLAN_FILE" "$NUMBERED_ITEMS" <<'PY'
import pathlib, re, sys
plan = pathlib.Path(sys.argv[1])
numbered = sys.argv[2].lower() == "true"
pat = re.compile(r"^\s*-\s+\[\s\]\s+\*\*\d+\.") if numbered else re.compile(r"^\s*-\s+\[\s\]\s+")
in_checklist = False
count = 0
for line in plan.read_text(encoding="utf-8").splitlines():
    if re.match(r"^##\s+.*[Cc]hecklist", line) or re.match(r"^##\s+Implementation", line):
        in_checklist = True
    if numbered and not in_checklist:
        continue
    if pat.match(line):
        count += 1
print(count)
PY
}

next_unchecked_item() {
    python3 - "$PLAN_FILE" "$NUMBERED_ITEMS" <<'PY'
import pathlib, re, sys
plan = pathlib.Path(sys.argv[1])
numbered = sys.argv[2].lower() == "true"
pat = re.compile(r"^\s*-\s+\[\s\]\s+(.+?)\s*$") if not numbered else re.compile(r"^\s*-\s+\[\s\]\s+\*\*\d+\.\s+(.+?)\*\*")
in_checklist = False
for line in plan.read_text(encoding="utf-8").splitlines():
    if re.match(r"^##\s+.*[Cc]hecklist", line) or re.match(r"^##\s+Implementation", line):
        in_checklist = True
    if numbered and not in_checklist:
        continue
    m = pat.match(line)
    if m:
        print(m.group(1).strip())
        break
PY
}

make_prompt() {
    local run_number="$1" before_count="$2" next_item="$3"
    cat <<EOF
You are running inside an automated Ralph loop.

Goal:
Work on the next unchecked item in \`$PLAN_FILE_REL\`, verify it, then mark it done only if verification actually passed.

Current run: $run_number
Unchecked checklist items before this run: $before_count
Next unchecked item: $next_item

Operating rules:
- Read \`$PLAN_FILE_REL\` first. It is the source of truth.
- Work on only the next unchecked checklist item. Do not start later items.
- Keep changes scoped to that item; follow existing project patterns.
- Add or update focused tests when appropriate.
- Run the fastest relevant verification; record the exact command.
- When complete, change that item's checkbox from \`[ ]\` to \`[x]\`.
- Add **Notes for later items:** under completed or future items when you learn something future agents would not easily find on their own.
- If blocked, document under that item, leave unchecked, and stop.
- Do not create git commits. This script commits after successful runs.

Before finishing, report what changed, what verification ran, and whether the item was marked complete.
EOF
}

commit_changes() {
    local run_number="$1" before_count="$2" after_count="$3"
    git add -A
    if git diff --cached --quiet; then
        log "No staged changes; skipping commit."
        return 0
    fi
    git commit -m "$(cat <<EOF
$COMMIT_PREFIX: run $run_number

Unchecked plan items: $before_count -> $after_count.
EOF
)"
}

if [[ "$ALLOW_DIRTY" == false ]]; then
    while IFS= read -r path; do
        is_allowed_initial_dirty_path "$path" || die "unrelated dirty file: $path (commit/stash or use --allow-dirty)"
    done < <(dirty_paths)
fi

LOG_DIR="$REPO_ROOT/.ralph-loop/logs"
mkdir -p "$LOG_DIR"

initial_count="$(unchecked_count)"
[[ "$initial_count" -gt 0 ]] || { log "No unchecked items in $PLAN_FILE_REL."; exit 0; }

log "Agent: $AGENT_MODE | Plan: $PLAN_FILE_REL | Unchecked: $initial_count"

no_change_runs=0
no_progress_runs=0

for ((run_number = 1; run_number <= MAX_RUNS; run_number++)); do
    before_count="$(unchecked_count)"
    [[ "$before_count" -gt 0 ]] || { log "Plan complete."; exit 0; }

    next_item="$(next_unchecked_item)"
    prompt="$(make_prompt "$run_number" "$before_count" "$next_item")"
    output_file="$LOG_DIR/run-$(printf '%03d' "$run_number").log"

    if [[ "$DRY_RUN" == true ]]; then printf '%s\n' "$prompt"; exit 0; fi

    before_status="$(status_snapshot)"
    log "Run $run_number/$MAX_RUNS: $next_item"
    run_agent "$prompt" "$output_file" || die "agent run $run_number failed — see $output_file"

    after_status="$(status_snapshot)"
    after_count="$(unchecked_count)"

    if [[ "$after_status" == "$before_status" ]]; then
        no_change_runs=$((no_change_runs + 1))
        log "No file changes ($no_change_runs/$MAX_NO_CHANGE_RUNS)"
    else
        no_change_runs=0
        commit_changes "$run_number" "$before_count" "$after_count"
    fi

    if [[ "$after_count" -lt "$before_count" ]]; then
        no_progress_runs=0
        log "Progress: $before_count -> $after_count unchecked"
    else
        no_progress_runs=$((no_progress_runs + 1))
        log "Checkbox count unchanged ($no_progress_runs/$MAX_NO_PROGRESS_RUNS)"
    fi

    [[ "$after_count" -eq 0 ]] && { log "Plan complete."; exit 0; }
    [[ "$MAX_NO_CHANGE_RUNS" -gt 0 && "$no_change_runs" -ge "$MAX_NO_CHANGE_RUNS" ]] && die "stopped: no file changes"
    [[ "$MAX_NO_PROGRESS_RUNS" -gt 0 && "$no_progress_runs" -ge "$MAX_NO_PROGRESS_RUNS" ]] && die "stopped: no checkbox progress"
done

die "stopped: max runs ($MAX_RUNS). Remaining: $(unchecked_count)"
