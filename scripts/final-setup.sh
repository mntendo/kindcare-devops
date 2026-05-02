#!/bin/bash
set -e

echo "========================================="
echo "   KINDCARE - FINAL SETUP SCRIPT"
echo "========================================="

CLUSTER_NAME="kindcare-dev"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

# STEP 1 - Terraform
echo ""
echo "--- STEP 1: Apply Terraform Infrastructure ---"
cd terraform/environments/dev
/usr/local/bin/terraform init
/usr/local/bin/terraform apply -var="db_password=KindCare2024x" -auto-approve
cd ../../..
echo "✓ Infrastructure ready"

# STEP 2 - Connect to EKS
echo ""
echo "--- STEP 2: Connect to EKS ---"
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION
echo "✓ Connected to EKS"

# STEP 3 - Create node group
echo ""
echo "--- STEP 3: Create Node Group ---"
aws eks create-nodegroup \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name kindcare-dev-nodes \
  --node-role arn:aws:iam::$ACCOUNT_ID:role/LabRole \
  --subnets $(aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=kindcare-dev-private-*" \
    --query 'Subnets[*].SubnetId' \
    --output text | tr '\t' ' ') \
  --instance-types t3.medium \
  --scaling-config minSize=1,maxSize=3,desiredSize=2 \
  --ami-type AL2_x86_64 \
  --region $REGION 2>/dev/null || echo "Node group already exists"

echo "Waiting for nodes to be ready..."
aws eks wait nodegroup-active \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name kindcare-dev-nodes \
  --region $REGION
echo "✓ Nodes ready"

# STEP 4 - Install Nginx Ingress
echo ""
echo "--- STEP 4: Install Nginx Ingress ---"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
echo "✓ Ingress ready"

# STEP 5 - Login to ECR and push images
echo ""
echo "--- STEP 5: Push Docker Images to ECR ---"
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin $ECR_REGISTRY
bash scripts/01-build-images.sh
echo "✓ Images pushed"

# STEP 6 - Create namespace and secrets
echo ""
echo "--- STEP 6: Create Namespace and Secrets ---"
kubectl apply -f k8s/base/namespace/namespace.yaml

RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier kindcare-dev-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

kubectl create secret generic kindcare-db-secret \
  --namespace=kindcare \
  --from-literal=host=$RDS_ENDPOINT \
  --from-literal=name=kindcare \
  --from-literal=username=kindcare \
  --from-literal=password=KindCare2024x \
  --dry-run=client -o yaml | kubectl apply -f -
echo "✓ Secrets created"

# STEP 7 - Deploy KindCare
echo ""
echo "--- STEP 7: Deploy KindCare ---"
bash scripts/02-update-manifests.sh
kubectl apply -k k8s/overlays/dev
kubectl rollout status deployment/triage-service -n kindcare --timeout=300s
kubectl rollout status deployment/bed-service -n kindcare --timeout=300s
kubectl rollout status deployment/alerts-service -n kindcare --timeout=300s
kubectl rollout status deployment/frontend -n kindcare --timeout=300s
echo "✓ KindCare deployed"

# STEP 8 - Install cert-manager
echo ""
echo "--- STEP 8: Install cert-manager ---"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
kubectl wait --for=condition=ready pod --all -n cert-manager --timeout=120s
kubectl apply -f k8s/cert-manager/cluster-issuer.yaml
kubectl apply -f k8s/cert-manager/grafana-ingress.yaml
echo "✓ cert-manager ready"

# STEP 9 - Install Argo CD
echo ""
echo "--- STEP 9: Install Argo CD ---"
kubectl create namespace argocd 2>/dev/null || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s
kubectl apply -f argocd/kindcare-app.yaml
echo "✓ Argo CD ready"

# STEP 10 - Install Prometheus and Grafana
echo ""
echo "--- STEP 10: Install Monitoring Stack ---"
kubectl create namespace monitoring 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create Grafana secrets
kubectl create secret generic grafana-secrets \
  --namespace monitoring \
  --from-literal=github-secret=$GRAFANA_GITHUB_SECRET \
  --from-literal=gmail-password=$GMAIL_APP_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values monitoring/values.yaml \
  --set grafana.envFromSecret=grafana-secrets
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --set promtail.enabled=true \
  --set loki.enabled=true \
  --set grafana.enabled=false
kubectl apply -f monitoring/alert-rules.yaml
echo "✓ Monitoring ready"


# STEP 11 - Fix RDS security group
echo ""
echo "--- STEP 11: Fix RDS Security Group ---"
NODE_SG=$(aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
  --output text)
RDS_SG=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=kindcare-dev-rds-sg" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG \
  --protocol tcp \
  --port 5432 \
  --source-group $NODE_SG \
  --region $REGION 2>/dev/null || echo "Rule already exists"
echo "✓ Security group fixed"

# STEP 12 - Update Route 53 with Load Balancer
echo ""
echo "--- STEP 12: Update DNS ---"
echo "Waiting for load balancer..."
sleep 60
LB_URL=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

cd terraform/environments/dev
/usr/local/bin/terraform apply \
  -var="db_password=KindCare2024x" \
  -var="load_balancer_hostname=$LB_URL" \
  -auto-approve
cd ../../..
echo "✓ DNS updated"

# STEP 13 - Final status
echo ""
echo "========================================="
echo "   KINDCARE IS LIVE!"
echo "   App:     https://kindcare.mariamdevops.com"
echo "   Grafana: https://grafana.mariamdevops.com"
echo "========================================="
echo ""
kubectl get pods -n kindcare
kubectl get pods -n monitoring
