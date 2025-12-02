# Application Code

Three microservices for the e-commerce PoC:

1. **Node.js Catalog Service** (Port 3000)
   - `/products` - List all products
   - `/products/:id` - Get product by ID
   - `/health` - Health check
   - `/metrics` - Prometheus metrics

2. **Python Orders Service** (Port 5000)
   - `/orders` - List all orders
   - `/orders/:id` - Get order by ID
   - `/health` - Health check
   - `/metrics` - Prometheus metrics

3. **Go Inventory Service** (Port 8080)
   - `/inventory` - List all inventory items
   - `/inventory/item?id=1` - Get item by ID
   - `/health` - Health check
   - `/metrics` - Prometheus metrics

## Prerequisites

- Docker installed and running
- AWS CLI configured with credentials
- ECR repositories created (from Terraform Phase 1)

## Build and Push All Images

```bash
cd apps
./build-and-push.sh
```

This script will:
1. Authenticate with ECR
2. Build all 3 Docker images
3. Tag them with ECR repository URLs
4. Push to ECR

**Expected duration:** 3-5 minutes

## Manual Build (Alternative)

### Node.js Service
```bash
cd nodejs
docker build -t ecommerce-nodejs-catalog:latest .
docker tag ecommerce-nodejs-catalog:latest 683031685817.dkr.ecr.ap-southeast-1.amazonaws.com/ecommerce-nodejs-catalog:latest
docker push 683031685817.dkr.ecr.ap-southeast-1.amazonaws.com/ecommerce-nodejs-catalog:latest
```

### Python Service
```bash
cd python
docker build -t ecommerce-python-orders:latest .
docker tag ecommerce-python-orders:latest 683031685817.dkr.ecr.ap-southeast-1.amazonaws.com/ecommerce-python-orders:latest
docker push 683031685817.dkr.ecr.ap-southeast-1.amazonaws.com/ecommerce-python-orders:latest
```

### Go Service
```bash
cd go
docker build -t ecommerce-go-inventory:latest .
docker tag ecommerce-go-inventory:latest 683031685817.dkr.ecr.ap-southeast-1.amazonaws.com/ecommerce-go-inventory:latest
docker push 683031685817.dkr.ecr.ap-southeast-1.amazonaws.com/ecommerce-go-inventory:latest
```

## Test Locally (Before Pushing)

### Node.js
```bash
cd nodejs
docker build -t nodejs-catalog .
docker run -p 3000:3000 nodejs-catalog
# Test: curl http://localhost:3000/health
```

### Python
```bash
cd python
docker build -t python-orders .
docker run -p 5000:5000 python-orders
# Test: curl http://localhost:5000/health
```

### Go
```bash
cd go
docker build -t go-inventory .
docker run -p 8080:8080 go-inventory
# Test: curl http://localhost:8080/health
```

## Verify Images in ECR

```bash
aws ecr describe-images --repository-name ecommerce-nodejs-catalog --region ap-southeast-1
aws ecr describe-images --repository-name ecommerce-python-orders --region ap-southeast-1
aws ecr describe-images --repository-name ecommerce-go-inventory --region ap-southeast-1
```

## Troubleshooting

### Docker not running
```bash
# macOS
open -a Docker

# Verify
docker ps
```

### ECR authentication failed
```bash
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin 683031685817.dkr.ecr.ap-southeast-1.amazonaws.com
```

### Build errors
- Node.js: Ensure Node.js 20+ is available in Docker
- Python: Check requirements.txt dependencies
- Go: Verify go.mod is correct
