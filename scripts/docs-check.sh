#!/bin/bash
# Hook: check if code changes have corresponding documentation updates.
# Runs on PreToolUse for "git commit" — warns but never blocks.
#
# Philosophy: PRDs come from Obsidian, code gets implemented,
# decisions and changes flow BACK to Obsidian. This hook ensures
# the loop closes on every commit.
#
# Monitors: src/, scripts/, tools/, .claude/ (not just src/)
# Severity: SHOULD FIX (not just CONSIDER)

set -euo pipefail

# ─── Configuration ──────────────────────────────────────────
# [SPEC] Adjust for your project
CODE_DIRS=("src" "scripts" "tools" ".claude")   # All code directories to monitor
DOCS_DIR="docs"                                   # Obsidian vault directory
ENV_EXAMPLE=".env.example"                        # Env example file
CLAUDE_MD="CLAUDE.md"                             # Project hub
CHANGELOG="CHANGELOG.md"                          # Changelog file
README="README.md"                                # README file

# ─── Build staged file lists ────────────────────────────────
STAGED_ALL=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)

# Skip if nothing staged
if [ -z "$STAGED_ALL" ]; then
  exit 0
fi

# Staged code files (across all monitored directories)
STAGED_CODE=""
for dir in "${CODE_DIRS[@]}"; do
  MATCH=$(git diff --cached --name-only --diff-filter=ACMR -- "${dir}/" 2>/dev/null || true)
  if [ -n "$MATCH" ]; then
    if [ -n "$STAGED_CODE" ]; then
      STAGED_CODE="${STAGED_CODE}
${MATCH}"
    else
      STAGED_CODE="$MATCH"
    fi
  fi
done

# Skip if no code files staged
if [ -z "$STAGED_CODE" ]; then
  exit 0
fi

# Staged documentation files
STAGED_DOCS=$(git diff --cached --name-only --diff-filter=ACMR -- "${DOCS_DIR}/" "${CLAUDE_MD}" "${README}" "${ENV_EXAMPLE}" "${CHANGELOG}" 2>/dev/null || true)

CODE_COUNT=$(echo "$STAGED_CODE" | wc -l | tr -d ' ')
WARNINGS=0

echo ""
echo "── Docs Check ──"

# ─── Check 1: Code changed but no docs updated ─────────────
if [ -z "$STAGED_DOCS" ]; then
  echo "⚠️  SHOULD FIX: ${CODE_COUNT} code file(s) changed but no documentation updated"
  echo "   Checklist: CLAUDE.md | README.md | CHANGELOG.md | .env.example | ADR | Gotchas"
  echo "   Changed:"
  echo "$STAGED_CODE" | head -5 | sed 's/^/     /'
  [ "$CODE_COUNT" -gt 5 ] && echo "     ... and $((CODE_COUNT - 5)) more"
  WARNINGS=$((WARNINGS + 1))
fi

# ─── Check 2: New files without CLAUDE.md/README update ─────
NEW_CODE_FILES=""
for dir in "${CODE_DIRS[@]}"; do
  MATCH=$(git diff --cached --name-only --diff-filter=A -- "${dir}/" 2>/dev/null || true)
  if [ -n "$MATCH" ]; then
    if [ -n "$NEW_CODE_FILES" ]; then
      NEW_CODE_FILES="${NEW_CODE_FILES}
${MATCH}"
    else
      NEW_CODE_FILES="$MATCH"
    fi
  fi
done

if [ -n "$NEW_CODE_FILES" ]; then
  CLAUDE_STAGED=$(echo "$STAGED_ALL" | grep -c "${CLAUDE_MD}" || true)
  README_STAGED=$(echo "$STAGED_ALL" | grep -c "${README}" || true)
  if [ "$CLAUDE_STAGED" -eq 0 ] && [ "$README_STAGED" -eq 0 ]; then
    NEW_COUNT=$(echo "$NEW_CODE_FILES" | wc -l | tr -d ' ')
    echo "⚠️  SHOULD FIX: ${NEW_COUNT} new file(s) — update CLAUDE.md module map or README structure"
    echo "$NEW_CODE_FILES" | head -5 | sed 's/^/     + /'
    [ "$NEW_COUNT" -gt 5 ] && echo "     ... and $((NEW_COUNT - 5)) more"
    WARNINGS=$((WARNINGS + 1))
  fi
fi

# ─── Check 3: Config/env changes without .env.example ───────
CONFIG_CHANGED=$(echo "$STAGED_CODE" | grep -i 'config' || true)
if [ -n "$CONFIG_CHANGED" ]; then
  # Check if new env vars were added (Node, Python, Go patterns)
  NEW_ENV_VARS=""
  for dir in "${CODE_DIRS[@]}"; do
    MATCH=$(git diff --cached -- "${dir}/" | grep -E '^[+].*process\.env\.|^[+].*os\.environ\.|^[+].*os\.Getenv\(' | grep -v '^+++' || true)
    if [ -n "$MATCH" ]; then
      NEW_ENV_VARS="${NEW_ENV_VARS}${MATCH}"
    fi
  done
  if [ -n "$NEW_ENV_VARS" ]; then
    ENV_STAGED=$(echo "$STAGED_ALL" | grep -c "${ENV_EXAMPLE}" || true)
    if [ "$ENV_STAGED" -eq 0 ]; then
      echo "⚠️  SHOULD FIX: New environment variables detected — update ${ENV_EXAMPLE}"
      echo "$NEW_ENV_VARS" | head -5 | sed 's/^/     /'
      WARNINGS=$((WARNINGS + 1))
    fi
  fi
fi

# ─── Check 4: Feature commit without CHANGELOG update ───────
# Detect commit message from git (if available) or check for feat: pattern
COMMIT_MSG=""
# Try to get the commit message being prepared
if [ -f ".git/COMMIT_EDITMSG" ]; then
  COMMIT_MSG=$(head -1 .git/COMMIT_EDITMSG 2>/dev/null || true)
fi

# Also check: are there new skills, commands, agents, or scripts?
NEW_SKILLS=$(echo "$STAGED_ALL" | grep -c '\.claude/skills/' || true)
NEW_COMMANDS=$(echo "$STAGED_ALL" | grep -c '\.claude/commands/' || true)
NEW_AGENTS=$(echo "$STAGED_ALL" | grep -c '\.claude/agents/' || true)
NEW_SCRIPTS=$(echo "$STAGED_ALL" | grep -c 'scripts/.*\.sh' || true)
NEW_FEATURES=$((NEW_SKILLS + NEW_COMMANDS + NEW_AGENTS))

CHANGELOG_STAGED=$(echo "$STAGED_ALL" | grep -c "${CHANGELOG}" || true)

if [ "$CHANGELOG_STAGED" -eq 0 ]; then
  # Check if this looks like a feature (new files in .claude/ or scripts/)
  if [ "$NEW_FEATURES" -gt 0 ]; then
    echo "⚠️  SHOULD FIX: New skills/commands/agents added but CHANGELOG.md not updated"
    echo "     ${NEW_SKILLS} skill(s), ${NEW_COMMANDS} command(s), ${NEW_AGENTS} agent(s)"
    WARNINGS=$((WARNINGS + 1))
  elif [ "$NEW_SCRIPTS" -gt 0 ]; then
    echo "⚠️  CONSIDER: New script(s) added — consider updating CHANGELOG.md"
    WARNINGS=$((WARNINGS + 1))
  fi
fi

# ─── Check 5: ADR-worthy changes without ADR ────────────────
# Detect architectural changes: new deps, new directories, hook changes
HOOKS_CHANGED=$(echo "$STAGED_ALL" | grep -c 'hooks\.json' || true)
NEW_DIRS=""
for dir in "${CODE_DIRS[@]}"; do
  # Check for files in new subdirectories
  MATCH=$(git diff --cached --name-only --diff-filter=A -- "${dir}/" 2>/dev/null | awk -F/ '{print $1"/"$2}' | sort -u || true)
  if [ -n "$MATCH" ]; then
    NEW_DIRS="${NEW_DIRS}${MATCH} "
  fi
done

ADR_STAGED=$(echo "$STAGED_ALL" | grep -c 'docs/architecture/' || true)
if [ "$HOOKS_CHANGED" -gt 0 ] && [ "$ADR_STAGED" -eq 0 ]; then
  echo "⚠️  CONSIDER: hooks.json changed — consider writing an ADR in docs/architecture/"
  WARNINGS=$((WARNINGS + 1))
fi

# ─── Summary ───────────────────────────────────────────────
if [ $WARNINGS -eq 0 ]; then
  echo "✅ Documentation in sync"
else
  echo ""
  echo "   📝 ${WARNINGS} documentation reminder(s)"
  echo "   Checklist: CLAUDE.md | README.md | CHANGELOG.md | .env.example | ADR | docs/"
  echo "   Run: grep -rE '\\[SPEC\\]|TODO' CLAUDE.md docs/ .env.example | head -10"
fi

# Never block — only warn
exit 0
