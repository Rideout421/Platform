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