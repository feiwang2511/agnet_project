#!/bin/bash
# AgentOS Behavioral Eval Script
# 检查 AgentOS 是否按预期行为工作

set -u

AGENTOS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCORE=0
TOTAL=0
FAILURES=""

check() {
  local name="$1"
  local result="$2"
  TOTAL=$((TOTAL + 1))
  if [ "$result" = "pass" ]; then
    SCORE=$((SCORE + 1))
    echo "  [PASS] $name"
  else
    echo "  [FAIL] $name"
    FAILURES="$FAILURES\n  - $name"
  fi
}

echo "=== AgentOS Behavioral Eval ==="
echo ""

# --- BC-001: Completion Behavior ---
echo "## Completion Behavior"

if [ -f "$AGENTOS_DIR/engine/STATE.md" ]; then
  STATE_STATUS=$(grep -o "DONE\|BUILD\|PLAN\|EVALUATE\|VERIFY\|IDLE" "$AGENTOS_DIR/engine/STATE.md" | head -1)
  if [ "$STATE_STATUS" = "DONE" ]; then
    TASK_ID=$(grep -oP 'Task ID.*?`\K[^`]+' "$AGENTOS_DIR/engine/STATE.md" 2>/dev/null || echo "recognize")
    if [ -f "$AGENTOS_DIR/spec/$TASK_ID/verify.md" ]; then
      if grep -q "pass\|PASS\|Pass" "$AGENTOS_DIR/spec/$TASK_ID/verify.md"; then
        check "BC-001: verify artifact exists with pass/fail" "pass"
      else
        check "BC-001: verify artifact exists with pass/fail" "fail"
      fi
    else
      check "BC-001: verify artifact exists with pass/fail" "fail"
    fi
  else
    check "BC-001: verify artifact exists with pass/fail (not DONE yet)" "pass"
  fi
else
  check "BC-001: verify artifact exists with pass/fail" "fail"
fi

# --- BC-002: Engine Compliance ---
echo ""
echo "## Engine Compliance"

TASK_ID="recognize"
if [ -f "$AGENTOS_DIR/spec/$TASK_ID/evaluate.md" ]; then
  check "BC-002a: evaluate.md exists" "pass"
else
  check "BC-002a: evaluate.md exists" "fail"
fi

if [ -f "$AGENTOS_DIR/spec/$TASK_ID/plan.md" ]; then
  check "BC-002b: plan.md exists" "pass"
else
  check "BC-002b: plan.md exists" "fail"
fi

if [ -f "$AGENTOS_DIR/spec/$TASK_ID/verify.md" ]; then
  check "BC-002c: verify.md exists" "pass"
else
  check "BC-002c: verify.md exists" "fail"
fi

# --- BC-003: ADR Coverage ---
echo ""
echo "## ADR Coverage"

ADR_COUNT=$(grep -c "^### \[ADR-" "$AGENTOS_DIR/knowledge/TECH.md" 2>/dev/null || echo "0")
if [ "$ADR_COUNT" -ge 3 ]; then
  check "BC-003: ADR count >= 3" "pass"
else
  check "BC-003: ADR count >= 3 (found $ADR_COUNT)" "fail"
fi

# --- BC-004: Tests Pass ---
echo ""
echo "## Test Verification"

if [ -d "$AGENTOS_DIR/tests" ]; then
  if command -v python3 >/dev/null 2>&1; then
    ACTIVATE=""
    if [ -f "$AGENTOS_DIR/.venv/bin/activate" ]; then
      ACTIVATE="source $AGENTOS_DIR/.venv/bin/activate && "
    fi
    TEST_RESULT=$(cd "$AGENTOS_DIR" && eval "${ACTIVATE}python3 -m pytest tests/ --tb=no -q" 2>&1 | tail -1)
    if echo "$TEST_RESULT" | grep -q "passed"; then
      check "BC-004: tests pass" "pass"
    else
      check "BC-004: tests pass" "fail"
    fi
  else
    check "BC-004: tests pass (python3 not available)" "fail"
  fi
else
  check "BC-004: tests directory exists" "fail"
fi

# --- BC-005: Governance Coverage ---
echo ""
echo "## Governance Coverage"

PRINCIPLES_COUNT=$(grep -c "^## P[0-9]" "$AGENTOS_DIR/governance/principles.md" 2>/dev/null || echo "0")
if [ "$PRINCIPLES_COUNT" -ge 3 ]; then
  check "BC-005a: Principles count >= 3" "pass"
else
  check "BC-005a: Principles count >= 3 (found $PRINCIPLES_COUNT)" "fail"
fi

RULES_COUNT=$(find "$AGENTOS_DIR/governance/rules" -name "*.md" 2>/dev/null | wc -l)
if [ "$RULES_COUNT" -ge 2 ]; then
  check "BC-005b: Rules count >= 2" "pass"
else
  check "BC-005b: Rules count >= 2 (found $RULES_COUNT)" "fail"
fi

GATES_COUNT=$(find "$AGENTOS_DIR/governance/gates" -name "*.sh" 2>/dev/null | wc -l)
if [ "$GATES_COUNT" -ge 1 ]; then
  check "BC-005c: Executable gates >= 1" "pass"
else
  check "BC-005c: Executable gates >= 1 (found $GATES_COUNT)" "fail"
fi

# --- BC-007: Verify Depth ---
echo ""
echo "## Verify Depth"

if [ -f "$AGENTOS_DIR/spec/$TASK_ID/verify.md" ]; then
  BREAK_COUNT=$(grep -c "^|" "$AGENTOS_DIR/spec/$TASK_ID/verify.md" | head -1)
  if [ "$BREAK_COUNT" -ge 7 ]; then
    check "BC-007: >= 5 destruction attempts in verify" "pass"
  else
    check "BC-007: >= 5 destruction attempts in verify (rows: $BREAK_COUNT)" "fail"
  fi
else
  check "BC-007: verify.md exists for destruction check" "fail"
fi

# --- BC-008: Hooks Registered ---
echo ""
echo "## Hooks"

if [ -f "$AGENTOS_DIR/.claude/settings.json" ]; then
  if grep -q "SessionStart" "$AGENTOS_DIR/.claude/settings.json"; then
    check "BC-008a: SessionStart hook registered" "pass"
  else
    check "BC-008a: SessionStart hook registered" "fail"
  fi
  if grep -q "SessionEnd\|Stop" "$AGENTOS_DIR/.claude/settings.json"; then
    check "BC-008b: SessionEnd/Stop hook registered" "pass"
  else
    check "BC-008b: SessionEnd/Stop hook registered" "fail"
  fi
else
  check "BC-008: settings.json exists" "fail"
fi

# --- BC-010: Corrections Log ---
echo ""
echo "## Corrections Health"

if [ -f "$AGENTOS_DIR/corrections.log" ]; then
  CORR_LINES=$(wc -l < "$AGENTOS_DIR/corrections.log" | tr -d ' ')
  if [ "$CORR_LINES" -gt 0 ]; then
    check "BC-010: corrections.log has content" "pass"
  else
    check "BC-010: corrections.log has content" "fail"
  fi
else
  check "BC-010: corrections.log exists" "fail"
fi

# --- Summary ---
echo ""
echo "=== EVAL SUMMARY ==="
PERCENT=$((SCORE * 100 / TOTAL))
echo "  Score: $SCORE / $TOTAL ($PERCENT%)"

if [ -n "$FAILURES" ]; then
  echo ""
  echo "  Failures:"
  printf "$FAILURES\n"
fi

echo ""
if [ "$PERCENT" -ge 80 ]; then
  echo "  Status: HEALTHY"
elif [ "$PERCENT" -ge 60 ]; then
  echo "  Status: NEEDS ATTENTION"
else
  echo "  Status: UNHEALTHY"
fi
