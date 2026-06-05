📦 2. PrometheusService.sh

Now the same pattern for Prometheus (this is the missing piece you asked for).

Create:

sudo vi PrometheusService.sh

Paste:

#!/bin/bash

# =============================================================================
# Prometheus Kubernetes Service Installer (OpenFaaS)
# =============================================================================
#
# PURPOSE:
# Ensures Prometheus is exposed via stable ClusterIP Service.
# Supports consistent port-forwarding on 9090.
#
# =============================================================================

set -e

echo "[INFO] Checking Prometheus service..."

# Prometheus already exists in your cluster, but we ensure consistency
kubectl get svc -n openfaas prometheus >/dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "[INFO] Creating Prometheus service..."

  cat <<EOF > /tmp/prometheus-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: openfaas
spec:
  selector:
    app: prometheus
  ports:
    - name: http
      port: 9090
      targetPort: 9090
  type: ClusterIP
EOF

  kubectl apply -f /tmp/prometheus-service.yaml
else
  echo "[INFO] Prometheus service already exists (no changes needed)"
fi

echo "[INFO] Verifying Prometheus service..."
kubectl get svc -n openfaas prometheus
kubectl get endpoints -n openfaas prometheus

echo "[SUCCESS] Prometheus service ready"

Make executable:

chmod +x PrometheusService.sh

Run:

./PrometheusService.sh