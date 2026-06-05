#!/bin/bash
set -euo pipefail

# ==============================================================================
# LAB CONTROL PLANE BOOTSTRAP (CLEAN + SOURCE-OF-TRUTH SAFE VERSION)
# ==============================================================================

echo "[STEP 1] Creating system directories..."

sudo mkdir -p /etc/minio
sudo mkdir -p /etc/grafana
sudo mkdir -p /etc/lab-stack

# ==============================================================================
# STEP 2 - MINIO CONFIG (SOURCE OF TRUTH ONLY)
# ==============================================================================

echo "[STEP 2] Ensuring MinIO config exists..."

if [[ ! -f /etc/minio/minio.env ]]; then
  echo "[ERROR] Missing /etc/minio/minio.env"
  echo "        This file must be created by MinIO install script."
  exit 1
fi

sudo chmod 600 /etc/minio/minio.env
sudo chown root:root /etc/minio/minio.env

echo "[OK] MinIO config validated (no secrets modified)"

# ==============================================================================
# STEP 3 - GRAFANA CONFIG (SOURCE OF TRUTH ONLY)
# ==============================================================================

echo "[STEP 3] Ensuring Grafana config exists..."

if [[ ! -f /etc/grafana/grafana.env ]]; then
  echo "[ERROR] Missing /etc/grafana/grafana.env"
  echo "        This file must be created by Grafana install script."
  exit 1
fi

sudo chmod 600 /etc/grafana/grafana.env
sudo chown root:root /etc/grafana/grafana.env

echo "[OK] Grafana config validated (no secrets modified)"

# ==============================================================================
# STEP 4 - CREATE LAB STATE CONTRACT (SYSTEM INTENT ONLY)
# ==============================================================================

echo "[STEP 4] Creating lab state contract..."

sudo mkdir -p /etc/lab-stack

sudo tee /etc/lab-stack/lab-state.env >/dev/null <<EOF
PROMETHEUS_URL=http://127.0.0.1:9090
GRAFANA_URL=http://127.0.0.1:3000

MINIO_ALIAS=local
MINIO_BUCKET=local/lab-backups

MINIO_ENV=/etc/minio/minio.env
GRAFANA_ENV=/etc/grafana/grafana.env
EOF

sudo chmod 644 /etc/lab-stack/lab-state.env

echo "[STEP 4B] Lab state contract written successfully"

# ==============================================================================
# STEP 5 - VALIDATION (NON-DESTRUCTIVE + SAFE)
# ==============================================================================

echo "[STEP 5] Validating services..."

# Validate file presence only (NO sourcing)
if [[ -f /etc/minio/minio.env ]]; then
  echo "[OK] MinIO config present"
else
  echo "[ERROR] Missing /etc/minio/minio.env"
  exit 1
fi

if [[ -f /etc/grafana/grafana.env ]]; then
  echo "[OK] Grafana config present"
else
  echo "[ERROR] Missing /etc/grafana/grafana.env"
  exit 1
fi

# Safe Prometheus check (no shell dependency)
curl -s --max-time 3 http://127.0.0.1:9090/api/v1/query?query=up >/dev/null \
  && echo "[OK] Prometheus reachable" \
  || echo "[WARN] Prometheus not reachable"

echo "[STEP 5] Validation complete"
# =============================================================================
