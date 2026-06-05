#!/usr/bin/env bash

# ==============================================================================
# OpenFaaSService.sh (LAB-GRADE VERSION)
# ==============================================================================
#
# PURPOSE
# -------
# Installs and configures OpenFaaS on Minikube using Helm
# and aligns CLI access to NodePort architecture.
#
# ARCHITECTURE (IMPORTANT)
# ------------------------
# This lab uses NodePort exposure:
#
# Minikube IP → 192.168.49.2
# OpenFaaS NodePort → 31112
#
# ACCESS URL:
# http://192.168.49.2:31112
#
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# COLORS
# ------------------------------------------------------------------------------

GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\e[34m"
RESET="\e[0m"

log() { echo -e "${BLUE}[INFO]${RESET} $1"; }
ok() { echo -e "${GREEN}[OK]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
fail() { echo -e "${RED}[ERROR]${RESET} $1"; }

# ------------------------------------------------------------------------------
# STEP 1 - DEPENDENCY CHECK
# ------------------------------------------------------------------------------

log "Checking dependencies..."

for cmd in kubectl helm minikube docker curl; do
    command -v $cmd >/dev/null 2>&1 && ok "$cmd found" || { fail "$cmd missing"; exit 1; }
done

# ------------------------------------------------------------------------------
# STEP 2 - MINIKUBE STATUS
# ------------------------------------------------------------------------------

log "Checking Minikube..."

minikube status >/dev/null 2>&1 && ok "Minikube running" || { fail "Start minikube"; exit 1; }

# ------------------------------------------------------------------------------
# STEP 3 - NAMESPACES
# ------------------------------------------------------------------------------

log "Applying OpenFaaS namespaces..."

kubectl apply -f https://raw.githubusercontent.com/openfaas/faas-netes/master/namespaces.yml

ok "Namespaces ready"

# ------------------------------------------------------------------------------
# STEP 4 - HELM REPO
# ------------------------------------------------------------------------------

log "Configuring Helm repo..."

helm repo add openfaas https://openfaas.github.io/faas-netes/ >/dev/null 2>&1 || true
helm repo update >/dev/null

ok "Helm updated"

# ------------------------------------------------------------------------------
# STEP 5 - INSTALL OPENFAAS
# ------------------------------------------------------------------------------

log "Installing OpenFaaS..."

helm upgrade openfaas openfaas/openfaas \
  --install \
  --namespace openfaas \
  --set functionNamespace=openfaas-fn \
  --set generateBasicAuth=true

ok "OpenFaaS installed"

# ------------------------------------------------------------------------------
# STEP 6 - WAIT FOR GATEWAY
# ------------------------------------------------------------------------------

log "Waiting for gateway..."

kubectl rollout status deployment/gateway -n openfaas --timeout=300s

ok "Gateway ready"

# ------------------------------------------------------------------------------
# STEP 7 - INSTALL CLI
# ------------------------------------------------------------------------------

if ! command -v faas-cli >/dev/null 2>&1; then
    log "Installing faas-cli..."
    curl -sSL https://cli.openfaas.com | sudo sh
fi

ok "faas-cli ready"

# ------------------------------------------------------------------------------
# STEP 8 - SET NODEPORT ACCESS (IMPORTANT FIX)
# ------------------------------------------------------------------------------

MINIKUBE_IP=$(minikube ip)
OPENFAAS_URL="http://${MINIKUBE_IP}:31112"

export OPENFAAS_URL=$OPENFAAS_URL
echo "export OPENFAAS_URL=$OPENFAAS_URL" >> ~/.bashrc

ok "OPENFAAS_URL set to $OPENFAAS_URL"

# ------------------------------------------------------------------------------
# STEP 9 - RETRIEVE PASSWORD
# ------------------------------------------------------------------------------

PASSWORD=$(kubectl get secret -n openfaas basic-auth \
  -o jsonpath="{.data.basic-auth-password}" | base64 --decode)

echo
echo "============================================================"
echo " OPENFAAS ACCESS"
echo "============================================================"
echo "URL:      $OPENFAAS_URL"
echo "Username: admin"
echo "Password: $PASSWORD"
echo "============================================================"

# ------------------------------------------------------------------------------
# STEP 10 - LOGIN AUTOMATION
# ------------------------------------------------------------------------------

echo "$PASSWORD" | faas-cli login --username admin --password-stdin >/dev/null

ok "Logged into OpenFaaS CLI"

# ------------------------------------------------------------------------------
# STEP 11 - VALIDATION (CORRECT ENDPOINT)
# ------------------------------------------------------------------------------

log "Validating gateway..."

curl -s "$OPENFAAS_URL/system/functions" >/dev/null && ok "Gateway reachable"

# ------------------------------------------------------------------------------
# STEP 12 - FINAL STATUS
# ------------------------------------------------------------------------------

echo
echo "============================================================"
echo " INSTALL COMPLETE"
echo "============================================================"

kubectl get pods -n openfaas
echo
kubectl get svc -n openfaas

echo
echo "NEXT STEP:"
echo "faas-cli store deploy figlet"
echo "echo hello | faas-cli invoke figlet"
echo
