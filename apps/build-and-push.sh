#!/bin/bash

set -e

# Configuration
AWS_REGION="ap-southeast-1"
AWS_ACCOUNT_ID="683031685817"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# ECR Repository names
NODEJS_REPO="ecommerce-nodejs-catalog"
PYTHON_REPO="ecommerce-python-orders"
GO_REPO="ecommerce-go-inventory"

echo "=========================================="
echo "Building and Pushing Docker Images to ECR"
echo "=========================================="

# Authenticate with ECR
echo "Authenticating with ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Build and push Node.js service
echo ""
echo "Building Node.js Catalog Service..."
cd nodejs
docker build -t ${NODEJS_REPO}:latest .
docker tag ${NODEJS_REPO}:latest ${ECR_REGISTRY}/${NODEJS_REPO}:latest
echo "Pushing Node.js image to ECR..."
docker push ${ECR_REGISTRY}/${NODEJS_REPO}:latest
cd ..

# Build and push Python service
echo ""
echo "Building Python Orders Service..."
cd python
docker build -t ${PYTHON_REPO}:latest .
docker tag ${PYTHON_REPO}:latest ${ECR_REGISTRY}/${PYTHON_REPO}:latest
echo "Pushing Python image to ECR..."
docker push ${ECR_REGISTRY}/${PYTHON_REPO}:latest
cd ..

# Build and push Go service
echo ""
echo "Building Go Inventory Service..."
cd go
docker build -t ${GO_REPO}:latest .
docker tag ${GO_REPO}:latest ${ECR_REGISTRY}/${GO_REPO}:latest
echo "Pushing Go image to ECR..."
docker push ${ECR_REGISTRY}/${GO_REPO}:latest
cd ..

echo ""
echo "=========================================="
echo "✅ All images built and pushed successfully!"
echo "=========================================="
echo ""
echo "Images pushed:"
echo "  - ${ECR_REGISTRY}/${NODEJS_REPO}:latest"
echo "  - ${ECR_REGISTRY}/${PYTHON_REPO}:latest"
echo "  - ${ECR_REGISTRY}/${GO_REPO}:latest"
echo ""
