#!/bin/bash

# =============================================================================
# Kubernetes Dashboard Admin Account Setup (Long-lived Token)
# =============================================================================

set -e

echo ""
echo "=================================================="
echo " KUBERNETES DASHBOARD ADMIN SETUP"
echo "=================================================="
echo ""

# -----------------------------------------------------------------------------
# STEP 1 — CREATE DASHBOARD ADMIN SERVICEACCOUNT + ROLE BINDING
# -----------------------------------------------------------------------------
echo "[STEP 1] Creating dashboard-admin configuration..."

cat <<EOF >/tmp/dashboard-admin.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dashboard-admin
  namespace: kubernetes-dashboard

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dashboard-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: dashboard-admin
  namespace: kubernetes-dashboard
EOF

kubectl apply -f /tmp/dashboard-admin.yaml

echo "[OK] ServiceAccount and ClusterRoleBinding applied"

# -----------------------------------------------------------------------------
# STEP 2 — CREATE LONG-LIVED TOKEN (Secret)
# -----------------------------------------------------------------------------
echo "[STEP 2] Creating long-lived token..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: dashboard-admin-token
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: "dashboard-admin"
type: kubernetes.io/service-account-token
EOF

echo "[OK] Long-lived token Secret created"

# -----------------------------------------------------------------------------
# STEP 3 — RETRIEVE TOKEN
# -----------------------------------------------------------------------------
echo "[STEP 3] Retrieving long-lived token..."

TOKEN=$(kubectl get secret dashboard-admin-token -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 -d)

echo ""
echo "=================================================="
echo " DASHBOARD LOGIN TOKEN (LONG-LIVED)"
echo "=================================================="
echo ""
echo "$TOKEN"
echo ""
echo "=================================================="

# -----------------------------------------------------------------------------
# FINAL INSTRUCTIONS
# -----------------------------------------------------------------------------
echo ""
echo "Dashboard URL:"
echo "  https://127.0.0.1:8001/"
echo ""
echo "Login Method:   Token"
echo "Token Source:   dashboard-admin-token (long-lived)"
echo ""
echo "This token should last much longer (often months) until manually deleted."
echo ""
echo "You can get the token anytime with:"
echo "  kubectl get secret dashboard-admin-token -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 -d"
echo ""
echo "=================================================="

# Cleanup temp file
rm -f /tmp/dashboard-admin.yaml
