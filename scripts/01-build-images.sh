#!/bin/bash
set -e

echo "=== STEP 1: Build and Push Docker Images ==="

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_REGISTRY

# Create ECR repos if they don't exist
for SERVICE in triage-service bed-service alerts-service frontend; do
  aws ecr describe-repositories --repository-names kindcare/$SERVICE \
    --region $AWS_REGION 2>/dev/null || \
  aws ecr create-repository --repository-name kindcare/$SERVICE \
    --region $AWS_REGION
done

# Build and push each service
for SERVICE in triage-service bed-service alerts-service; do
  echo "Building $SERVICE..."
  docker build -t $ECR_REGISTRY/kindcare/$SERVICE:$IMAGE_TAG \
    ./services/$SERVICE
  docker push $ECR_REGISTRY/kindcare/$SERVICE:$IMAGE_TAG
  echo "$SERVICE pushed successfully"
done

# Build and push frontend
echo "Building frontend..."
docker build -t $ECR_REGISTRY/kindcare/frontend:$IMAGE_TAG ./frontend
docker push $ECR_REGISTRY/kindcare/frontend:$IMAGE_TAG

echo "=== All images pushed successfully ==="
