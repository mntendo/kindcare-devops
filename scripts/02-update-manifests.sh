#!/bin/bash
set -e

echo "=== STEP 2: Update Kubernetes Manifests with new image tags ==="

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# Update image tags in all deployment files
for SERVICE in triage-service bed-service alerts-service frontend; do
  sed -i "s|[0-9]*\.dkr\.ecr\.us-east-1\.amazonaws\.com/kindcare/$SERVICE:.*|$ECR_REGISTRY/kindcare/$SERVICE:$IMAGE_TAG|g" \
    k8s/base/$SERVICE/deployment.yaml
  echo "Updated $SERVICE image to $IMAGE_TAG"
done

echo "=== Manifests updated ==="
