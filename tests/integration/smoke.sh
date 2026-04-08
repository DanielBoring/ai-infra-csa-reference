#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Smoke / Integration Test Script
# Validates deployed infrastructure endpoints are reachable and return
# expected response schemas.
#
# Usage:
#   bash tests/integration/smoke.sh <ACA_FQDN> <APIM_GATEWAY_URL>
#
# Example:
#   bash tests/integration/smoke.sh \
#     app-ai-infra-ref-dev.happyocean-abc123.eastus2.azurecontainerapps.io \
#     https://apim-ai-infra-ref-dev.azure-api.net
# ---------------------------------------------------------------------------

set -euo pipefail

ACA_FQDN="${1:?Usage: smoke.sh <ACA_FQDN> <APIM_GATEWAY_URL>}"
APIM_URL="${2:?Usage: smoke.sh <ACA_FQDN> <APIM_GATEWAY_URL>}"

PASS=0
FAIL=0

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "============================================"
echo "  Smoke Tests — AI Infra CSA Reference"
echo "============================================"
echo ""

# ----- Test 1: ACA Health Endpoint -----
echo "Test 1: ACA /health endpoint"
HTTP_CODE=$(curl -s -o /tmp/health_response.json -w "%{http_code}" "https://${ACA_FQDN}/health" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
  STATUS=$(cat /tmp/health_response.json | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
  if [ "$STATUS" = "healthy" ]; then
    pass "ACA /health returned 200 with status=healthy"
  else
    fail "ACA /health returned 200 but status=${STATUS} (expected 'healthy')"
  fi
else
  fail "ACA /health returned HTTP ${HTTP_CODE} (expected 200)"
fi

# ----- Test 2: APIM Gateway Reachable -----
echo "Test 2: APIM gateway reachable"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${APIM_URL}/" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" != "000" ]; then
  pass "APIM gateway reachable (HTTP ${HTTP_CODE})"
else
  fail "APIM gateway not reachable"
fi

# ----- Test 3: Chat Completions via APIM -----
echo "Test 3: POST /chat/completions via APIM"
HTTP_CODE=$(curl -s -o /tmp/chat_response.json -w "%{http_code}" \
  -X POST "${APIM_URL}/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "Hello from smoke test"}]}' \
  2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
  # Validate response schema has required fields
  RESPONSE=$(cat /tmp/chat_response.json)
  
  HAS_ID=$(echo "$RESPONSE" | grep -c '"id"' || true)
  HAS_CHOICES=$(echo "$RESPONSE" | grep -c '"choices"' || true)
  HAS_USAGE=$(echo "$RESPONSE" | grep -c '"usage"' || true)
  
  if [ "$HAS_ID" -ge 1 ] && [ "$HAS_CHOICES" -ge 1 ] && [ "$HAS_USAGE" -ge 1 ]; then
    pass "Chat completions returned valid schema (id, choices, usage)"
  else
    fail "Chat completions response missing required fields (id=${HAS_ID}, choices=${HAS_CHOICES}, usage=${HAS_USAGE})"
    echo "       Response: $(cat /tmp/chat_response.json | head -5)"
  fi
else
  fail "Chat completions returned HTTP ${HTTP_CODE} (expected 200)"
  echo "       Response: $(cat /tmp/chat_response.json 2>/dev/null | head -5)"
fi

# ----- Test 4: Rate Limiting Headers -----
echo "Test 4: Rate limiting headers present"
HEADERS=$(curl -s -D - -o /dev/null \
  -X POST "${APIM_URL}/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "Test"}]}' \
  2>/dev/null || echo "")

if echo "$HEADERS" | grep -qi "x-ratelimit-remaining\|retry-after"; then
  pass "Rate limiting headers present in response"
else
  # Rate limit headers may not be present on Consumption tier
  echo "  ⚠️  SKIP: Rate limiting headers not found (may be expected on Consumption tier)"
fi

# ----- Summary -----
echo ""
echo "============================================"
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo "============================================"

# Clean up
rm -f /tmp/health_response.json /tmp/chat_response.json

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

exit 0
