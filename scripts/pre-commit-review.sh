#!/bin/bash
# Hook: automated code review before every commit
# Exit 0 = allow, Exit 2 = block (MUST FIX found)
#
# Triggered by .claude/hooks.json PreToolUse on "git commit"
# This is a TEMPLATE — customize the [SPEC] sections for your project.
#
# Review levels (set via REVIEW_LEVEL env var or bootstrap):
#   simple = bash checks only (grep, compile, tests) — fast, free
#   hybrid = bash + Sonnet AI review (warnings only) — balanced
#   deep   = bash + Opus AI review (warnings only) — thorough
#
# Philosophy: agents and skills are for on-demand tasks.
# Hooks are for guarantees that must never fail.

set -euo pipefail

# ─── Review Level ───────────────────────────────────────────
REVIEW_LEVEL="${REVIEW_LEVEL:-hybrid}"   # simple | hybrid | deep

# ─── Configuration ──────────────────────────────────────────
LANG_EXTENSIONS="py"
SOURCE_DIR="src"
TEST_DIR="tests"
TEST_SUFFIX=".py"               # tests seguem o padrão test_<modulo>.py
COMPILE_CMD="ruff check src/ --quiet"
TEST_CMD="pytest --tb=short -q"
LINT_CMD=""                     # coberto pelo PostToolUse hook (lint-check.sh)

# ─── Detect staged source files ─────────────────────────────
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR -- "*.$LANG_EXTENSIONS" | grep "^${SOURCE_DIR}/" | grep -v '__tests__\|test_\|_test\.\|\.test\.\|\.spec\.' || true)

if [ -z "$STAGED_FILES" ]; then
  echo "✅ No source files staged — skipping review"
  exit 0
fi

FILE_COUNT=$(echo "$STAGED_FILES" | wc -l | tr -d ' ')
echo "🔍 Code Review: checking $FILE_COUNT file(s)..."
echo ""

MUST_FIX=0
SHOULD_FIX=0
WARNINGS=""

# ═══════════════════════════════════════════════════════════
# UNIVERSAL CHECKS (apply to any project)
# ═══════════════════════════════════════════════════════════

# ─── 1. Compilation / Type check ────────────────────────────
if [ -n "$COMPILE_CMD" ]; then
  echo "── Compilation ──"
  COMPILE_OUTPUT=$($COMPILE_CMD 2>&1) || true
  COMPILE_EXIT=$?
  if [ $COMPILE_EXIT -ne 0 ]; then
    echo "❌ MUST FIX: Compilation errors"
    echo "$COMPILE_OUTPUT" | head -20
    MUST_FIX=$((MUST_FIX + 1))
  else
    echo "✅ Compilation OK"
  fi
fi

# ─── 2. Tests passing ──────────────────────────────────────
if [ -n "$TEST_CMD" ]; then
  echo ""
  echo "── Tests ──"
  TEST_OUTPUT=$($TEST_CMD 2>&1) || true
  TEST_EXIT=$?
  if [ $TEST_EXIT -ne 0 ]; then
    echo "❌ MUST FIX: Tests failing"
    echo "$TEST_OUTPUT" | tail -15
    MUST_FIX=$((MUST_FIX + 1))
  else
    echo "✅ Tests passing"
  fi
fi

# ─── 3. Security: no hardcoded secrets ──────────────────────
echo ""
echo "── Security ──"
SECRET_PATTERNS='(API_KEY|api_key|apiKey|SECRET|secret|PASSWORD|password|TOKEN|token|PRIVATE_KEY)\s*[:=]\s*["\x27][A-Za-z0-9]'
SECRETS_FOUND=""
for f in $STAGED_FILES; do
  MATCH=$(grep -nEi "$SECRET_PATTERNS" "$f" 2>/dev/null | grep -v 'process\.env\|os\.environ\|os\.Getenv\|env::var\|config\.\|Config\.\|\.env\|example\|placeholder\|TODO\|SPEC' || true)
  if [ -n "$MATCH" ]; then
    SECRETS_FOUND="$SECRETS_FOUND\n  $f: $MATCH"
  fi
done

if [ -n "$SECRETS_FOUND" ]; then
  echo "❌ MUST FIX: Possible hardcoded secrets"
  echo -e "$SECRETS_FOUND"
  MUST_FIX=$((MUST_FIX + 1))
else
  echo "✅ No hardcoded secrets"
fi

# ─── 4. Quality: language-specific checks ───────────────────
echo ""
echo "── Quality ──"
for f in $STAGED_FILES; do
  # print() — deve usar logging
  PRINT=$(grep -n '^[^#]*\bprint(' "$f" 2>/dev/null || true)
  if [ -n "$PRINT" ]; then
    WARNINGS="$WARNINGS\n  SHOULD FIX [$f]: Use logger em vez de print()"
    SHOULD_FIX=$((SHOULD_FIX + 1))
  fi

  # type: ignore sem especificar o código
  TYPE_IGNORE=$(grep -n '# type: ignore$' "$f" 2>/dev/null || true)
  if [ -n "$TYPE_IGNORE" ]; then
    WARNINGS="$WARNINGS\n  SHOULD FIX [$f]: # type: ignore sem código — use # type: ignore[<code>]"
    SHOULD_FIX=$((SHOULD_FIX + 1))
  fi

  # bare except
  BARE_EXCEPT=$(grep -n '^\s*except\s*:' "$f" 2>/dev/null || true)
  if [ -n "$BARE_EXCEPT" ]; then
    WARNINGS="$WARNINGS\n  SHOULD FIX [$f]: bare except — especifique a exceção"
    SHOULD_FIX=$((SHOULD_FIX + 1))
  fi
done

if [ $SHOULD_FIX -eq 0 ]; then
  echo "✅ Quality checks passed"
else
  echo "⚠️  $SHOULD_FIX quality warning(s) found"
  echo -e "$WARNINGS"
fi

# ─── 5. Error handling: external calls need try/catch ───────
echo ""
echo "── Error Handling ──"
ERR_ISSUES=""
for f in $STAGED_FILES; do
  case "$LANG_EXTENSIONS" in
    ts|tsx|js|jsx)
      HAS_FETCH=$(grep -c 'await fetch\|await axios\|\.fromUrl(' "$f" 2>/dev/null || true)
      HAS_CATCH=$(grep -c 'catch\s*(' "$f" 2>/dev/null || true)
      ;;
    py)
      HAS_FETCH=$(grep -c 'requests\.\|httpx\.\|aiohttp\.\|urllib' "$f" 2>/dev/null || true)
      HAS_CATCH=$(grep -c 'except\s' "$f" 2>/dev/null || true)
      ;;
    go)
      HAS_FETCH=$(grep -c 'http\.Get\|http\.Post\|http\.Do' "$f" 2>/dev/null || true)
      HAS_CATCH=$(grep -c 'if err != nil' "$f" 2>/dev/null || true)
      ;;
    *)
      HAS_FETCH=0
      HAS_CATCH=0
      ;;
  esac

  if [ "$HAS_FETCH" -gt 0 ] && [ "$HAS_CATCH" -eq 0 ]; then
    ERR_ISSUES="$ERR_ISSUES\n  SHOULD FIX [$f]: External calls without error handling"
    SHOULD_FIX=$((SHOULD_FIX + 1))
  fi
done

if [ -z "$ERR_ISSUES" ]; then
  echo "✅ Error handling OK"
else
  echo -e "$ERR_ISSUES"
fi

# ─── 6. Test coverage gap ──────────────────────────────────
echo ""
echo "── Test Coverage ──"
UNTESTED=""
for f in $STAGED_FILES; do
  BASENAME=$(basename "$f" ".$LANG_EXTENSIONS")
  # Padrão: src/bot/handlers.py → tests/test_handlers.py
  TEST_FILE="${TEST_DIR}/test_${BASENAME}${TEST_SUFFIX}"
  if [ ! -f "$TEST_FILE" ]; then
    UNTESTED="$UNTESTED\n  CONSIDER [$f]: sem arquivo de teste em $TEST_FILE"
  fi
done

if [ -z "$UNTESTED" ]; then
  echo "✅ Todos os arquivos alterados têm testes"
else
  echo "ℹ️  Arquivos sem teste (considere adicionar):"
  echo -e "$UNTESTED"
fi

# ─── 7. Scope discipline: "Não alterou" ──────────────────────
echo ""
echo "── Scope ──"
echo "ℹ️  CONSIDER: Inclua 'Não alterou:' no commit message listando arquivos/módulos NÃO alterados intencionalmente"
echo "   Isso ajuda revisores a entender o escopo pretendido da mudança."

# ═══════════════════════════════════════════════════════════
# CHECKS ESPECÍFICOS DO FPBOT
# ═══════════════════════════════════════════════════════════

echo ""
echo "── fpbot: regras específicas ──"
FPBOT_ISSUES=""

for f in $STAGED_FILES; do
  # Secrets hardcoded (xoxb-, xapp-, sk-ant-)
  HARDCODED_TOKEN=$(grep -nE '(xoxb-|xapp-|sk-ant-)[A-Za-z0-9]' "$f" 2>/dev/null || true)
  if [ -n "$HARDCODED_TOKEN" ]; then
    echo "❌ MUST FIX [$f]: Token Slack/Anthropic hardcoded — use os.environ"
    MUST_FIX=$((MUST_FIX + 1))
  fi

  # Supabase service key exposta em código
  SUPABASE_KEY=$(grep -nE 'eyJ[A-Za-z0-9]{20,}' "$f" 2>/dev/null || true)
  if [ -n "$SUPABASE_KEY" ]; then
    echo "❌ MUST FIX [$f]: Possível JWT/service key hardcoded — use SUPABASE_SERVICE_KEY env var"
    MUST_FIX=$((MUST_FIX + 1))
  fi

  # Lógica pesada antes do ACK no Slack (violação do timeout de 3s)
  # Detecta se say() é chamado DEPOIS de search_pages ou answer() no mesmo handler
  ACK_ORDER=$(grep -n 'search_pages\|answer(' "$f" 2>/dev/null || true)
  FIRST_SAY=$(grep -n 'say(' "$f" 2>/dev/null | head -1 | cut -d: -f1 || true)
  FIRST_SEARCH=$(grep -n 'search_pages\|answer(' "$f" 2>/dev/null | head -1 | cut -d: -f1 || true)
  if [ -n "$FIRST_SAY" ] && [ -n "$FIRST_SEARCH" ] && [ "$FIRST_SEARCH" -lt "$FIRST_SAY" ] 2>/dev/null; then
    FPBOT_ISSUES="$FPBOT_ISSUES\n  SHOULD FIX [$f]: busca/resposta antes do ACK (say) — risco de timeout Slack (3s)"
    SHOULD_FIX=$((SHOULD_FIX + 1))
  fi
done

if [ -z "$FPBOT_ISSUES" ]; then
  echo "✅ Regras fpbot OK"
else
  echo -e "$FPBOT_ISSUES"
fi

# ═══════════════════════════════════════════════════════════
# AI REVIEW (hybrid/deep mode only)
# ═══════════════════════════════════════════════════════════
if [ "$REVIEW_LEVEL" = "hybrid" ] || [ "$REVIEW_LEVEL" = "deep" ]; then
  echo ""
  echo "── AI Review ($(echo $REVIEW_LEVEL | tr '[:lower:]' '[:upper:]')) ──"

  if [ "$REVIEW_LEVEL" = "deep" ]; then
    export AI_REVIEW_MODEL="opus"
    export AI_REVIEW_MAX_TOKENS=800
  else
    export AI_REVIEW_MODEL="sonnet"
    export AI_REVIEW_MAX_TOKENS=500
  fi

  if [ -f "scripts/ai-review.sh" ]; then
    AI_OUTPUT=$(bash scripts/ai-review.sh 2>&1) || true
    if [ -n "$AI_OUTPUT" ]; then
      echo "$AI_OUTPUT"
      # Count AI warnings (don't block, just count)
      AI_WARNINGS=$(echo "$AI_OUTPUT" | grep -c '⚠️\|SHOULD FIX' || true)
      if [ "$AI_WARNINGS" -gt 0 ]; then
        SHOULD_FIX=$((SHOULD_FIX + AI_WARNINGS))
      fi
    fi
  else
    echo "⚠️  scripts/ai-review.sh not found — skipping AI review"
  fi
fi

# ─── Summary ────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $MUST_FIX -gt 0 ]; then
  echo "🚫 BLOCKED: $MUST_FIX MUST FIX issue(s) found"
  echo "   Fix the issues above before committing."
  exit 2
elif [ $SHOULD_FIX -gt 0 ]; then
  echo "⚠️  PASSED with $SHOULD_FIX warning(s) [mode: $REVIEW_LEVEL]"
  echo "   Consider fixing before deploying."
  exit 0
else
  echo "✅ All checks passed! [mode: $REVIEW_LEVEL]"
  exit 0
fi
