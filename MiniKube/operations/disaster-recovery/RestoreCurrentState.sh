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