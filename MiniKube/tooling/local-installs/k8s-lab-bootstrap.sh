#!/bin/bash

# =============================================================================
# KUBERNETES LAB SETUP RUNBOOK (REFERENCE / INSTALL GUIDE)
# =============================================================================
#
# PURPOSE
# -----------------------------------------------------------------------------
# This file is NOT executed as a single script.
#
# It is a REBUILD GUIDE used to recreate:
#   - Minikube auto-start service
#   - Kubernetes port-forward exposure layer
#
# Components are intentionally separated:
#   1. Minikube systemd service (already created earlier)
#   2. Lab bootstrap script (/usr/local/bin/k8s-lab-bootstrap.sh)
#   3. Optional systemd service for bootstrap script
#
# =============================================================================


# =============================================================================
# STEP 1 — VERIFY BASE SYSTEM STATE
# =============================================================================
#
# Run these BEFORE doing anything else:
#
#   minikube status
#   kubectl get nodes
#   kubectl get pods -A
#
# Expected:
#   - cluster = Running
#   - nodes = Ready
#   - openfaas pods = Running
#
# =============================================================================


# =============================================================================
# STEP 2 — CREATE BOOTSTRAP SCRIPT (PORT FORWARD LAYER)
# =============================================================================
#
# FILE LOCATION:
#   /usr/local/bin/k8s-lab-bootstrap.sh
#
# CREATE FILE:
#
#   sudo vi /usr/local/bin/k8s-lab-bootstrap.sh
#
# CONTENT (PASTE BELOW EXACTLY)
# -----------------------------------------------------------------------------

#!/bin/bash
set -euo pipefail

LOG_DIR="/tmp/k8s-lab"
mkdir -p "$LOG_DIR"

echo "[BOOTSTRAP] Waiting for Kubernetes cluster..."

until kubectl get nodes >/dev/null 2>&1; do
  sleep 5
done

echo "[BOOTSTRAP] Cluster READY"

# =============================================================================
# OPENFAAS NODEPORT ALIGNMENT
# =============================================================================

echo "[BOOTSTRAP] Aligning OpenFaaS NodePort access..."

MINIKUBE_IP=$(minikube ip)
OPENFAAS_URL="http://${MINIKUBE_IP}:31112"

export OPENFAAS_URL="${OPENFAAS_URL}"

grep -q "OPENFAAS_URL" ~/.bashrc || \
echo "export OPENFAAS_URL=${OPENFAAS_URL}" >> ~/.bashrc

echo "[BOOTSTRAP] OpenFaaS URL: ${OPENFAAS_URL}"

# Validate OpenFaaS gateway (auth-safe)
if curl -s -u admin:"$(kubectl get secret -n openfaas basic-auth -o jsonpath="{.data.basic-auth-password}" | base64 --decode)" \
  "${OPENFAAS_URL}/system/functions" >/dev/null; then
  echo "[BOOTSTRAP] OpenFaaS reachable"
else
  echo "[BOOTSTRAP] OpenFaaS NOT reachable"
fi

# Validate CLI
echo "[BOOTSTRAP] Validating faas-cli..."

if faas-cli list >/dev/null 2>&1; then
  echo "[BOOTSTRAP] faas-cli OK"
  faas-cli list
else
  echo "[BOOTSTRAP] WARNING: faas-cli not authenticated or unreachable"
fi

# =============================================================================
# CLEANUP OLD PORT-FORWARDS
# =============================================================================

pkill -f "kubectl port-forward" || true
sleep 2

# =============================================================================
# KUBERNETES DASHBOARD
# =============================================================================

echo "[BOOTSTRAP] Starting Kubernetes Dashboard..."

DASH_PID=""

if kubectl get svc -n kubernetes-dashboard kubernetes-dashboard >/dev/null 2>&1; then
  kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8001:443 \
    > "$LOG_DIR/dashboard.log" 2>&1 &
  DASH_PID=$!
else
  echo "[WARN] Kubernetes Dashboard service not found"
fi

# =============================================================================
# PROMETHEUS
# =============================================================================

echo "[BOOTSTRAP] Starting Prometheus..."

kubectl port-forward -n openfaas svc/prometheus 9090:9090 \
  > "$LOG_DIR/prometheus.log" 2>&1 &
PROM_PID=$!

# =============================================================================
# GRAFANA
# =============================================================================

echo "[BOOTSTRAP] Starting Grafana..."

kubectl port-forward -n openfaas svc/grafana 3000:3000 \
  > "$LOG_DIR/grafana.log" 2>&1 &
GRAF_PID=$!

echo "[BOOTSTRAP] Services started"

# =============================================================================
# PROCESS MANAGEMENT
# =============================================================================

PIDS="$PROM_PID $GRAF_PID"

if [ -n "${DASH_PID}" ]; then
  PIDS="$PIDS $DASH_PID"
fi

wait $PIDS

# -----------------------------------------------------------------------------
# SAVE AND EXIT:
#   :wq
#
# MAKE EXECUTABLE:
#   sudo chmod +x /usr/local/bin/k8s-lab-bootstrap.sh
#
# RELOAD SERVICE (IF APPLICABLE):
sudo systemctl daemon-reload
sudo systemctl restart k8s-lab-bootstrap
# =============================================================================

# =============================================================================
# STEP 2A — OPENFAAS ACCESS ALIGNMENT (NODEPORT MODEL)
# =============================================================================
#
# PURPOSE
# -------
# Standardize OpenFaaS CLI + API access using Minikube NodePort.
#
# ARCHITECTURE
# -----------
# OpenFaaS is exposed via NodePort:
#   http://<minikube-ip>:31112
#
# =============================================================================

# -----------------------------------------------------------------------------
# Resolve Minikube IP and construct OpenFaaS endpoint
#Below steps were run and verified in the lab environment. 
#They are included here for completeness and reference, but may not be necessary to run again.
#Added to bootstrap script for auto-alignment on startup.
# -----------------------------------------------------------------------------

MINIKUBE_IP=$(minikube ip)
OPENFAAS_URL="http://${MINIKUBE_IP}:31112"

export OPENFAAS_URL="${OPENFAAS_URL}"

# Persist for future shell sessions (idempotent)
grep -q "OPENFAAS_URL" ~/.bashrc || \
echo "export OPENFAAS_URL=${OPENFAAS_URL}" >> ~/.bashrc

echo "[BOOTSTRAP] OpenFaaS URL set to: ${OPENFAAS_URL}"

# -----------------------------------------------------------------------------
# Validate OpenFaaS Gateway API
# -----------------------------------------------------------------------------

if curl -s "${OPENFAAS_URL}/system/functions" >/dev/null; then
  echo "[BOOTSTRAP] OpenFaaS reachable"
else
  echo "[BOOTSTRAP] OpenFaaS NOT reachable"
fi

# -----------------------------------------------------------------------------
# Validate CLI connectivity
# -----------------------------------------------------------------------------

echo "[BOOTSTRAP] Validating faas-cli access..."

if faas-cli list >/dev/null 2>&1; then
  echo "[BOOTSTRAP] faas-cli functional (authenticated + connected)"
  faas-cli list
else
  echo "[BOOTSTRAP] WARNING: faas-cli failed (check login or endpoint)"
fi

# =============================================================================
# STEP 3 — OPTIONAL SYSTEMD SERVICE (AUTO START BOOTSTRAP)
# =============================================================================
#
# FILE:
#   /etc/systemd/system/k8s-lab-bootstrap.service
#
# CREATE:
#   sudo vi /etc/systemd/system/k8s-lab-bootstrap.service
#
# CONTENT:
# -----------------------------------------------------------------------------

[Unit]
Description=Kubernetes Lab Bootstrap (Port Forward Manager)
After=minikube.service
Requires=minikube.service

[Service]
Type=simple
User=rideout421
ExecStart=/usr/local/bin/k8s-lab-bootstrap.sh

# 🔑 IMPORTANT: prevents silent restarts that kill port-forwards
KillMode=process
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target

# -----------------------------------------------------------------------------
# ENABLE:
#
#   sudo systemctl daemon-reload
#   sudo systemctl enable k8s-lab-bootstrap
#   sudo systemctl start k8s-lab-bootstrap
# =============================================================================


# =============================================================================
# STEP 4 — VALIDATION
# =============================================================================
#
# Check services:
#
#   systemctl status k8s-lab-bootstrap
#   ss -tulpn | grep -E '9090|3000|8001'
#
# Browser URLs:
#   http://127.0.0.1:9090
#   http://127.0.0.1:3000
#   http://127.0.0.1:8001
#
# =============================================================================
# END
# =============================================================================