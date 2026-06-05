#!/bin/bash
set -euo pipefail

# ==============================================================================
# AUTOMATE BACKUP + RECOVERY CONTROL PLANE (INSTALL ONLY)
# ==============================================================================
# PURPOSE:
# - Install backup/restore scripts ONCE
# - No cron (event-driven model)
# - Safe re-runnable installer
# ==============================================================================

BACKUP_SCRIPT="/usr/local/bin/BackupCurrentState.sh"
RESTORE_SCRIPT="/usr/local/bin/RestoreCurrentState.sh"

echo "[STEP 1] Installing BackupCurrentState.sh..."

sudo tee "$BACKUP_SCRIPT" >/dev/null <<'BACKUP_EOF'
#!/bin/bash
set -euo pipefail

# =============================================================================
# LAB PIPELINE SCRIPT LOCATION MAP
# =============================================================================
#BACKUP_SCRIPT="/usr/local/bin/BackupCurrentState.sh"
#RESTORE_SCRIPT="/usr/local/bin/RestoreCurrentState.sh"
# =============================================================================
# EXECUTION NOTES
# =============================================================================
# Run without sudo (required for mc + kubeconfig context consistency)
# =============================================================================
# FULL LAB BACKUP PIPELINE
# ==============================================================================

TIMESTAMP=$(date +%F-%H%M%S)
WORKDIR="/tmp/lab-backup-$TIMESTAMP"
ARCHIVE="/tmp/full-lab-backup-$TIMESTAMP.tar.gz"
BUCKET="local/lab-backups"
GRAFANA_URL="http://192.168.49.2:31300"

mkdir -p "$WORKDIR"

echo "=================================================="
echo " FULL LAB BACKUP STARTING - $TIMESTAMP"
echo "=================================================="

cleanup() {
    echo "[CLEANUP] Removing temporary files..."
    rm -rf "$WORKDIR" 2>/dev/null || true
}
trap cleanup EXIT

# ==============================================================================
# STEP 1 - ENVIRONMENT
# ==============================================================================

echo "[STEP 1] Loading environment..."
mkdir -p "$WORKDIR/secrets"

for envfile in /etc/minio/minio.env /etc/grafana/grafana.env; do
    if [[ -f "$envfile" ]]; then
        sudo cp "$envfile" "$WORKDIR/secrets/$(basename "$envfile")" || true
        sudo chown "$USER:$USER" "$WORKDIR/secrets/$(basename "$envfile")" || true
        chmod 600 "$WORKDIR/secrets/$(basename "$envfile")" || true
    fi
done

if [[ -f /etc/grafana/grafana.env ]]; then
    GF_SECURITY_ADMIN_USER=$(sudo grep -E '^GF_SECURITY_ADMIN_USER=' /etc/grafana/grafana.env | cut -d'=' -f2- | tr -d '"')
    GF_SECURITY_ADMIN_PASSWORD=$(sudo grep -E '^GF_SECURITY_ADMIN_PASSWORD=' /etc/grafana/grafana.env | cut -d'=' -f2- | tr -d '"')
    echo "[OK] Grafana credentials loaded"
fi

echo "[OK] Environment loaded"

# ==============================================================================
# STEPS 2-4
# ==============================================================================

echo "[STEP 2] Capturing OpenTofu state..."
mkdir -p "$WORKDIR/tofu"
cp *.tf terraform.tfstate* "$WORKDIR/tofu/" 2>/dev/null || true

echo "[STEP 3] Exporting Kubernetes state..."
mkdir -p "$WORKDIR/k8s"
kubectl get nodes -o yaml > "$WORKDIR/k8s/nodes.yaml" || true
kubectl get all -A -o yaml > "$WORKDIR/k8s/all-resources.yaml" || true
kubectl get pvc,pv -A -o yaml > "$WORKDIR/k8s/storage.yaml" || true

kubectl get all -n openfaas -o yaml > "$WORKDIR/k8s/openfaas.yaml" || true
kubectl get all -n openfaas-fn -o yaml > "$WORKDIR/k8s/openfaas-fn.yaml" || true

echo "[STEP 4] Capturing OpenFaaS state..."
mkdir -p "$WORKDIR/openfaas"
faas-cli list -n openfaas > "$WORKDIR/openfaas/functions.txt" 2>/dev/null || true

# ==============================================================================
# STEP 5 - GRAFANA
# ==============================================================================

echo "[STEP 5] Exporting Grafana..."
mkdir -p "$WORKDIR/grafana/dashboards"

if [[ -n "${GF_SECURITY_ADMIN_USER:-}" && -n "${GF_SECURITY_ADMIN_PASSWORD:-}" ]]; then
    echo "[INFO] Testing Grafana API..."
    curl -s --max-time 10 -u "$GF_SECURITY_ADMIN_USER:$GF_SECURITY_ADMIN_PASSWORD" \
      "$GRAFANA_URL/api/health" > /dev/null && echo "[OK] Grafana API reachable" || echo "[WARN] Grafana API not responding"

    echo "[INFO] Exporting datasources..."
    curl -s --max-time 15 -u "$GF_SECURITY_ADMIN_USER:$GF_SECURITY_ADMIN_PASSWORD" \
      "$GRAFANA_URL/api/datasources" > "$WORKDIR/grafana/datasources.json"

    echo "[INFO] Exporting dashboards..."
    curl -s --max-time 15 -u "$GF_SECURITY_ADMIN_USER:$GF_SECURITY_ADMIN_PASSWORD" \
      "$GRAFANA_URL/api/search" > "$WORKDIR/grafana/dashboard-search.json"

    DASH_UIDS=$(jq -r '.[] | select(.uid != null) | .uid' "$WORKDIR/grafana/dashboard-search.json" 2>/dev/null || echo "")

    echo "[INFO] Found $(echo "$DASH_UIDS" | wc -w) dashboard(s)"

    for uid in $DASH_UIDS; do
        echo "   → Exporting dashboard: $uid"
        curl -s --max-time 15 -u "$GF_SECURITY_ADMIN_USER:$GF_SECURITY_ADMIN_PASSWORD" \
          "$GRAFANA_URL/api/dashboards/uid/$uid" > "$WORKDIR/grafana/dashboards/$uid.json" || true
    done

    # Backup database
    echo "[INFO] Copying Grafana database..."
    GRAFANA_POD=$(kubectl get pod -n openfaas -l app=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$GRAFANA_POD" ]]; then
        kubectl cp "openfaas/$GRAFANA_POD:/var/lib/grafana/grafana.db" \
          "$WORKDIR/grafana/grafana.db" 2>/dev/null || echo "[WARN] Grafana DB copy failed"
    fi
else
    echo "[WARN] Grafana credentials not found"
fi

# ==============================================================================
# STEP 6 - PROMETHEUS
# ==============================================================================

echo "[STEP 6] Capturing Prometheus state..."
mkdir -p "$WORKDIR/prometheus"

PROM_POD=$(kubectl get pod -n openfaas -l app=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "$PROM_POD" ]]; then
    curl -s --max-time 10 "http://127.0.0.1:9090/api/v1/query?query=up" > "$WORKDIR/prometheus/up.json" || true

    echo "[INFO] Creating Prometheus TSDB snapshot..."
    SNAPSHOT_RESPONSE=$(curl -s --max-time 25 -X POST http://127.0.0.1:9090/api/v1/admin/tsdb/snapshot)
    echo "$SNAPSHOT_RESPONSE" > "$WORKDIR/prometheus/tsdb-snapshot-response.json"

    SNAPSHOT_NAME=$(echo "$SNAPSHOT_RESPONSE" | jq -r '.data.name // empty')
    if [[ -n "$SNAPSHOT_NAME" ]]; then
        echo "[INFO] Snapshot created: $SNAPSHOT_NAME"
        mkdir -p "$WORKDIR/prometheus/snapshot"
        kubectl cp "openfaas/$PROM_POD:/prometheus/snapshots/$SNAPSHOT_NAME" \
          "$WORKDIR/prometheus/snapshot/" 2>/dev/null || echo "[WARN] Snapshot copy skipped"
    fi
fi

# ==============================================================================
# FINAL STEPS
# ==============================================================================

echo "[STEP 7] MinIO inventory..."
mkdir -p "$WORKDIR/minio"
mc ls --recursive local > "$WORKDIR/minio/minio-inventory.txt" 2>/dev/null || true

echo "[STEP 8] System state..."
mkdir -p "$WORKDIR/system"
uname -a > "$WORKDIR/system/uname.txt"
df -h > "$WORKDIR/system/disk-usage.txt"
kubectl version > "$WORKDIR/system/kubectl-version.txt"
minikube status > "$WORKDIR/system/minikube-status.txt"

echo "[STEP 9] Creating archive..."
tar -czf "$ARCHIVE" -C "$WORKDIR" .

echo "[STEP 10] Uploading to MinIO..."
mc cp "$ARCHIVE" "$BUCKET/"

echo "[STEP 11] Retention (keep latest 3)..."
mc ls "$BUCKET/" --recursive | awk '{print $NF}' | grep '^full-lab-backup-' | sort -r > /tmp/backups_sorted.txt 2>/dev/null || true
COUNT=$(wc -l < /tmp/backups_sorted.txt 2>/dev/null || echo 0)
if [[ $COUNT -gt 3 ]]; then
    echo "Removing $((COUNT-3)) old backups..."
    tail -n +4 /tmp/backups_sorted.txt | while read -r file; do
        [[ -n "$file" ]] && mc rm "$BUCKET/$file"
    done
fi
rm -f /tmp/backups_sorted.txt

echo ""
echo "=================================================="
echo " FULL LAB BACKUP COMPLETE"
echo "=================================================="
echo "Archive: $ARCHIVE"
echo "Saved to: $BUCKET"
echo "=================================================="
BACKUP_EOF

sudo chmod +x "$BACKUP_SCRIPT"

# ------------------------------------------------------------------------------

echo "[STEP 2] Installing RestoreCurrentState.sh..."

sudo tee "$RESTORE_SCRIPT" >/dev/null <<'RESTORE_EOF'
#!/bin/bash

# =============================================================================
# LAB RESTORE PIPELINE
# =============================================================================
# MODES
# -----------------------------------------------------------------------------
# DRY RUN (default)
#   ./RestoreCurrentState.sh
#
# APPLY KUBERNETES RESTORE
#   ENABLE_APPLY=true ./RestoreCurrentState.sh
#
# OPENFAAS RESTORE + VALIDATION
#   ENABLE_OPENFAAS_RESTORE=true ./RestoreCurrentState.sh
#
# FULL RESTORE
#   ENABLE_APPLY=true ENABLE_OPENFAAS_RESTORE=true ./RestoreCurrentState.sh
# =============================================================================
# LAB PIPELINE SCRIPT LOCATION MAP
# =============================================================================
#BACKUP_SCRIPT="/usr/local/bin/BackupCurrentState.sh"
#RESTORE_SCRIPT="/usr/local/bin/RestoreCurrentState.sh"
# =============================================================================
# EXECUTION NOTES
# =============================================================================
# Run without sudo (required for mc + kubeconfig context consistency)
# =============================================================================

BUCKET="local/lab-backups"
WORKDIR="/tmp/lab-restore"
ARCHIVE="/tmp/lab-backup.tar.gz"

ENABLE_APPLY="${ENABLE_APPLY:-false}"
ENABLE_OPENFAAS_RESTORE="${ENABLE_OPENFAAS_RESTORE:-false}"

echo "[STEP 1] Locating latest backup in MinIO..."

LATEST=$(mc ls "$BUCKET" 2>/dev/null | grep tar.gz | sort | tail -n 1 | awk '{print $NF}')

if [ -z "$LATEST" ]; then
  echo "[ERROR] No backup found in $BUCKET"
  exit 1
fi

echo "[INFO] Backup selected: $LATEST"

# =============================================================================
# DOWNLOAD BACKUP
# =============================================================================

echo "[STEP 2] Downloading backup..."
rm -f "$ARCHIVE"

mc cp "$BUCKET/$LATEST" "$ARCHIVE" >/dev/null 2>&1 || {
  echo "[ERROR] MinIO download failed"
  exit 1
}

# =============================================================================
# EXTRACT BACKUP
# =============================================================================

echo "[STEP 3] Extracting archive..."
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

tar -xzf "$ARCHIVE" -C "$WORKDIR" >/dev/null 2>&1 || {
  echo "[ERROR] Failed to extract backup archive"
  exit 1
}

echo "[STEP 4] Backup contents:"
find "$WORKDIR" -type f | sort

# =============================================================================
# TOFU RESTORE
# =============================================================================

echo "[STEP 5] OpenTofu restore (local only)..."

if [ -d "$WORKDIR/tofu" ]; then
  cp -f "$WORKDIR/tofu/"* . 2>/dev/null || true
  echo "[OK] OpenTofu state restored"
else
  echo "[WARN] No OpenTofu state found"
fi

# =============================================================================
# KUBERNETES RESTORE
# =============================================================================

echo "[STEP 6] Kubernetes restore phase..."

if [ "$ENABLE_APPLY" = "true" ]; then

  echo "[APPLY] Applying Kubernetes manifests..."

  FILES=(
    "configmaps.yaml"
    "services.yaml"
    "pv.yaml"
    "pvc.yaml"
    "openfaas.yaml"
    "openfaas-fn.yaml"
  )

  for f in "${FILES[@]}"; do
    if [ -f "$WORKDIR/k8s/$f" ]; then
      kubectl apply -f "$WORKDIR/k8s/$f" --validate=false >/dev/null 2>&1 || true
    fi
  done

  echo "[OK] Kubernetes restore applied"
else
  echo "[DRY-RUN] Kubernetes restore skipped"
fi

# =============================================================================
# PERSISTENT VOLUME PATCH (PROMETHEUS)
# =============================================================================

echo "[STEP 6b] Ensuring Prometheus PVC patch is applied..."

PROM_VOL=$(kubectl get deployment prometheus -n openfaas \
  -o jsonpath='{.spec.template.spec.volumes[1].persistentVolumeClaim.claimName}' 2>/dev/null || true)

if [ "$PROM_VOL" != "prometheus-data" ]; then
  echo "[PATCH] Prometheus still using EmptyDir — reapplying PVC patch..."
  kubectl patch deployment prometheus -n openfaas --type=json -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/volumes/1",
      "value": {
        "name": "prom-data",
        "persistentVolumeClaim": {
          "claimName": "prometheus-data"
        }
      }
    }
  ]' && echo "[OK] Prometheus PVC patch applied" || echo "[WARN] Prometheus patch failed"
else
  echo "[OK] Prometheus PVC already correct"
fi

# =============================================================================
# OPENFAAS RESTORE
# =============================================================================

echo "[STEP 7] OpenFaaS restore/validation..."

GATEWAY_PORT=$(kubectl get svc gateway-external -n openfaas \
  -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || true)

# Use minikube ip instead of 127.0.0.1 for NodePort reachability
MINIKUBE_IP=$(minikube ip 2>/dev/null || true)

if [ -n "$GATEWAY_PORT" ] && [ -n "$MINIKUBE_IP" ]; then
  GATEWAY="http://${MINIKUBE_IP}:${GATEWAY_PORT}"
  echo "[INFO] OpenFaaS gateway: $GATEWAY"
elif [ -n "$GATEWAY_PORT" ]; then
  echo "[WARN] minikube ip failed, falling back to 127.0.0.1"
  GATEWAY="http://127.0.0.1:${GATEWAY_PORT}"
else
  echo "[WARN] OpenFaaS gateway not found"
  GATEWAY=""
fi

if [ "$ENABLE_OPENFAAS_RESTORE" = "true" ]; then

  export OPENFAAS_URL="$GATEWAY"

  echo "[INFO] Restoring OpenFaaS functions into namespace openfaas-fn..."

  if [ -f "$WORKDIR/openfaas/function-deployments.yaml" ]; then
    kubectl apply -n openfaas-fn -f "$WORKDIR/openfaas/function-deployments.yaml" >/dev/null 2>&1 || true
  fi

  if [ -f "$WORKDIR/openfaas/function-services.yaml" ]; then
    kubectl apply -n openfaas-fn -f "$WORKDIR/openfaas/function-services.yaml" >/dev/null 2>&1 || true
  fi

  echo "[OK] OpenFaaS restore completed"

else
  echo "[SKIP] OpenFaaS restore disabled"
fi

# =============================================================================
# OPENFAAS VALIDATION
# =============================================================================

if [ -n "$GATEWAY" ]; then
  echo "[STEP 8] OpenFaaS validation (safe check)..."

  for i in 1 2 3 4 5; do
    curl -s "$GATEWAY/system/functions" >/dev/null 2>&1 && break
    echo "[WAIT] Gateway not ready ($i/5)"
    sleep 2
  done

  if command -v faas-cli >/dev/null 2>&1; then
    echo "[INFO] Listing functions (correct namespace: openfaas-fn)"

    faas-cli list \
      --gateway "$GATEWAY" \
      -n openfaas-fn \
      >/dev/null 2>&1 || echo "[WARN] faas-cli validation failed (non-critical)"
  fi
else
  echo "[SKIP] OpenFaaS validation (no gateway)"
fi

# =============================================================================
# PROMETHEUS SNAPSHOT
# =============================================================================

echo "[STEP 9] Prometheus snapshot..."

if [ -f "$WORKDIR/prometheus/up.json" ]; then
  cat "$WORKDIR/prometheus/up.json"
  echo ""
else
  echo "[WARN] No Prometheus snapshot found"
fi

# =============================================================================
# CLEANUP
# =============================================================================

echo "[STEP 10] Cleanup..."

rm -rf "$WORKDIR" 2>/dev/null
rm -f "$ARCHIVE" 2>/dev/null

echo ""
echo "=================================================="
echo " RESTORE COMPLETE"
echo "=================================================="
echo "Backup  : $LATEST"
echo "K8s     : $ENABLE_APPLY"
echo "OpenFaaS: $ENABLE_OPENFAAS_RESTORE"
echo "=================================================="
RESTORE_EOF

sudo chmod +x "$RESTORE_SCRIPT"

# ------------------------------------------------------------------------------

echo "[STEP 3] Validation..."

if [[ -x /usr/local/bin/BackupCurrentState.sh ]]; then
  echo "[OK] Backup script installed"
fi

if [[ -x /usr/local/bin/RestoreCurrentState.sh ]]; then
  echo "[OK] Restore script installed"
fi

# Syntax check both scripts
bash -n /usr/local/bin/BackupCurrentState.sh  && echo "[OK] BackupCurrentState.sh syntax valid"
bash -n /usr/local/bin/RestoreCurrentState.sh && echo "[OK] RestoreCurrentState.sh syntax valid"

echo ""
echo "=================================================="
echo " CONTROL PLANE INSTALL COMPLETE"
echo "=================================================="
echo "Backup script  : /usr/local/bin/BackupCurrentState.sh"
echo "Restore script : /usr/local/bin/RestoreCurrentState.sh"
echo "=================================================="
