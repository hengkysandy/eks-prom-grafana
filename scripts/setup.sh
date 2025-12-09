#!/bin/bash
# Setup script for E-Commerce Microservices PoC
# This script helps new users get started quickly

set -e

echo "=========================================="
echo "E-Commerce Microservices PoC Setup"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    # AWS CLI
    if command -v aws &> /dev/null; then
        echo -e "${GREEN}✓${NC} AWS CLI: $(aws --version | cut -d' ' -f1)"
    else
        echo -e "${RED}✗${NC} AWS CLI not found. Install: https://aws.amazon.com/cli/"
        exit 1
    fi
    
    # kubectl
    if command -v kubectl &> /dev/null; then
        echo -e "${GREEN}✓${NC} kubectl: $(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')"
    else
        echo -e "${RED}✗${NC} kubectl not found. Install: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    # Terraform
    if command -v terraform &> /dev/null; then
        echo -e "${GREEN}✓${NC} Terraform: $(terraform version -json | jq -r '.terraform_version')"
    else
        echo -e "${RED}✗${NC} Terraform not found. Install: https://www.terraform.io/downloads"
        exit 1
    fi
    
    # Docker
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
    else
        echo -e "${RED}✗${NC} Docker not found. Install: https://www.docker.com/get-started"
        exit 1
    fi
    
    # Helm
    if command -v helm &> /dev/null; then
        echo -e "${GREEN}✓${NC} Helm: $(helm version --short)"
    else
        echo -e "${YELLOW}!${NC} Helm not found (optional). Install: https://helm.sh/docs/intro/install/"
    fi
    
    echo ""
}

# Check AWS credentials
check_aws_credentials() {
    echo "Checking AWS credentials..."
    
    if aws sts get-caller-identity &> /dev/null; then
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        echo -e "${GREEN}✓${NC} AWS Account: $ACCOUNT_ID"
    else
        echo -e "${RED}✗${NC} AWS credentials not configured. Run: aws configure"
        exit 1
    fi
    
    echo ""
}

# Main menu
show_menu() {
    echo "What would you like to do?"
    echo ""
    echo "1) Deploy infrastructure (Terraform)"
    echo "2) Build and push Docker images"
    echo "3) Deploy Kubernetes resources"
    echo "4) Run quick test"
    echo "5) Access dashboards"
    echo "6) Full setup (1-4)"
    echo "7) Destroy everything"
    echo "0) Exit"
    echo ""
    read -p "Enter choice [0-7]: " choice
}

# Deploy infrastructure
deploy_infrastructure() {
    echo ""
    echo "Deploying infrastructure with Terraform..."
    cd terraform
    
    terraform init
    terraform plan -out=tfplan
    
    read -p "Apply this plan? (y/n): " confirm
    if [[ $confirm == "y" ]]; then
        terraform apply tfplan
        
        # Update kubeconfig
        echo ""
        echo "Updating kubeconfig..."
        aws eks update-kubeconfig --region ap-southeast-1 --name ecommerce-poc-eks
        
        echo -e "${GREEN}✓${NC} Infrastructure deployed!"
    fi
    
    cd ..
}

# Build and push images
build_images() {
    echo ""
    echo "Building and pushing Docker images..."
    cd apps
    ./build-and-push.sh
    cd ..
    echo -e "${GREEN}✓${NC} Images built and pushed!"
}

# Deploy Kubernetes resources
deploy_kubernetes() {
    echo ""
    echo "Deploying Kubernetes resources..."
    cd k8s
    kubectl apply -k .
    
    echo ""
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=nodejs-catalog -n ecommerce-poc --timeout=120s || true
    kubectl wait --for=condition=ready pod -l app=python-orders -n ecommerce-poc --timeout=120s || true
    kubectl wait --for=condition=ready pod -l app=go-inventory -n ecommerce-poc --timeout=120s || true
    
    cd ..
    echo -e "${GREEN}✓${NC} Kubernetes resources deployed!"
}

# Run quick test
run_quick_test() {
    echo ""
    echo "Running quick test..."
    cd k8s/tests
    ./quick-test.sh
    cd ../..
}

# Access dashboards
access_dashboards() {
    echo ""
    echo "Dashboard Access Instructions:"
    echo ""
    echo "1. Grafana (Observability):"
    echo "   kubectl port-forward -n monitoring svc/grafana 3001:3000"
    echo "   URL: http://localhost:3001"
    echo "   Login: admin/admin"
    echo ""
    echo "2. Prometheus (Metrics):"
    echo "   kubectl port-forward -n monitoring svc/prometheus 9090:9090"
    echo "   URL: http://localhost:9090"
    echo ""
    echo "3. Alertmanager (Alerts):"
    echo "   kubectl port-forward -n monitoring svc/alertmanager 9093:9093"
    echo "   URL: http://localhost:9093"
    echo ""
    echo "4. Kubernetes Dashboard:"
    echo "   kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443"
    echo "   URL: https://localhost:8443"
    echo ""
    
    read -p "Start Grafana port-forward now? (y/n): " confirm
    if [[ $confirm == "y" ]]; then
        echo "Starting Grafana on http://localhost:3001 (Ctrl+C to stop)"
        kubectl port-forward -n monitoring svc/grafana 3001:3000
    fi
}

# Destroy everything
destroy_all() {
    echo ""
    echo -e "${RED}WARNING: This will destroy all resources!${NC}"
    read -p "Are you sure? (type 'yes' to confirm): " confirm
    
    if [[ $confirm == "yes" ]]; then
        echo "Deleting Kubernetes resources..."
        cd k8s
        kubectl delete -k . || true
        cd ..
        
        echo "Destroying Terraform infrastructure..."
        cd terraform
        terraform destroy -auto-approve
        cd ..
        
        echo -e "${GREEN}✓${NC} All resources destroyed!"
    fi
}

# Full setup
full_setup() {
    deploy_infrastructure
    build_images
    deploy_kubernetes
    run_quick_test
    
    echo ""
    echo "=========================================="
    echo -e "${GREEN}Setup Complete!${NC}"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Access Grafana: kubectl port-forward -n monitoring svc/grafana 3001:3000"
    echo "2. Open http://localhost:3001 (admin/admin)"
    echo "3. Explore the dashboards!"
}

# Main
check_prerequisites
check_aws_credentials

while true; do
    show_menu
    
    case $choice in
        1) deploy_infrastructure ;;
        2) build_images ;;
        3) deploy_kubernetes ;;
        4) run_quick_test ;;
        5) access_dashboards ;;
        6) full_setup ;;
        7) destroy_all ;;
        0) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid option" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
