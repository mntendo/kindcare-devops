#!/bin/bash
set -e

echo "KINDCARE PRODUCTION SMOKE TESTS"
echo ""

PROD_URL=${PROD_URL:-"https://kindcare.mariamdevops.com"}

pass=0
fail=0

check() {
  local description=$1
  local result=$2
  local expected=$3
  if echo "$result" | grep -q "$expected"; then
    echo "✓ PASS: $description"
    pass=$((pass+1))
  else
    echo "✗ FAIL: $description"
    echo "  Expected: $expected"
    echo "  Got: $result"
    fail=$((fail+1))
  fi
}

# TEST 1 - Frontend accessible
echo "--- Test 1: Frontend HTTPS ---"
FRONTEND=$(curl -sfk --max-time 15 $PROD_URL 2>/dev/null || echo "FAILED")
check "Frontend accessible via HTTPS" "$FRONTEND" "html\|HTML\|kindcare\|KindCare"

# TEST 2 - Beds endpoint
echo ""
echo "--- Test 2: Beds endpoint ---"
BEDS=$(curl -sfk --max-time 15 $PROD_URL/beds 2>/dev/null || echo "FAILED")
check "Beds endpoint working" "$BEDS" "bed_number\|ward\|ICU"

# TEST 3 - Alerts endpoint
echo ""
echo "--- Test 3: Alerts endpoint ---"
ALERTS=$(curl -sfk --max-time 15 $PROD_URL/alerts 2>/dev/null || echo "FAILED")
check "Alerts endpoint working" "$ALERTS" "\[\|id\|type"

# TEST 4 - SSL certificate
echo ""
echo "--- Test 4: SSL Certificate ---"
SSL_CHECK=$(curl -sv --max-time 15 $PROD_URL 2>&1 | grep -i "SSL\|TLS\|certificate" || echo "FAILED")
check "SSL certificate valid" "$SSL_CHECK" "SSL\|TLS\|certificate"

echo ""
echo "PRODUCTION SMOKE TEST RESULTS"
echo "  PASSED: $pass"
echo "  FAILED: $fail"
echo ""

if [ $fail -gt 0 ]; then
  echo "PRODUCTION SMOKE TESTS FAILED - $fail tests did not pass"
  exit 1
fi

echo "ALL PRODUCTION SMOKE TESTS PASSED"
echo "KindCare is live at $PROD_URL"
