# Kubernetes Manifests

Kubernetes resources for the e-commerce microservices PoC with EC2 nodes.

## Directory Structure

```
k8s/
├── namespace.yaml          # ecommerce-poc and monitoring namespaces
├── storage-class.yaml      # EBS gp3 StorageClass
├── kustomization.yaml      # Kustomize configuration
├── nodejs-deployment.yaml  # Node.js catalog service
├── python-deployment.yaml  # Python orders service
├── go-deployment.yaml      # Go inventory service
├── traffic-generator.yaml  # Traffic generator pod
├── prometheus/
│   ├── prometheus-deployment.yaml  # Prometheus with 30GB PVC
│   └── kube-state-metrics.yaml     # Kubernetes metrics
├── grafana/
│   └── grafana-deployment.yaml     # Grafana with 10GB PVC
├── loki/
│   └── loki-deployment.yaml        # Loki with 10GB PVC
└── tempo/
    └── tempo-deployment.yaml       # Tempo with 10GB PVC
```

## Deployment

```bash
# Deploy all resources
kubectl apply -k .

# Check status
kubectl get pods -A
kubectl get pvc -n monitoring
```

## Namespaces

- `ecommerce-poc`: Application microservices
- `monitoring`: Observability stack (Prometheus, Grafana, Loki, Tempo)

## Persistent Volumes

| Component | Size | StorageClass |
|-----------|------|--------------|
| Prometheus | 30GB | ebs-gp3 |
| Grafana | 10GB | ebs-gp3 |
| Loki | 10GB | ebs-gp3 |
| Tempo | 10GB | ebs-gp3 |

## Access Services

```bash
# Grafana
kubectl port-forward -n monitoring svc/grafana 3001:3000

# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Application
kubectl port-forward -n ecommerce-poc svc/nodejs-catalog 3000:3000
```

## Cleanup

```bash
kubectl delete -k .
```
