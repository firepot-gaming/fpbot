#!/bin/bash
# Hook: security check before bash commands
# Exit 0 = allow, Exit 2 = block

CMD="$1"

# Block rm -rf on critical directories
if echo "$CMD" | grep -qE "rm\s+-rf\s+(/|src/|docs/|\.claude/)"; then
  echo "🚫 Blocked: destructive command on protected directory"
  exit 2
fi

# Block secret exposure
if echo "$CMD" | grep -qE "cat\s+\.env|echo\s+\\\$.*SECRET|echo\s+\\\$.*KEY"; then
  echo "🚫 Blocked: potential secret exposure"
  exit 2
fi

exit 0
