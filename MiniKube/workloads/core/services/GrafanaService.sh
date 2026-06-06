#!/bin/bash

# =============================================================================
# Grafana Kubernetes Service + Secure Credential Bootstrap (OpenFaaS)
# =============================================================================
#
# PURPOSE:
# - Ensures Grafana Service is stable (ClusterIP)
# - Establishes /etc/grafana/grafana.env as single source of truth
# - Avoids Kubernetes mutation assumptions (NO deployment patching)
# - Provides safe validation without SSH/session risk
#
# IMPORTANT:
# Grafana in this lab runs as a POD, NOT a Deployment.
# Therefore we do NOT use kubectl set env deployment/grafana.
#
# =============================================================================

set -euo pipefail

# =============================================================================
# STEP 1 - CREATE SERVICE (IDEMPOTENT)
# =============================================================================

echo "[STEP 1] Creating Grafana service manifest..."

cat <<EOF > /tmp/grafana-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: openfaas
spec:
  selector:
    run: grafana
  ports:
    - name: http
      port: 3000
      targetPort: 3000
  type: ClusterIP
EOF

echo "[STEP 2] Applying Grafana service..."
kubectl apply -f /tmp/grafana-service.yaml

echo "[STEP 3] Verifying service..."
kubectl get svc -n openfaas grafana
kubectl get endpoints -n openfaas grafana

# =============================================================================
# STEP 4 - VM-LEVEL SECRET SOURCE OF TRUTH
# =============================================================================

echo "[STEP 4] Creating Grafana credential file (/etc/grafana/grafana.env)..."

sudo mkdir -p /etc/grafana

sudo tee /etc/grafana/grafana.env >/dev/null <<'EOF'
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=changeme   # Set your password here before running
EOF

sudo chmod 600 /etc/grafana/grafana.env
sudo chown root:root /etc/grafana/grafana.env

echo "[STEP 4B] Credentials stored securely at /etc/grafana/grafana.env"

# =============================================================================
# STEP 5 - SAFE VALIDATION (NO K8S MUTATION, NO SSH RISK)
# =============================================================================

echo "[STEP 5] Validating Grafana pod (no modification)..."

kubectl get pods -n openfaas | grep grafana || true

echo "[STEP 6] Validating Grafana service..."
kubectl get svc -n openfaas grafana

# =============================================================================
# STEP 6 - OPTIONAL API CHECK (SAFE SECRET READ)
# =============================================================================

echo "[STEP 7] Running safe API validation..."

GF_USER=$(sudo grep GF_SECURITY_ADMIN_USER /etc/grafana/grafana.env | cut -d'=' -f2)
GF_PASS=$(sudo grep GF_SECURITY_ADMIN_PASSWORD /etc/grafana/grafana.env | cut -d'=' -f2)

curl -s -u "$GF_USER:$GF_PASS" http://127.0.0.1:3000/api/health || true

# =============================================================================
# STEP 7 - FINAL OUTPUT
# =============================================================================

echo ""
echo "=================================================="
echo " GRAFANA SETUP COMPLETE (HARDENED LAB VERSION)"
echo "=================================================="

echo "[INFO] Grafana Service:"
kubectl get svc -n openfaas grafana

echo ""
echo "[INFO] Grafana Pod:"
kubectl get pods -n openfaas | grep grafana

echo ""
echo "[INFO] Credential Source:"
echo "  /etc/grafana/grafana.env"

echo ""
echo "[INFO] Access:"
echo "  http://127.0.0.1:3000"
echo "=================================================="