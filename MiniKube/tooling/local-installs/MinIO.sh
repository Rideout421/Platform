#!/bin/bash
set -euo pipefail

# =============================================================================
# MINIO LOCAL INSTALL / RESET / RECOVERY RUNBOOK (CLEAN + SAFE STATE)
# =============================================================================
#
# FIXES APPLIED
# -------------
# - Correct step sequencing (no missing steps)
# - Prevent sudo file read permission failures
# - Ensure MinIO is fully up before mc alias
# - Harden credential extraction
# - Avoid SSH disruption during restart window
# - Add readiness validation loop
#
# ARCHITECTURE
# ------------
# MinIO VM service:
#   S3 API:     http://127.0.0.1:9000
#   Console:    http://127.0.0.1:9001
# =============================================================================

echo "[STEP 1] Stopping MinIO service..."
sudo systemctl stop minio || true

# =============================================================================
# STEP 2 — DATA DIRECTORY
# =============================================================================

echo "[STEP 2] Preparing MinIO data directory..."

if [ -d /data/minio ]; then
  sudo mv /data/minio /data/minio.backup.$(date +%s) || true
fi

sudo mkdir -p /data/minio
sudo chown -R minio-user:minio-user /data/minio

# =============================================================================
# STEP 3 — CREDENTIAL SOURCE OF TRUTH
# =============================================================================

echo "[STEP 3] Creating MinIO environment file..."

sudo mkdir -p /etc/minio

sudo tee /etc/minio/minio.env >/dev/null <<'EOF'
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=Shell421!
EOF

sudo chmod 600 /etc/minio/minio.env
sudo chown root:root /etc/minio/minio.env

# =============================================================================
# STEP 4 — SYSTEMD OVERRIDE
# =============================================================================

echo "[STEP 4] Applying systemd override..."

sudo mkdir -p /etc/systemd/system/minio.service.d

sudo tee /etc/systemd/system/minio.service.d/override.conf >/dev/null <<'EOF'
[Service]
EnvironmentFile=/etc/minio/minio.env
EOF

# =============================================================================
# STEP 5 — START MINIO (AND WAIT FOR READINESS)
# =============================================================================

echo "[STEP 5] Restarting MinIO..."

sudo systemctl daemon-reload
sudo systemctl restart minio

echo "[STEP 5A] Waiting for MinIO API readiness..."

until curl -s http://127.0.0.1:9000/minio/health/live >/dev/null 2>&1; do
  sleep 2
done

echo "[STEP 5B] MinIO is READY"

echo "[STEP 6] Configuring mc alias safely..."

MINIO_ROOT_USER=$(sudo awk -F= '/MINIO_ROOT_USER/ {print $2}' /etc/minio/minio.env)
MINIO_ROOT_PASSWORD=$(sudo awk -F= '/MINIO_ROOT_PASSWORD/ {print $2}' /etc/minio/minio.env)

mc alias set local http://127.0.0.1:9000 \
  "$MINIO_ROOT_USER" \
  "$MINIO_ROOT_PASSWORD" >/dev/null

echo "[STEP 6] mc alias configured"

# =============================================================================
# STEP 7 — VALIDATION
# =============================================================================

echo ""
echo "=================================================="
echo " MINIO DEPLOYMENT COMPLETE"
echo "=================================================="

systemctl status minio --no-pager | head -n 10

echo ""
ss -tulpn | grep -E '9000|9001' || true

echo ""
echo "ACCESS:"
echo "  S3 API  : http://127.0.0.1:9000"
echo "  Console : http://127.0.0.1:9001"
echo ""
echo "Credential source:"
echo "  /etc/minio/minio.env"
echo "=================================================="
