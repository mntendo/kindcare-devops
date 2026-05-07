#!/bin/bash
set -e

echo "=== QA INTEGRATION TESTS ==="

echo "--- Starting services ---"
docker compose up -d --build
echo "Waiting for all services to be healthy..."
docker compose wait triage-service bed-service alerts-service 2>/dev/null || sleep 30

# Test 1 - Frontend health
echo "--- Test 1: Frontend health ---"
curl -sf http://localhost:8080/health && echo "✓ Frontend healthy" || { echo "FAIL: Frontend"; docker compose down; exit 1; }

# Test 2 - Triage service health
echo "--- Test 2: Triage service health ---"
curl -sf http://localhost:3001/health && echo "✓ Triage healthy" || { echo "FAIL: Triage"; docker compose down; exit 1; }

# Test 3 - Bed service health
echo "--- Test 3: Bed service health ---"
curl -sf http://localhost:3002/health && echo "✓ Bed service healthy" || { echo "FAIL: Bed service"; docker compose down; exit 1; }

# Test 4 - Alerts service health
echo "--- Test 4: Alerts service health ---"
curl -sf http://localhost:3003/health && echo "✓ Alerts healthy" || { echo "FAIL: Alerts"; docker compose down; exit 1; }

# Test 5 - Create a patient
echo "--- Test 5: Create patient ---"
RESPONSE=$(curl -sf -X POST http://localhost:3001/patients \
  -H "Content-Type: application/json" \
  -d '{"name":"QA Test Patient","chiefComplaint":"chest pain","heartRate":145,"bpSystolic":85,"o2Sat":88,"temperature":99.1,"respiratoryRate":28,"painLevel":9,"consciousness":"Alert"}')
echo $RESPONSE | grep -q "id" && echo "✓ Patient created" || { echo "FAIL: Patient creation"; docker compose down; exit 1; }

# Test 6 - Check bed availability
echo "--- Test 6: Bed availability ---"
curl -sf http://localhost:3002/beds | grep -q "ward" && echo "✓ Beds available" || { echo "FAIL: Bed availability"; docker compose down; exit 1; }

# Test 7 - Check alerts endpoint
echo "--- Test 7: Alerts endpoint ---"
curl -sf http://localhost:3003/alerts && echo "✓ Alerts endpoint working" || { echo "FAIL: Alerts endpoint"; docker compose down; exit 1; }

docker compose down
echo "=== ALL QA TESTS PASSED ==="
