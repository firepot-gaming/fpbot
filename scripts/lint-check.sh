#!/bin/bash
# Hook: lint check after file write
# Exit 0 = allow, Exit 2 = block
# [SPEC] Customize for your stack

FILE="$1"

case "$FILE" in
  *.py)
    ruff check "$FILE" --quiet 2>/dev/null
    ;;
  *.ts|*.tsx|*.js|*.jsx)
    npx eslint "$FILE" --quiet 2>/dev/null
    ;;
  *)
    exit 0
    ;;
esac

if [ $? -ne 0 ]; then
  echo "⚠️  Lint issues found in $FILE"
  exit 0  # warn but don't block (change to exit 2 to block)
fi

exit 0
