#!/usr/bin/env bash

# ==============================================================================
# Update.sh
# ==============================================================================
#
# PURPOSE
# -------
# Comprehensive maintenance and update script for:
#
# - Ubuntu 24.04 LTS
# - Docker
# - Minikube
# - Kubernetes tooling
# - Helm repositories
# - Snap packages
# - OpenTofu validation
# - MinIO validation
#
# ENVIRONMENT
# -----------
# Host VM:
#   - OpenTofu
#   - MinIO
#   - Docker
#   - Minikube
#
# Kubernetes Cluster:
#   - OpenFaaS
#   - Prometheus
#   - Grafana
#
# SECURITY / OPERATIONS
# ---------------------
# - Uses strict bash settings
# - Performs non-destructive validation checks
# - Does NOT automatically reboot
# - Safe for repeated execution
#
# USAGE
# -----
# chmod +x Update.sh
# ./Update.sh
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

# ------------------------------------------------------------------------------
# FUNCTIONS
# ------------------------------------------------------------------------------

log() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

success() {
    echo -e "${GREEN}[OK]${RESET} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${RESET} $1"
}

fail() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

# ------------------------------------------------------------------------------
# HEADER
# ------------------------------------------------------------------------------

echo
echo "============================================================"
echo " Ubuntu + Kubernetes Maintenance Script"
echo "============================================================"
echo

# ------------------------------------------------------------------------------
# STEP 1 - UPDATE PACKAGE INDEX
# ------------------------------------------------------------------------------

log "Updating APT package index..."

sudo apt update

success "APT package index updated."

# ------------------------------------------------------------------------------
# STEP 2 - STANDARD PACKAGE UPGRADES
# ------------------------------------------------------------------------------

log "Upgrading installed packages..."

sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y

success "Installed packages upgraded."

# ------------------------------------------------------------------------------
# STEP 3 - FULL DIST-UPGRADE
# ------------------------------------------------------------------------------

log "Running full-upgrade..."

sudo DEBIAN_FRONTEND=noninteractive apt full-upgrade -y

success "Full upgrade completed."

# ------------------------------------------------------------------------------
# STEP 4 - REMOVE UNUSED PACKAGES
# ------------------------------------------------------------------------------

log "Removing unused packages..."

sudo apt autoremove -y
sudo apt autoclean -y

success "Unused packages removed."

# ------------------------------------------------------------------------------
# STEP 5 - REFRESH SNAP PACKAGES
# ------------------------------------------------------------------------------

if command -v snap >/dev/null 2>&1; then
    log "Refreshing snap packages..."

    sudo snap refresh

    success "Snap packages refreshed."
else
    warn "Snap not installed. Skipping."
fi

# ------------------------------------------------------------------------------
# STEP 6 - UPDATE HELM REPOSITORIES
# ------------------------------------------------------------------------------

if command -v helm >/dev/null 2>&1; then
    log "Updating Helm repositories..."

    helm repo update

    success "Helm repositories updated."
else
    warn "Helm not installed. Skipping."
fi

# ------------------------------------------------------------------------------
# STEP 7 - VALIDATE DOCKER
# ------------------------------------------------------------------------------

if systemctl is-active --quiet docker; then
    success "Docker service is running."
else
    warn "Docker service is NOT running."
fi

# ------------------------------------------------------------------------------
# STEP 8 - VALIDATE MINIO
# ------------------------------------------------------------------------------

if systemctl is-active --quiet minio; then
    success "MinIO service is running."
else
    warn "MinIO service is NOT running."
fi

# ------------------------------------------------------------------------------
# STEP 9 - VALIDATE MINIKUBE
# ------------------------------------------------------------------------------

if command -v minikube >/dev/null 2>&1; then

    log "Checking Minikube status..."

    minikube status || true

    success "Minikube validation completed."

else
    warn "Minikube not installed."
fi

# ------------------------------------------------------------------------------
# STEP 10 - VALIDATE KUBERNETES
# ------------------------------------------------------------------------------

if command -v kubectl >/dev/null 2>&1; then

    log "Checking Kubernetes nodes..."

    kubectl get nodes || true

    echo

    log "Checking Kubernetes pods..."

    kubectl get pods -A || true

    success "Kubernetes validation completed."

else
    warn "kubectl not installed."
fi

# ------------------------------------------------------------------------------
# STEP 11 - VALIDATE OPENTOFU
# ------------------------------------------------------------------------------

if command -v tofu >/dev/null 2>&1; then

    log "Checking OpenTofu version..."

    tofu version

    success "OpenTofu validation completed."

else
    warn "OpenTofu not installed."
fi

# ------------------------------------------------------------------------------
# STEP 12 - SYSTEM HEALTH CHECKS
# ------------------------------------------------------------------------------

echo
echo "============================================================"
echo " SYSTEM HEALTH"
echo "============================================================"

echo
log "Kernel Version:"
uname -r

echo
log "Disk Usage:"
df -h

echo
log "Memory Usage:"
free -h

echo
log "Failed Services:"
systemctl --failed || true

# ------------------------------------------------------------------------------
# STEP 13 - REBOOT CHECK
# ------------------------------------------------------------------------------

echo
echo "============================================================"
echo " REBOOT STATUS"
echo "============================================================"

if [ -f /var/run/reboot-required ]; then

    warn "System reboot is REQUIRED."

    echo
    cat /var/run/reboot-required.pkgs || true

else

    success "No reboot required."

fi

# ------------------------------------------------------------------------------
# FOOTER
# ------------------------------------------------------------------------------

echo
echo "============================================================"
echo " Maintenance Completed Successfully"
echo "============================================================"
echo