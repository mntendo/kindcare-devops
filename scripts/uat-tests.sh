#!/bin/bash
set -e

echo "KINDCARE UAT - USER ACCEPTANCE TESTS"
echo ""

BASE_TRIAGE="http://localhost:3001"
BASE_BED="http://localhost:3002"
BASE_ALERTS="http://localhost:3003"

pass=0
fail=0

# Helper function to check test results
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


# SCENARIO 1 - Critical Patient Level 1
echo "--- SCENARIO 1: Critical Patient ---"

PATIENT1=$(curl -sf -X POST $BASE_TRIAGE/patients \
  -H "Content-Type: application/json" \
  -d '{"firstName":"Critical","lastName":"Patient","dob":"1970-01-01","gender":"Male","chiefComplaint":"cardiac arrest","heartRate":160,"bloodPressureSystolic":70,"bloodPressureDiastolic":40,"oxygenSaturation":82,"temperature":104,"respiratoryRate":35,"painLevel":10,"consciousnessLevel":"Unresponsive"}')

check "Level 1 patient created" "$PATIENT1" "triage_level"
check "Level 1 assigned CRITICAL" "$PATIENT1" "CRITICAL"
PATIENT1_ID=$(echo $PATIENT1 | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')

# Assign bed - Level 1 should go to ICU
BED1=$(curl -sf -X POST $BASE_BED/beds/assign \
  -H "Content-Type: application/json" \
  -d "{\"patientId\":$PATIENT1_ID,\"patientName\":\"Critical Patient\",\"triageLevel\":1}")

check "Level 1 patient assigned to ICU" "$BED1" "ICU"


# SCENARIO 2 - Moderate Patient Level 3
echo ""
echo "--- SCENARIO 2: Moderate Patient ---"

PATIENT2=$(curl -sf -X POST $BASE_TRIAGE/patients \
  -H "Content-Type: application/json" \
  -d '{"firstName":"Moderate","lastName":"Patient","dob":"1985-06-15","gender":"Female","chiefComplaint":"abdominal pain","heartRate":95,"bloodPressureSystolic":130,"bloodPressureDiastolic":85,"oxygenSaturation":96,"temperature":100.2,"respiratoryRate":18,"painLevel":6,"consciousnessLevel":"Alert"}')

check "Level 3 patient created" "$PATIENT2" "triage_level"
PATIENT2_ID=$(echo $PATIENT2 | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')


# SCENARIO 3 - Minor Patient Level 5
echo ""
echo "--- SCENARIO 3: Minor Patient ---"

PATIENT3=$(curl -sf -X POST $BASE_TRIAGE/patients \
  -H "Content-Type: application/json" \
  -d '{"firstName":"Minor","lastName":"Patient","dob":"2000-03-20","gender":"Female","chiefComplaint":"sore throat","heartRate":75,"bloodPressureSystolic":118,"bloodPressureDiastolic":75,"oxygenSaturation":99,"temperature":98.9,"respiratoryRate":14,"painLevel":2,"consciousnessLevel":"Alert"}')

check "Level 5 patient created" "$PATIENT3" "triage_level"
PATIENT3_ID=$(echo $PATIENT3 | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')


# SCENARIO 4 - Bed Management
echo ""
echo "--- SCENARIO 4: Bed Management ---"

BEDS=$(curl -sf $BASE_BED/beds)
check "Beds endpoint returns data" "$BEDS" "bed_number"
check "Beds have ward information" "$BEDS" "ward"
check "Beds have status" "$BEDS" "available"


# SCENARIO 5 - Alert Generation
echo ""
echo "--- SCENARIO 5: Alert Generation ---"

ALERTS=$(curl -sf $BASE_ALERTS/alerts)
check "Alerts endpoint working" "$ALERTS" "\["


# SCENARIO 6 - Patient List
echo ""
echo "--- SCENARIO 6: Patient List ---"

PATIENTS=$(curl -sf $BASE_TRIAGE/patients)
check "Patient list returns data" "$PATIENTS" "id"
check "Critical patient in list" "$PATIENTS" "Critical"
check "Minor patient in list" "$PATIENTS" "Minor"


# RESULTS
echo ""
echo "UAT RESULTS"
echo "  PASSED: $pass"
echo "  FAILED: $fail"
echo ""

if [ $fail -gt 0 ]; then
  echo "UAT FAILED - $fail tests did not pass"
  exit 1
fi

echo "ALL UAT TESTS PASSED"
