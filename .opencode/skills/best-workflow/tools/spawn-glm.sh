#!/usr/bin/env bash
# spawn-glm.sh — Spawn one agent for Orchestration Workflow
#
# Pipes prompt from file through stdin to OpenCode or Pi CLI. Pass -m to override with a specific model.
# Stdin piping avoids shell escaping issues with complex prompt content.
#
# Agents run until completion — no max-turns limit.
#
# Usage:
#   spawn-glm.sh -n NAME -f PROMPT_FILE [-m MODEL]
#
# Arguments:
#   -n, --name         Agent name (log: ${REPO_ROOT}/tmp/{NAME}-log.txt)
#   -f, --prompt-file  Path to the prompt text file
#   -m, --model        Model to use (optional)
#   --pi               Use pi to spawn subagents
#
# Output (stdout):
#   SPAWNED|name|pid|log_file
#
# Examples:
#   spawn-glm.sh -n sec-reviewer -f ${REPO_ROOT}/tmp/sec-reviewer-prompt.txt
#   spawn-glm.sh -n s1-reviewer -f ${REPO_ROOT}/tmp/s1-reviewer-prompt.txt -m zai/glm-5.1

set -euo pipefail

# Source .bestworkflowrc from project-local config directories (silently skip if missing)
for _rc_dir in ".agents" ".opencode" ".pi" "."; do
  _rc_file="${_rc_dir}/.bestworkflowrc"
  [[ -f "$_rc_file" ]] && source "$_rc_file"
done

REPO_ROOT="$PWD"

# ── Parse arguments ──
NAME="" PROMPT_FILE="" MODEL="" PIDEV=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)        NAME="$2";        shift 2 ;;
    -f|--prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    -m|--model)       MODEL="$2";       shift 2 ;;
    -h|--help)        sed -n '2,/^$/p' "$0" | sed 's/^# \?//'; exit 0 ;;
    --pi)             PIDEV=1 ; shift 1 ;;
    *) echo "ERROR: Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Check if bestworkflow_spawn function is defined. If it is call it and skip rest of this script.
if declare -f bestworkflow_spawn &>/dev/null; then
  bestworkflow_spawn
  exit $?
fi

if [[ -n "$PIDEV" ]]; then
  command -v pi &>/dev/null || \
  { echo "ERROR: pi not found in PATH. Install pi first." >&2; exit 1; }
else
  command -v opencode &>/dev/null || \
  { echo "ERROR: opencode not found in PATH. Install OpenCode first." >&2; exit 1; }
fi

# ── Validate ──
[[ -z "$NAME" ]]        && { echo "ERROR: -n NAME required" >&2; exit 1; }
[[ -z "$PROMPT_FILE" ]] && { echo "ERROR: -f PROMPT_FILE required" >&2; exit 1; }
[[ ! -f "$PROMPT_FILE" ]] && \
  { echo "ERROR: Prompt file not found: $PROMPT_FILE" >&2; exit 1; }
[[ ! -s "$PROMPT_FILE" ]] && \
  { echo "ERROR: Prompt file is empty: $PROMPT_FILE" >&2; exit 1; }

# Reject NAME values that would enable path traversal or break filenames
case "$NAME" in
  */*|*\\*|*\|*|*\&*|*\$*|*\"*|*\`*)
    echo "ERROR: NAME contains unsafe characters (/, \\, |, &, \$, \", \`): $NAME" >&2
    exit 1
    ;;
esac

# Fall back to BESTWORKFLOW_MODEL env var if -m not given
[[ -z "$MODEL" && -n "${BESTWORKFLOW_MODEL:-}" ]] && MODEL="$BESTWORKFLOW_MODEL"

mkdir -p "${REPO_ROOT}/tmp"
LOG="${REPO_ROOT}/tmp/${NAME}-log.txt"
STATUS="${REPO_ROOT}/tmp/${NAME}-status.txt"

# ── Spawn: pipe prompt file → opencode run ──
# Model defaults to opencode's configured model; -m overrides when provided.
if [[ -n "$PIDEV" ]]; then
  if [[ -n "$MODEL" ]]; then
    pi --print --model "$MODEL" --session $LOG --name $NAME "$(cat "$PROMPT_FILE")" > /dev/null 2>&1 &
  else
    pi --print  --session $LOG --name $NAME "$(cat "$PROMPT_FILE")" > /dev/null 2>&1 &
  fi
else
  if [[ -n "$MODEL" ]]; then
      opencode run \
    -m "$MODEL" \
    --format json \
    < "$PROMPT_FILE" > "$LOG" 2>&1 &
  else
    opencode run \
    --format json \
    < "$PROMPT_FILE" > "$LOG" 2>&1 &
  fi
fi

PID=$!

RESULT="SPAWNED|${NAME}|${PID}|${LOG}"

# Write to status file (reliable) + stdout (best-effort).
printf '%s\n' "$RESULT" > "$STATUS"
echo "$RESULT"
