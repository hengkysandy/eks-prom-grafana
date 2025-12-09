# Operations Runbook

## Daily Operations

### Morning Health Check

```bash
# 1. Check all nodes are ready
kubectl get nodes

# 2. Check all pods are running
kubectl get pods -A | grep -v Running | grep -v Completed

# 3. Check for firing alerts
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.state=="firing")'

# 4. Check storage usage
kubectl exec -n monitoring deployment/prometheus -- df -h /prometheus
kubectl exec -n monitoring deployment/loki -- df -h /loki
```

### Accessing Dashboards

```bash
# Grafana (main observability)
kubectl port-forward -n monitoring svc/grafana 3001:3000
# URL: http://localhost:3001 (admin/admin)

# Prometheus (metrics/alerts)
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# URL: http://localhost:9090

# Alertmanager (alert management)
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
# URL: http://localhost:9093

# Kubernetes Dashboard
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
# URL: https://localhost:8443
# Token: kubectl get secret admin-user -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 --decode
```

## Common Tasks

### Restart a Deployment

```bash
kubectl rollout restart deployment/<name> -n <namespace>
kubectl rollout status deployment/<name> -n <namespace>
```

### Scale a Deployment

```bash
# Scale up
kubectl scale deployment/<name> -n <namespace> --replicas=3

# Scale down
kubectl scale deployment/<name> -n <namespace> --replicas=1
```

### View Logs

```bash
# Current logs
kubectl logs -n <namespace> deployment/<name> -f

# Previous container (after crash)
kubectl logs -n <namespace> <pod-name> --previous

# All pods of a deployment
kubectl logs -n <namespace> -l app=<label> --all-containers
```

### Execute into Pod

```bash
kubectl exec -it -n <namespace> <pod-name> -- /bin/sh
```

### Check Resource Usage

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -n <namespace>
```

## Incident Response

### Service Outage

1. **Identify**: Check which service is down
   ```bash
   kubectl get pods -n ecommerce-poc
   ```

2. **Investigate**: Check logs and events
   ```bash
   kubectl logs -n ecommerce-poc deployment/<service> --tail=100
   kubectl describe pod -n ecommerce-poc -l app=<service>
   ```

3. **Mitigate**: Restart or rollback
   ```bash
   # Restart
   kubectl rollout restart deployment/<service> -n ecommerce-poc
   
   # Or rollback
   kubectl rollout undo deployment/<service> -n ecommerce-poc
   ```

4. **Verify**: Confirm service is back
   ```bash
   kubectl get pods -n ecommerce-poc -l app=<service>
   curl http://localhost:<port>/health
   ```

### High Memory/CPU

1. **Identify**: Find resource-hungry pods
   ```bash
   kubectl top pods -n ecommerce-poc --sort-by=memory
   kubectl top pods -n ecommerce-poc --sort-by=cpu
   ```

2. **Investigate**: Check for leaks or spikes
   ```bash
   # Check Grafana Pod Metrics dashboard
   # Look for memory growth over time
   ```

3. **Mitigate**: Restart or scale
   ```bash
   kubectl rollout restart deployment/<service> -n ecommerce-poc
   ```

### Disk Full

1. **Identify**: Check PVC usage
   ```bash
   kubectl exec -n monitoring deployment/prometheus -- df -h /prometheus
   ```

2. **Mitigate**: 
   - Reduce retention period
   - Delete old data
   - Expand PVC (if supported)

## Maintenance Procedures

### Update Application

```bash
# 1. Build new image
cd apps
./build-and-push.sh

# 2. Update deployment
kubectl set image deployment/<name> -n ecommerce-poc <container>=<new-image>

# 3. Monitor rollout
kubectl rollout status deployment/<name> -n ecommerce-poc
```

### Update Kubernetes Manifests

```bash
# 1. Edit manifest
vim k8s/<file>.yaml

# 2. Apply changes
kubectl apply -f k8s/<file>.yaml

# 3. Verify
kubectl get pods -n <namespace>
```

### Terraform Changes

```bash
cd terraform

# 1. Plan changes
terraform plan

# 2. Review output carefully

# 3. Apply
terraform apply

# 4. Update kubeconfig if needed
aws eks update-kubeconfig --region ap-southeast-1 --name ecommerce-poc-eks
```

## Backup & Recovery

### Export Grafana Dashboards

```bash
# Get dashboard JSON
kubectl port-forward -n monitoring svc/grafana 3001:3000 &
curl -s http://admin:admin@localhost:3001/api/dashboards/uid/<uid> | jq '.dashboard' > dashboard-backup.json
```

### Export Prometheus Rules

```bash
kubectl get configmap alert-rules -n monitoring -o yaml > alert-rules-backup.yaml
```

### Disaster Recovery

If cluster is lost:
1. Run `terraform apply` to recreate infrastructure
2. Run `kubectl apply -k k8s/` to redeploy workloads
3. Restore Grafana dashboards from backups
4. Data in PVCs will be lost (consider backup solutions for production)

## Useful Commands Reference

```bash
# Get all resources in namespace
kubectl get all -n <namespace>

# Describe resource
kubectl describe <resource> <name> -n <namespace>

# Get YAML of resource
kubectl get <resource> <name> -n <namespace> -o yaml

# Delete resource
kubectl delete <resource> <name> -n <namespace>

# Watch resources
kubectl get pods -n <namespace> -w

# Port forward
kubectl port-forward -n <namespace> svc/<service> <local>:<remote>

# Copy files from pod
kubectl cp <namespace>/<pod>:<path> <local-path>
```
