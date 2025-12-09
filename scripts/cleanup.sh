#!/bin/bash
# Cleanup script for E-Commerce Microservices PoC
# Use this to properly tear down all resources

set -e

echo "=========================================="
echo "E-Commerce Microservices PoC Cleanup"
echo "=========================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${RED}WARNING: This will delete all resources!${NC}"
echo ""
echo "This script will:"
echo "1. Delete all Kubernetes resources"
echo "2. Delete Kubernetes Dashboard (Helm)"
echo "3. Wait for PVCs to be deleted"
echo "4. Destroy Terraform infrastructure"
echo ""

read -p "Are you sure you want to continue? (type 'yes'): " confirm

if [[ $confirm != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Step 1: Deleting Kubernetes resources..."
cd k8s
kubectl delete -k . --ignore-not-found=true || true
cd ..

echo ""
echo "Step 2: Deleting Kubernetes Dashboard..."
helm uninstall kubernetes-dashboard -n kubernetes-dashboard 2>/dev/null || true
kubectl delete namespace kubernetes-dashboard --ignore-not-found=true || true

echo ""
echo "Step 3: Waiting for PVCs to be deleted..."
echo "Checking PVCs..."
kubectl get pvc -A 2>/dev/null || true

# Wait up to 2 minutes for PVCs to be deleted
for i in {1..24}; do
    PVC_COUNT=$(kubectl get pvc -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [[ $PVC_COUNT -eq 0 ]]; then
        echo "All PVCs deleted."
        break
    fi
    echo "Waiting for $PVC_COUNT PVCs to be deleted... ($i/24)"
    sleep 5
done

echo ""
echo "Step 4: Destroying Terraform infrastructure..."
cd terraform
terraform destroy -auto-approve
cd ..

echo ""
echo -e "${GREEN}=========================================="
echo "Cleanup Complete!"
echo "==========================================${NC}"
echo ""
echo "All resources have been deleted."
echo "Your AWS account should no longer incur charges for this project."
