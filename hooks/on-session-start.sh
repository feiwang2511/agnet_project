#!/bin/bash
# 触发时机：Claude Code session 启动时
# 做什么：把 AgentOS 的关键上下文注入给 Agent。

set -u

AGENTOS_DIR="$(cd "$(dirname "$0")/.." && pwd)"

section() {
  echo ""
  echo "=== $1 ==="
}

print_file_if_exists() {
  local title="$1"
  local file="$2"
  local lines="${3:-9999}"

  if [ -f "$file" ]; then
    echo "--- $title ---"
    head -n "$lines" "$file"
    if [ "$(wc -l < "$file" | tr -d ' ')" -gt "$lines" ]; then
      echo "..."
    fi
    echo ""
  else
    echo "--- $title ---"
    echo "MISSING: $file"
    echo ""
  fi
}

section "AGENTOS BOOTSTRAP"
echo "Repo: $AGENTOS_DIR"
echo "Purpose: Load project knowledge, governance, current status, and health before work starts."

section "P0 PRINCIPLES - highest priority behavior constraints"
print_file_if_exists "governance/principles.md" "$AGENTOS_DIR/governance/principles.md"

section "P1 CURRENT PROJECT STATE"
print_file_if_exists "knowledge/PROJECT.md" "$AGENTOS_DIR/knowledge/PROJECT.md"

if [ -f "$AGENTOS_DIR/engine/STATE.md" ]; then
  print_file_if_exists "engine/STATE.md" "$AGENTOS_DIR/engine/STATE.md"
fi

section "P2 DOMAIN KNOWLEDGE SUMMARIES"
for doc in PRODUCT TECH IMPROVEMENT; do
  print_file_if_exists "knowledge/$doc.md" "$AGENTOS_DIR/knowledge/$doc.md" 35
done

section "P3 ACTIVE RULES"
rule_count=0
for rule in "$AGENTOS_DIR"/governance/rules/*.md; do
  [ -e "$rule" ] || continue
  rule_count=$((rule_count + 1))
  print_file_if_exists "$(basename "$rule")" "$rule" 24
done

if [ "$rule_count" -eq 0 ]; then
  echo "No active rules found."
fi

section "P4 PROHIBITIONS"
if [ -f "$AGENTOS_DIR/knowledge/IMPROVEMENT.md" ]; then
  awk '
    /^## 禁止事项/ { printing = 1; print; next }
    /^## / && printing { exit }
    printing { print }
  ' "$AGENTOS_DIR/knowledge/IMPROVEMENT.md"
else
  echo "MISSING: knowledge/IMPROVEMENT.md"
fi

section "P5 HEALTH SUMMARY"
if [ -x "$AGENTOS_DIR/knowledge/health.sh" ]; then
  bash "$AGENTOS_DIR/knowledge/health.sh" 2>/dev/null | tail -8
else
  echo "MISSING or not executable: knowledge/health.sh"
fi

section "AGENTOS BOOTSTRAP COMPLETE"
