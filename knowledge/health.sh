#!/bin/bash
# Knowledge 系统健康检查
#
# 这个脚本回答一个问题：当前 AgentOS 的 Knowledge/Governance
# 是否足够新鲜、完整、轻量，可以安全注入给 Agent。

set -u

AGENTOS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WARNINGS=0
ERRORS=0

file_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null
}

days_old() {
  local file="$1"
  local modified
  modified="$(file_mtime "$file")"
  echo $(( ($(date +%s) - modified) / 86400 ))
}

count_words() {
  wc -w < "$1" | tr -d ' '
}

echo "=== Knowledge Health Check ==="
echo ""

echo "Freshness Check:"
for doc in PRODUCT TECH IMPROVEMENT PROJECT; do
  file="$AGENTOS_DIR/knowledge/$doc.md"
  if [ ! -f "$file" ]; then
    echo "  ERROR $doc.md: MISSING"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  age="$(days_old "$file")"
  if [ "$doc" = "PROJECT" ] && [ "$age" -gt 3 ]; then
    echo "  WARNING $doc.md: ${age} days old (threshold: 3)"
    WARNINGS=$((WARNINGS + 1))
  elif [ "$age" -gt 14 ]; then
    echo "  WARNING $doc.md: ${age} days old (threshold: 14)"
    WARNINGS=$((WARNINGS + 1))
  else
    echo "  OK $doc.md: ${age} days old"
  fi
done

echo ""
echo "Governance Check:"
principles="$AGENTOS_DIR/governance/principles.md"
if [ ! -f "$principles" ]; then
  echo "  ERROR principles.md: MISSING"
  ERRORS=$((ERRORS + 1))
else
  principle_count="$(grep -c '^## P' "$principles" || true)"
  if [ "$principle_count" -lt 3 ]; then
    echo "  WARNING principles: only $principle_count (target: 3-5)"
    WARNINGS=$((WARNINGS + 1))
  elif [ "$principle_count" -gt 5 ]; then
    echo "  WARNING principles: $principle_count (target: 3-5)"
    WARNINGS=$((WARNINGS + 1))
  else
    echo "  OK principles: $principle_count"
  fi
fi

active_rules="$(find "$AGENTOS_DIR/governance/rules" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
retired_rules="$(find "$AGENTOS_DIR/governance/rules/_retired" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
echo "  Active rules: $active_rules"
echo "  Retired rules: $retired_rules"
if [ "$active_rules" -gt 15 ]; then
  echo "  WARNING Too many active rules (>15). Distillation needed."
  WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "Injection Budget Check:"
total_words=0
while IFS= read -r -d '' file; do
  words="$(count_words "$file")"
  total_words=$((total_words + words))
done < <(find "$AGENTOS_DIR/knowledge" "$AGENTOS_DIR/governance" -name "*.md" -print0 2>/dev/null)

estimated_tokens=$((total_words * 4 / 3))
echo "  Total words: $total_words"
echo "  Estimated tokens: ~$estimated_tokens"
if [ "$estimated_tokens" -gt 15000 ]; then
  echo "  WARNING Exceeds injection budget (15K). Consider distilling."
  WARNINGS=$((WARNINGS + 1))
else
  echo "  OK Within budget"
fi

echo ""
echo "Executable Gates Check:"
gate_count="$(find "$AGENTOS_DIR/governance/gates" -maxdepth 1 -type f -perm +111 2>/dev/null | wc -l | tr -d ' ')"
if [ "$gate_count" -eq 0 ]; then
  echo "  WARNING No executable gates found"
  WARNINGS=$((WARNINGS + 1))
else
  echo "  OK executable gates: $gate_count"
fi

echo ""
echo "=== Summary ==="
echo "  Warnings: $WARNINGS | Errors: $ERRORS"

if [ "$ERRORS" -gt 0 ]; then
  echo "  UNHEALTHY - fix errors before proceeding"
  exit 1
elif [ "$WARNINGS" -gt 2 ]; then
  echo "  DEGRADED - schedule maintenance"
else
  echo "  HEALTHY"
fi

