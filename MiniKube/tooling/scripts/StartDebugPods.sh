#!/bin/bash

set -euo pipefail

# ==============================================================================
# KUBERNETES DEBUG POD STARTUP
# ==============================================================================

echo "=============================================================================="
echo "VALIDATING CLUSTER"
echo "=============================================================================="

kubectl get nodes

echo
echo "=============================================================================="
echo "REMOVING OLD DEBUG PODS"
echo "=============================================================================="

kubectl delete pod debug --ignore-not-found=true
kubectl delete pod busybox --ignore-not-found=true

echo
echo "=============================================================================="
echo "CREATING NETSHOOT DEBUG POD"
echo "=============================================================================="

kubectl run debug \
  --image=nicolaka/netshoot \
  --restart=Never \
  --command -- sleep infinity

echo
echo "=============================================================================="
echo "CREATING BUSYBOX POD"
echo "=============================================================================="

kubectl run busybox \
  --image=busybox \
  --restart=Never \
  --command -- sleep infinity

echo
echo "=============================================================================="
echo "WAITING FOR PODS TO START"
echo "=============================================================================="

kubectl wait --for=condition=Ready pod/debug --timeout=120s
kubectl wait --for=condition=Ready pod/busybox --timeout=120s

echo
echo "=============================================================================="
echo "FINAL POD STATUS"
echo "=============================================================================="

kubectl get pods -o wide

echo
echo "=============================================================================="
echo "ACCESS COMMANDS"
echo "=============================================================================="

echo "Netshoot:"
echo "kubectl exec -it debug -- /bin/bash"

echo
echo "BusyBox:"
echo "kubectl exec -it busybox -- /bin/sh"

echo
echo "=============================================================================="
echo "DEBUG ENVIRONMENT READY"
echo "=============================================================================="