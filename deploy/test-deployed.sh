#!/bin/bash
# Integration test against the deployed API
# Usage: ./deploy/test-deployed.sh [API_URL]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -n "${1:-}" ]; then
    API_URL="$1"
elif [ -f "$SCRIPT_DIR/api-endpoint.txt" ]; then
    API_URL=$(cat "$SCRIPT_DIR/api-endpoint.txt")
else
    echo "Usage: $0 <api-url>"
    echo "  or place the URL in deploy/api-endpoint.txt"
    exit 1
fi

ENDPOINT="$API_URL/recognize"
PASS=0
FAIL=0

echo "=== Integration Tests: $ENDPOINT ==="
echo ""

# --- Test 1: Empty image returns 400 ---
echo -n "Test 1: Empty image returns 400... "
RESP=$(curl -s -w "\n%{http_code}" -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d '{"image": ""}')
HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "400" ]; then
    echo "PASS (HTTP $HTTP_CODE)"
    PASS=$((PASS + 1))
else
    echo "FAIL (expected 400, got $HTTP_CODE)"
    echo "  Body: $BODY"
    FAIL=$((FAIL + 1))
fi

# --- Test 2: Invalid base64 returns 400 ---
echo -n "Test 2: Invalid base64 returns 400... "
RESP=$(curl -s -w "\n%{http_code}" -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d '{"image": "not-valid-base64!!!"}')
HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "400" ]; then
    echo "PASS (HTTP $HTTP_CODE)"
    PASS=$((PASS + 1))
else
    echo "FAIL (expected 400, got $HTTP_CODE)"
    echo "  Body: $BODY"
    FAIL=$((FAIL + 1))
fi

# --- Test 3: Non-image format returns 400 ---
echo -n "Test 3: Non-image format returns 400... "
NOT_IMAGE_B64=$(echo -n "this is not an image" | base64)
RESP=$(curl -s -w "\n%{http_code}" -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "{\"image\": \"$NOT_IMAGE_B64\"}")
HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "400" ]; then
    echo "PASS (HTTP $HTTP_CODE)"
    PASS=$((PASS + 1))
else
    echo "FAIL (expected 400, got $HTTP_CODE)"
    echo "  Body: $BODY"
    FAIL=$((FAIL + 1))
fi

# --- Test 4: Valid JPEG calls Bedrock (200 or 502 both acceptable) ---
echo -n "Test 4: Valid JPEG returns 200 or 502... "
# Create minimal JPEG header + data
JPEG_B64=$(python3 -c "
import base64
jpeg = b'\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00'
jpeg += b'\xff\xd9'
print(base64.b64encode(jpeg).decode())
")
RESP=$(curl -s -w "\n%{http_code}" -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "{\"image\": \"$JPEG_B64\", \"subject\": \"math\", \"grade\": \"grade_7\"}")
HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "502" ]; then
    echo "PASS (HTTP $HTTP_CODE - Bedrock reachable or returned structured error)"
    PASS=$((PASS + 1))
    if [ "$HTTP_CODE" = "200" ]; then
        echo "  Response: $BODY"
    fi
else
    echo "FAIL (expected 200 or 502, got $HTTP_CODE)"
    echo "  Body: $BODY"
    FAIL=$((FAIL + 1))
fi

# --- Test 5: Error response has correct structure ---
echo -n "Test 5: Error response structure... "
RESP=$(curl -s -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d '{"image": ""}')

HAS_CODE=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'code' in d.get('error',{}) else 'no')" 2>/dev/null || echo "no")
HAS_MSG=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'message' in d.get('error',{}) else 'no')" 2>/dev/null || echo "no")
HAS_RID=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'request_id' in d.get('error',{}) else 'no')" 2>/dev/null || echo "no")

if [ "$HAS_CODE" = "yes" ] && [ "$HAS_MSG" = "yes" ] && [ "$HAS_RID" = "yes" ]; then
    echo "PASS (error.code, error.message, error.request_id present)"
    PASS=$((PASS + 1))
else
    echo "FAIL (missing error structure fields)"
    echo "  Response: $RESP"
    FAIL=$((FAIL + 1))
fi

# --- Summary ---
echo ""
echo "=== Results ==="
TOTAL=$((PASS + FAIL))
echo "  Pass: $PASS / $TOTAL"
if [ "$FAIL" -eq 0 ]; then
    echo "  ALL TESTS PASSED"
else
    echo "  $FAIL FAILED"
    exit 1
fi
