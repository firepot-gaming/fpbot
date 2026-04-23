#!/bin/bash
# AI-powered code review via Claude Code CLI
# Called by pre-commit-review.sh in hybrid/deep mode.
#
# Uses `claude` CLI (runs on your Max/Pro plan — no API key needed).
# Falls back to Anthropic API if CLI not available.
# Returns warnings only — never blocks (bash checks handle blocking).
#
# Model: configurable via AI_REVIEW_MODEL env var
#   hybrid → sonnet (default)
#   deep   → opus

set -euo pipefail

# ─── Config ─────────────────────────────────────────────────
AI_REVIEW_MODEL="${AI_REVIEW_MODEL:-sonnet}"
AI_REVIEW_MAX_DIFF_LINES="${AI_REVIEW_MAX_DIFF_LINES:-300}"

# ─── Get staged diff ────────────────────────────────────────
DIFF=$(git diff --cached --diff-filter=ACMR -- '*.ts' '*.py' '*.go' '*.rs' '*.js' '*.tsx' '*.jsx' | head -n "$AI_REVIEW_MAX_DIFF_LINES")

if [ -z "$DIFF" ]; then
  echo "✅ AI Review: no diff to analyze"
  exit 0
fi

# ─── Project context ────────────────────────────────────────
PROJECT_CONTEXT=""
if [ -f ".claude/skills/code-review/SKILL.md" ]; then
  PROJECT_CONTEXT=$(head -40 .claude/skills/code-review/SKILL.md)
fi

# ─── Build prompt ──────────────────────────────────────────
SYSTEM_PROMPT="You are a code reviewer. Analyze the git diff and report issues.

Rules:
- Only report real, actionable issues — no generic advice
- Focus on: logic bugs, edge cases, missing error handling, security risks, business logic errors
- Do NOT report style/formatting issues (linter handles those)
- Do NOT report missing tests (bash check handles that)
- Do NOT report compilation errors (tsc handles that)
- Be concise: max 3-5 findings, one line each
- If the diff looks clean, just say 'No issues found'

${PROJECT_CONTEXT}
Output format (one per line):
⚠️ SHOULD FIX [file]: description
ℹ️ CONSIDER [file]: description"

USER_PROMPT="Review this staged diff:

${DIFF}"

# ─── Method 1: Claude Code CLI (uses Max/Pro plan) ─────────
if command -v claude &> /dev/null; then
  AI_OUTPUT=$(echo "$USER_PROMPT" | claude --print \
    --model "$AI_REVIEW_MODEL" \
    --append-system-prompt "$SYSTEM_PROMPT" \
    --bare \
    --allowedTools "" \
    2>/dev/null) || true

  if [ -n "$AI_OUTPUT" ]; then
    echo "$AI_OUTPUT"
    exit 0
  fi
fi

# ─── Method 2: Anthropic API (fallback, requires API key) ──
# [SPEC] Remove this section if you only use Claude Code CLI

API_KEY="${ANTHROPIC_API_KEY:-}"

if [ -z "$API_KEY" ]; then
  for env_file in ".env" "$HOME/.env" "$HOME/.config/anthropic/.env"; do
    if [ -f "$env_file" ]; then
      CANDIDATE=$(grep '^ANTHROPIC_API_KEY=' "$env_file" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)
      if [ -n "$CANDIDATE" ]; then
        API_KEY="$CANDIDATE"
        break
      fi
    fi
  done
fi

if [ -z "$API_KEY" ]; then
  echo "⚠️  AI Review: neither claude CLI nor ANTHROPIC_API_KEY available"
  echo "   Install Claude Code CLI or set ANTHROPIC_API_KEY"
  exit 0
fi

# Map model aliases to full names for API
case "$AI_REVIEW_MODEL" in
  sonnet) API_MODEL="claude-sonnet-4-20250514" ;;
  opus)   API_MODEL="claude-opus-4-20250514" ;;
  haiku)  API_MODEL="claude-haiku-4-5-20251001" ;;
  *)      API_MODEL="$AI_REVIEW_MODEL" ;;
esac

AI_REVIEW_MAX_TOKENS="${AI_REVIEW_MAX_TOKENS:-500}"

export API_KEY API_MODEL AI_REVIEW_MAX_TOKENS
export REVIEW_DIFF="$DIFF"
export REVIEW_SYSTEM_PROMPT="$SYSTEM_PROMPT"

AI_OUTPUT=$(python3 << 'PYEOF'
import json, sys, os, urllib.request, urllib.error

api_key = os.environ.get("API_KEY", "")
model = os.environ.get("API_MODEL", "claude-sonnet-4-20250514")
max_tokens = int(os.environ.get("AI_REVIEW_MAX_TOKENS", "500"))
diff = os.environ.get("REVIEW_DIFF", "")
system_prompt = os.environ.get("REVIEW_SYSTEM_PROMPT", "")

if not api_key or not diff:
    sys.exit(0)

payload = json.dumps({
    "model": model,
    "max_tokens": max_tokens,
    "system": system_prompt,
    "messages": [{"role": "user", "content": f"Review this staged diff:\n\n{diff}"}]
}).encode("utf-8")

req = urllib.request.Request(
    "https://api.anthropic.com/v1/messages",
    data=payload,
    headers={
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    },
)

try:
    with urllib.request.urlopen(req, timeout=25) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        if "content" in data and len(data["content"]) > 0:
            print(data["content"][0]["text"])
except Exception as e:
    print(f"⚠️  AI Review API fallback: {e}")
PYEOF
) || true

if [ -n "$AI_OUTPUT" ]; then
  echo "$AI_OUTPUT"
fi

exit 0
