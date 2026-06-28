#!/bin/bash
# Gate: 基础质量检查
# 追溯:
# - P1: 完成 = 主动验证且没有失败项
# - P2: 宁可进入待确认，也不让脏数据进入正式学习链路
# 毕业条件:
# - 连续 60 天不触发后，可考虑拆分成更细的 lint/schema/secrets gates。

set -u

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
FAIL=0

echo "=== Gate: basic quality ==="

echo ""
echo "Python syntax check:"
PY_FOUND=0
while IFS= read -r -d '' file; do
  PY_FOUND=1
  if ! python3 -m py_compile "$file"; then
    echo "FAIL Python syntax: $file"
    FAIL=1
  fi
done < <(find "$ROOT_DIR" -name "*.py" -not -path "*/.venv/*" -not -path "*/venv/*" -print0)

if [ "$PY_FOUND" -eq 0 ]; then
  echo "OK No Python files found"
fi

echo ""
echo "Secret scan:"
SECRET_PATTERN='AKIA[0-9A-Z]{16}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|sk-[A-Za-z0-9_-]{20,}'
SECRET_MATCHES=$(grep -R -n -E "$SECRET_PATTERN" "$ROOT_DIR" \
  --exclude-dir=.git \
  --exclude-dir=.venv \
  --exclude-dir=venv \
  --exclude="check-basic-quality.sh" 2>/dev/null || true)

if [ -n "$SECRET_MATCHES" ]; then
  echo "FAIL Possible secret detected:"
  echo "$SECRET_MATCHES"
  FAIL=1
else
  echo "OK No obvious secrets detected"
fi

echo ""
if [ "$FAIL" -ne 0 ]; then
  echo "GATE BLOCKED: basic quality checks failed"
  exit 1
fi

echo "Gate passed: basic quality"

