#!/bin/bash
set -e

echo "=== STEP 5: Smoke Test ==="

# Wait for all deployments to be ready
kubectl rollout status deployment/triage-service -n kindcare --timeout=300s
kubectl rollout status deployment/bed-service -n kindcare --timeout=300s
kubectl rollout status deployment/alerts-service -n kindcare --timeout=300s
kubectl rollout status deployment/frontend -n kindcare --timeout=300s

echo "All deployments are healthy"

# Check all pods are running
kubectl get pods -n kindcare

echo "=== Smoke test passed ==="
