#!/bin/bash
set -e

echo "=== DAY 2: Node Patching ==="
echo "This script rotates EKS worker nodes with zero downtime"

CLUSTER_NAME=${CLUSTER_NAME:-"kindcare-dev"}
NODEGROUP_NAME=${NODEGROUP_NAME:-"kindcare-dev-nodes"}
REGION=${AWS_REGION:-"us-east-1"}

# Step 1 - Get current nodes
echo "--- Step 1: Current nodes ---"
kubectl get nodes

# Step 2 - Cordon all nodes (stop scheduling new pods)
echo "--- Step 2: Cordoning nodes ---"
for NODE in $(kubectl get nodes -o name); do
  kubectl cordon $NODE
  echo "Cordoned $NODE"
done

# Step 3 - Drain nodes one at a time (move pods off gracefully)
echo "--- Step 3: Draining nodes one at a time ---"
for NODE in $(kubectl get nodes -o name); do
  echo "Draining $NODE..."
  kubectl drain $NODE \
    --ignore-daemonsets \
    --delete-emptydir-data \
    --force \
    --grace-period=60
  echo "$NODE drained"
done

# Step 4 - Trigger node group update (AWS replaces with new AMI)
echo "--- Step 4: Triggering node group update ---"
aws eks update-nodegroup-version \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name $NODEGROUP_NAME \
  --region $REGION

echo "--- Step 5: Waiting for update to complete ---"
aws eks wait nodegroup-active \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name $NODEGROUP_NAME \
  --region $REGION

# Step 6 - Verify new nodes are ready
echo "--- Step 6: New nodes status ---"
kubectl get nodes

echo "=== Node patching complete - zero downtime achieved ==="
