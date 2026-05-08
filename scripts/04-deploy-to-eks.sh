#!/bin/bash
set -e

echo "=== STEP 4: Deploy to EKS ==="

# Update kubeconfig to connect to the cluster
aws eks update-kubeconfig \
  --name kindcare-$ENVIRONMENT \
  --region $AWS_REGION

# Create namespace if it doesn't exist
kubectl apply -f k8s/base/namespace/namespace.yaml

# Create or update the database secret
kubectl create secret generic kindcare-db-secret \
  --namespace=kindcare \
  --from-literal=host=$DB_HOST \
  --from-literal=name=kindcare \
  --from-literal=username=kindcare \
  --from-literal=password=$DB_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

# Apply the correct overlay based on environment
kubectl apply -k k8s/overlays/$ENVIRONMENT

# Ensure NODE_ENV is set for production RDS SSL
kubectl set env deployment/triage-service deployment/bed-service deployment/alerts-service \
  --namespace=kindcare NODE_ENV=production


echo "=== Deployment applied ==="
