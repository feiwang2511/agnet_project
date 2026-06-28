#!/bin/bash
# 错题本业务验证脚本
# 验证已部署 API 的核心业务行为

set -u

API_BASE="${API_BASE:-https://hrlx9t2lub.execute-api.us-east-1.amazonaws.com/prod}"
PASS=0
FAIL=0

check() {
  local name="$1"
  local result="$2"
  if [ "$result" = "pass" ]; then
    PASS=$((PASS + 1))
    echo "  [PASS] $name"
  else
    FAIL=$((FAIL + 1))
    echo "  [FAIL] $name"
  fi
}

echo "=== 错题本业务验证 ==="
echo "API: $API_BASE"
echo ""

# --- 1. 空图片返回 400 ---
echo "## 输入校验"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API_BASE/recognize" \
  -H "Content-Type: application/json" \
  -d '{"image": ""}')
HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "400" ]; then
  check "空图片返回 400" "pass"
else
  check "空图片返回 400 (got $HTTP_CODE)" "fail"
fi

# 验证错误结构
if echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'code' in d['error'] and 'message' in d['error']" 2>/dev/null; then
  check "错误响应包含 error.code 和 error.message" "pass"
else
  check "错误响应包含 error.code 和 error.message" "fail"
fi

# --- 2. 非图片格式返回 400 ---
FAKE_GIF=$(echo -n "R0lGODlh" | base64)
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API_BASE/recognize" \
  -H "Content-Type: application/json" \
  -d "{\"image\": \"$FAKE_GIF\"}")
HTTP_CODE=$(echo "$RESP" | tail -1)

if [ "$HTTP_CODE" = "400" ]; then
  check "非JPEG/PNG返回 400" "pass"
else
  check "非JPEG/PNG返回 400 (got $HTTP_CODE)" "fail"
fi

# --- 3. GET /questions 返回列表 ---
echo ""
echo "## 错题管理"
RESP=$(curl -s -w "\n%{http_code}" "$API_BASE/questions")
HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
  check "GET /questions 返回 200" "pass"
else
  check "GET /questions 返回 200 (got $HTTP_CODE)" "fail"
fi

if echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'questions' in d and isinstance(d['questions'], list)" 2>/dev/null; then
  check "响应包含 questions 数组" "pass"
else
  check "响应包含 questions 数组" "fail"
fi

# --- 4. GET /questions?status=confirmed 过滤有效 ---
RESP=$(curl -s "$API_BASE/questions?status=confirmed")
if echo "$RESP" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for q in d.get('questions',[]):
    assert q['status']=='confirmed', f'unexpected status: {q[\"status\"]}'
" 2>/dev/null; then
  check "status 过滤只返回 confirmed" "pass"
else
  check "status 过滤只返回 confirmed" "fail"
fi

# --- 5. GET /review 返回复习列表 ---
echo ""
echo "## 复习功能"
RESP=$(curl -s -w "\n%{http_code}" "$API_BASE/review")
HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
  check "GET /review 返回 200" "pass"
else
  check "GET /review 返回 200 (got $HTTP_CODE)" "fail"
fi

if echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'questions' in d" 2>/dev/null; then
  check "复习响应包含 questions 字段" "pass"
else
  check "复习响应包含 questions 字段" "fail"
fi

# --- 6. 复习列表只包含 confirmed + unmastered ---
if echo "$BODY" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for q in d.get('questions',[]):
    assert q['status']=='confirmed', f'non-confirmed in review: {q[\"status\"]}'
    assert q.get('mastery')!='mastered', 'mastered item in review list'
" 2>/dev/null; then
  check "复习列表只含 confirmed+unmastered" "pass"
else
  check "复习列表只含 confirmed+unmastered" "fail"
fi

# --- 7. 不存在的题目返回 404 ---
echo ""
echo "## 边界情况"
RESP=$(curl -s -w "\n%{http_code}" "$API_BASE/questions/nonexistent_id_12345")
HTTP_CODE=$(echo "$RESP" | tail -1)

if [ "$HTTP_CODE" = "404" ]; then
  check "不存在的题目返回 404" "pass"
else
  check "不存在的题目返回 404 (got $HTTP_CODE)" "fail"
fi

# --- 8. confirm 需要 knowledge_points ---
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API_BASE/questions/nonexistent_id/confirm" \
  -H "Content-Type: application/json" \
  -d '{"question_text": "test", "knowledge_points": []}')
HTTP_CODE=$(echo "$RESP" | tail -1)

if [ "$HTTP_CODE" = "400" ]; then
  check "confirm 空知识点返回 400" "pass"
else
  check "confirm 空知识点返回 400 (got $HTTP_CODE)" "fail"
fi

# --- Summary ---
echo ""
echo "=== 业务验证结果 ==="
TOTAL=$((PASS + FAIL))
echo "  Pass: $PASS / $TOTAL"
if [ "$FAIL" -eq 0 ]; then
  echo "  Status: ALL PASS"
  exit 0
else
  echo "  Status: $FAIL FAILURES"
  exit 1
fi
