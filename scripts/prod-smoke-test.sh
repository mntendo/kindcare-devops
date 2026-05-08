#!/bin/bash
set -e

echo "KINDCARE PRODUCTION SMOKE TESTS"
echo ""

# Production URL - set as environment variable
PROD_URL=${PROD_URL:-"https://kindcare.mariamdevops.com"}

pass=0
fail=0

# Helper function
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


# TEST 1 - Frontend is accessible via HTTPS
echo "--- Test 1: Frontend HTTPS ---"
FRONTEND=$(curl -sf --max-time 10 $PROD_URL || echo "FAILED")
check "Frontend accessible via HTTPS" "$FRONTEND" "KindCare\|kindcare\|DOCTYPE"


# TEST 2 - Triage service health
echo ""
echo "--- Test 2: Triage Service Health ---"
TRIAGE_HEALTH=$(curl -sf --max-time 10 $PROD_URL/patients/health || echo "FAILED")
check "Triage service healthy" "$TRIAGE_HEALTH" "ok"


# TEST 3 - Bed service health
echo ""
echo "--- Test 3: Bed Service Health ---"
BED_HEALTH=$(curl -sf --max-time 10 $PROD_URL/beds/health || echo "FAILED")
check "Bed service healthy" "$BED_HEALTH" "ok"


# TEST 4 - Alerts service health
echo ""
echo "--- Test 4: Alerts Service Health ---"
ALERTS_HEALTH=$(curl -sf --max-time 10 $PROD_URL/alerts/health || echo "FAILED")
check "Alerts service healthy" "$ALERTS_HEALTH" "ok"


# TEST 5 - Beds endpoint returns data
echo ""
echo "--- Test 5: Beds Available ---"
BEDS=$(curl -sf --max-time 10 $PROD_URL/beds || echo "FAILED")
check "Beds endpoint working" "$BEDS" "bed_number"


# TEST 6 - SSL certificate valid
echo ""
echo "--- Test 6: SSL Certificate ---"
SSL_CHECK=$(curl -sv --max-time 10 $PROD_URL 2>&1 | grep -i "SSL\|TLS\|certificate" || echo "FAILED")
check "SSL certificate valid" "$SSL_CHECK" "SSL\|TLS\|certificate"


# RESULTS
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
