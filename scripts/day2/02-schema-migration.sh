#!/bin/bash
set -e

echo "=== DAY 2: Database Schema Migration ==="
echo "This script safely applies database schema changes"

MIGRATION_VERSION=${MIGRATION_VERSION:-"v2"}

# Step 1 - Check current pod status before migration
echo "--- Step 1: Current deployment status ---"
kubectl get pods -n kindcare

# Step 2 - Create migration as a Kubernetes Job
echo "--- Step 2: Running database migration job ---"
cat <<MIGRATION | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration-$MIGRATION_VERSION
  namespace: kindcare
spec:
  template:
    spec:
      containers:
      - name: migration
        image: postgres:15-alpine
        command:
          - /bin/sh
          - -c
          - |
            echo "Running migration $MIGRATION_VERSION..."
            PGPASSWORD=\$DB_PASSWORD psql \
              -h \$DB_HOST \
              -U \$DB_USER \
              -d \$DB_NAME \
              -c "ALTER TABLE patients ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();"
            PGPASSWORD=\$DB_PASSWORD psql \
              -h \$DB_HOST \
              -U \$DB_USER \
              -d \$DB_NAME \
              -c "ALTER TABLE patients ADD COLUMN IF NOT EXISTS discharge_notes TEXT;"
            echo "Migration $MIGRATION_VERSION complete!"
        env:
          - name: DB_HOST
            valueFrom:
              secretKeyRef:
                name: kindcare-db-secret
                key: host
          - name: DB_USER
            valueFrom:
              secretKeyRef:
                name: kindcare-db-secret
                key: username
          - name: DB_PASSWORD
            valueFrom:
              secretKeyRef:
                name: kindcare-db-secret
                key: password
          - name: DB_NAME
            valueFrom:
              secretKeyRef:
                name: kindcare-db-secret
                key: name
      restartPolicy: Never
  backoffLimit: 3
MIGRATION

# Step 3 - Wait for migration to complete
echo "--- Step 3: Waiting for migration to complete ---"
kubectl wait --for=condition=complete \
  job/db-migration-$MIGRATION_VERSION \
  -n kindcare \
  --timeout=120s

# Step 4 - Check migration job logs
echo "--- Step 4: Migration logs ---"
kubectl logs -n kindcare \
  -l job-name=db-migration-$MIGRATION_VERSION

# Step 5 - Rolling restart of services to pick up schema changes
echo "--- Step 5: Rolling restart of services ---"
kubectl rollout restart deployment/triage-service deployment/bed-service deployment/alerts-service -n kindcare
kubectl rollout status deployment -n kindcare

echo "=== Schema migration complete ==="
