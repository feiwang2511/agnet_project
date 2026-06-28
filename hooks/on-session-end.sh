#!/bin/bash
# 触发时机：Claude Code session 结束时
# 做什么：从会话中提取 corrections、decisions、discoveries，追加到 corrections.log。

set -u

AGENTOS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="$AGENTOS_DIR/corrections.log"

SESSION_PAYLOAD="$(cat)"

PROMPT='Review this session transcript or hook payload.

Extract only durable AgentOS learning items:
1. Corrections the user made, format: CORRECTION: ...
2. Decisions made with rationale, format: DECISION: ...
3. New facts discovered, format: DISCOVERY: ...

Rules:
- Output one item per line.
- Do not include generic conversation.
- Do not include secrets, credentials, or private user data.
- If no durable learning item exists, output NONE.'

if ! command -v claude >/dev/null 2>&1; then
  echo "SessionEnd hook skipped: claude command not found" >&2
  exit 0
fi

CAPTURE="$(
  printf '%s\n' "$SESSION_PAYLOAD" | claude --print "$PROMPT" 2>/dev/null || true
)"

if [ -z "$CAPTURE" ] || [ "$CAPTURE" = "NONE" ]; then
  exit 0
fi

{
  echo ""
  echo "## Session Capture - $(date '+%Y-%m-%d %H:%M:%S')"
  printf '%s\n' "$CAPTURE"
} >> "$LOG_FILE"

