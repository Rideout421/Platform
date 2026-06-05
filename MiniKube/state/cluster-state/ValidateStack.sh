#!/bin/bash

set -e

echo ""
echo "=================================================="
echo " KUBERNETES + HOST LAB VALIDATION STARTING"
echo "=================================================="
echo ""

# ------------------------------------------------------------------
# 1. MINIKUBE
# ------------------------------------------------------------------
echo "[CHECK 1] Minikube Status"
minikube status
echo ""

# ------------------------------------------------------------------
# 2. KUBERNETES NODES
# ------------------------------------------------------------------
echo "[CHECK 2] Kubernetes Nodes"
kubectl get nodes -o wide
echo ""

# ------------------------------------------------------------------
# 3. CLUSTER PODS
# ------------------------------------------------------------------
echo "[CHECK 3] Cluster Pods"
kubectl get pods -A | grep -E 'openfaas|kube-system' || true
echo ""

# ------------------------------------------------------------------
# 4. OPENFAAS SERVICES
# ------------------------------------------------------------------
echo "[CHECK 4] OpenFaaS Services"
kubectl get svc -n openfaas || true
echo ""

# ------------------------------------------------------------------
# 5. PROMETHEUS
# ------------------------------------------------------------------
echo "[CHECK 5] Prometheus"
kubectl get svc -n openfaas prometheus || echo "Prometheus service missing"
kubectl get endpoints -n openfaas prometheus || echo "Prometheus endpoints missing"
echo ""

# ------------------------------------------------------------------
# 6. GRAFANA
# ------------------------------------------------------------------
echo "[CHECK 6] Grafana"
kubectl get svc -n openfaas grafana || echo "Grafana service missing"
kubectl get endpoints -n openfaas grafana || echo "Grafana endpoints missing"
echo ""

# ------------------------------------------------------------------
# 7. KUBERNETES DASHBOARD
# ------------------------------------------------------------------
echo "[CHECK 7] Kubernetes Dashboard"

kubectl get ns kubernetes-dashboard >/dev/null 2>&1 && \
kubectl get pods -n kubernetes-dashboard || echo "Dashboard not deployed"

kubectl get svc -n kubernetes-dashboard || echo "Dashboard service missing"

echo ""

# ------------------------------------------------------------------
# 8. MINIO (LOCAL HOST VALIDATION)
# ------------------------------------------------------------------
echo "[CHECK 8] MinIO (Local Host Service)"

echo "-> Process check:"
if pgrep -fa minio >/dev/null; then
    pgrep -fa minio
else
    echo "MinIO process: NOT RUNNING"
fi

echo ""
echo "-> Port check:"
if ss -tulpn | grep -qE '9000|9001'; then
    ss -tulpn | grep -E '9000|9001'
else
    echo "MinIO ports (9000/9001): NOT LISTENING"
fi

echo ""
echo "-> Systemd check (if applicable):"
if systemctl list-unit-files | grep -q minio; then
    systemctl status minio --no-pager || true
else
    echo "No MinIO systemd service registered"
fi

echo ""

# ------------------------------------------------------------------
# 9. PORT FORWARDS
# ------------------------------------------------------------------
echo "[CHECK 9] Active Port Forwards"
ss -tulpn | grep -E '9090|3000|8001' || echo "No port-forwards active"
echo ""

# ------------------------------------------------------------------
# 10. FINAL SUMMARY
# ------------------------------------------------------------------
echo "=================================================="
echo " LAB VALIDATION SUMMARY"
echo "=================================================="

echo "Prometheus : http://127.0.0.1:9090"
echo "Grafana    : http://127.0.0.1:3000"
echo "Dashboard  : https://127.0.0.1:8001"
echo "MinIO      : http://127.0.0.1:9000 (if running)"
echo ""

echo "Cluster     : $(minikube status | grep host | awk '{print $2}' 2>/dev/null || echo 'unknown')"

echo ""
echo "=================================================="
echo " VALIDATION COMPLETE"
echo "=================================================="