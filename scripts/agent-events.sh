#!/bin/bash
# Agent Event Protocol — structured JSONL event emitter for multi-agent observability.
# Source this file from hooks and scripts to emit events to logs/agent-events.jsonl.
#
# Usage:
#   source "$(dirname "$0")/agent-events.sh"
#   emit_agent_start "security-auditor" "audit src/"
#   emit_agent_complete "security-auditor" "ok" "No issues found"
#
# Level: L4

# ─── Configuration ──────────────────────────────────────────
# Find project root: look for CLAUDE.md starting from script location
_blueprint_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
# If sourced from a different cwd, fallback to git root or pwd
if [ ! -f "${_blueprint_root}/CLAUDE.md" ]; then
  _blueprint_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
AGENT_EVENTS_DIR="${_blueprint_root}/logs"
AGENT_EVENTS_LOG="${AGENT_EVENTS_DIR}/agent-events.jsonl"
BLUEPRINT_SESSION_ID="${BLUEPRINT_SESSION_ID:-s_$(date +%s)_$$}"

# Ensure logs directory exists
mkdir -p "$AGENT_EVENTS_DIR"

# ─── Helpers ────────────────────────────────────────────────

# Escape a string for safe JSON embedding
_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# ─── Core emitter ───────────────────────────────────────────
# emit_event <event_type> <agent_name> [key=value ...]
# Writes one JSONL line with timestamp, event type, agent, session, pid, and extra fields.
emit_event() {
  local event_type="$1"
  local agent_name="$2"
  shift 2

  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  local pid="$$"

  # Build extra fields
  local extras=""
  for kv in "$@"; do
    local key="${kv%%=*}"
    local val="${kv#*=}"
    val="$(_json_escape "$val")"
    extras="${extras},\"${key}\":\"${val}\""
  done

  local line="{\"ts\":\"${ts}\",\"event\":\"${event_type}\",\"agent\":\"$(_json_escape "$agent_name")\",\"session\":\"${BLUEPRINT_SESSION_ID}\",\"pid\":\"${pid}\"${extras}}"

  # Write with atomic locking (mkdir is atomic on all POSIX systems)
  local lockdir="${AGENT_EVENTS_LOG}.lock"
  local retries=0
  while ! mkdir "$lockdir" 2>/dev/null; do
    retries=$((retries + 1))
    if [ $retries -gt 100 ]; then
      # Stale lock — force remove and retry
      rmdir "$lockdir" 2>/dev/null || rm -rf "$lockdir"
      retries=0
    fi
    sleep 0.01
  done
  printf '%s\n' "$line" >> "$AGENT_EVENTS_LOG"
  rmdir "$lockdir" 2>/dev/null
}

# ─── Typed emitters ─────────────────────────────────────────

# emit_agent_start <agent_name> <task_description> [agent_id]
emit_agent_start() {
  local agent_name="$1"
  local task="$2"
  local agent_id="${3:-}"
  if [ -n "$agent_id" ]; then
    emit_event "agent:start" "$agent_name" "task=$task" "agent_id=$agent_id"
  else
    emit_event "agent:start" "$agent_name" "task=$task"
  fi
}

# emit_agent_progress <agent_name> <tool_name> <detail>
emit_agent_progress() {
  local agent_name="$1"
  local tool_name="$2"
  local detail="$3"
  emit_event "agent:progress" "$agent_name" "tool=$tool_name" "detail=$detail"
}

# emit_agent_complete <agent_name> <status: ok|error|warning> <summary> [agent_id]
emit_agent_complete() {
  local agent_name="$1"
  local agent_status="$2"
  local summary="$3"
  local agent_id="${4:-}"
  if [ -n "$agent_id" ]; then
    emit_event "agent:complete" "$agent_name" "status=$agent_status" "summary=$summary" "agent_id=$agent_id"
  else
    emit_event "agent:complete" "$agent_name" "status=$agent_status" "summary=$summary"
  fi
}

# emit_agent_finding <agent_name> <severity> <category> <message>
emit_agent_finding() {
  local agent_name="$1"
  local severity="$2"
  local category="$3"
  local message="$4"
  emit_event "agent:finding" "$agent_name" "severity=$severity" "category=$category" "message=$message"
}

# emit_session_start <session_id> <agents_planned>
emit_session_start() {
  local session_id="$1"
  local agents_planned="$2"
  emit_event "session:start" "_orchestrator" "session_id=$session_id" "agents_planned=$agents_planned"
}

# emit_session_end <session_id> <summary>
emit_session_end() {
  local session_id="$1"
  local summary="$2"
  emit_event "session:end" "_orchestrator" "session_id=$session_id" "summary=$summary"
}

# emit_flow <from_agent> <to_agent> <flow_type: command|data|audit|feedback|sync|insight> <data>
emit_flow() {
  local from_agent="$1"
  local to_agent="$2"
  local flow_type="$3"
  local data="$4"
  emit_event "flow:${flow_type}" "$from_agent" "to=$to_agent" "data=$data"
}
