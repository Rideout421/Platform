echo "===== CLUSTER INFO ====="
timeout 10 kubectl cluster-info 2>/dev/null || echo "Unavailable"

echo -e "\n===== NODES ====="
timeout 10 kubectl get nodes -o wide 2>/dev/null || echo "Unavailable"

echo -e "\n===== NAMESPACES ====="
timeout 10 kubectl get ns 2>/dev/null || echo "Unavailable"

echo -e "\n===== HELM DEPLOYMENTS ====="
timeout 10 helm list -A 2>/dev/null || echo "Helm unavailable"

echo -e "\n===== PODS ====="
timeout 15 kubectl get pods -A -o wide 2>/dev/null || echo "Unavailable"

echo -e "\n===== SERVICES ====="
timeout 10 kubectl get svc -A 2>/dev/null || echo "Unavailable"

echo -e "\n===== INGRESS ====="
timeout 10 kubectl get ingress -A 2>/dev/null || echo "None or unavailable"

echo -e "\n===== STORAGE ====="
timeout 10 kubectl get pvc -A 2>/dev/null || echo "PVC unavailable"
echo
timeout 10 kubectl get pv 2>/dev/null || echo "PV unavailable"

echo -e "\n===== OPENFAAS ====="
timeout 10 faas-cli list 2>/dev/null || echo "faas-cli unavailable"
echo
timeout 10 kubectl get all -n openfaas 2>/dev/null || echo "openfaas namespace unavailable"
echo
timeout 10 kubectl get all -n openfaas-fn 2>/dev/null || echo "openfaas-fn namespace unavailable"

echo -e "\n===== OBSERVABILITY ====="
timeout 10 sh -c "kubectl get pods -A | egrep -i 'grafana|prometheus|metrics|alert|loki'" 2>/dev/null || echo "No observability pods found"
echo
timeout 10 kubectl get servicemonitors -A 2>/dev/null || echo "No ServiceMonitors"

echo -e "\n===== MINIO ====="
if command -v systemctl >/dev/null 2>&1; then
  if timeout 10 systemctl is-active --quiet minio; then
    echo "MinIO service is active"
  else
    echo "MinIO service is not active"
  fi
elif timeout 10 pgrep -af minio >/dev/null 2>&1; then
  echo "MinIO process is running"
else
  echo "MinIO not found locally"
fi

if command -v curl >/dev/null 2>&1; then
  if timeout 10 curl -sSf http://127.0.0.1:9000/minio/health/ready >/dev/null 2>&1; then
    echo "MinIO HTTP health endpoint reachable"
  else
    echo "MinIO HTTP health endpoint unreachable"
  fi
else
  echo "curl unavailable for MinIO health check"
fi

echo -e "\n===== RESOURCE USAGE ====="
timeout 10 kubectl top nodes 2>/dev/null || echo "Metrics unavailable"
echo
timeout 10 kubectl top pods -A 2>/dev/null || echo "Metrics unavailable"
