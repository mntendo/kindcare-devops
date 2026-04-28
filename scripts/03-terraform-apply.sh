#!/bin/bash
set -e

echo "=== STEP 3: Apply Terraform Infrastructure ==="

cd terraform/environments/$ENVIRONMENT

terraform init
terraform plan -var="db_password=$DB_PASSWORD" -out=tfplan
terraform apply -auto-approve tfplan

echo "=== Terraform applied successfully ==="
