#!/usr/bin/env bash

# ==============================================================================
# OpenTofu Installation Script
# ==============================================================================
#
# PURPOSE
# -------
# Installs OpenTofu using the official installer script provided by the
# OpenTofu project.
#
# ENVIRONMENT
# -----------
# Intended for:
# - Ubuntu/Debian lab environments
# - Kubernetes utility/control VM
# - Single-node infrastructure lab systems
#
# COMPONENTS ALREADY PRESENT IN LAB
# ---------------------------------
# - Kubernetes
# - MinIO
# - OpenFaaS
# - Prometheus
# - Grafana
#
# SECURITY NOTES
# --------------
# - Downloads installer directly from official OpenTofu source
# - Script is reviewed before execution
# - Uses standalone installation method
#
# OFFICIAL DOCUMENTATION
# ----------------------
# https://opentofu.org/docs/intro/install/
#
# ==============================================================================

set -euo pipefail

echo "============================================================"
echo "OpenTofu Installation Starting"
echo "============================================================"

# ------------------------------------------------------------------------------
# STEP 1 - DOWNLOAD INSTALLER
# ------------------------------------------------------------------------------
#
# Downloads the official OpenTofu installer script from:
# https://get.opentofu.org
#
# Flags:
# -f = Fail on HTTP errors
# -s = Silent mode
# -S = Show errors if they occur
# -L = Follow redirects
#
# ------------------------------------------------------------------------------

echo
echo "[STEP 1] Downloading OpenTofu installer..."

curl -fsSL https://get.opentofu.org/install-opentofu.sh \
    -o install-opentofu.sh

echo "[OK] Installer downloaded successfully."

# ------------------------------------------------------------------------------
# STEP 2 - APPLY EXECUTE PERMISSIONS
# ------------------------------------------------------------------------------
#
# Makes the installer executable.
#
# ------------------------------------------------------------------------------

echo
echo "[STEP 2] Setting execute permissions on installer..."

chmod +x install-opentofu.sh

echo "[OK] Execute permissions applied."

# ------------------------------------------------------------------------------
# STEP 3 - OPTIONAL SECURITY REVIEW
# ------------------------------------------------------------------------------
#
# Displays first section of installer for validation/review.
# Recommended before running external scripts.
#
# Remove or comment this section if fully automating.
#
# ------------------------------------------------------------------------------

echo
echo "[STEP 3] Displaying first 40 lines of installer for review..."
echo "------------------------------------------------------------"

head -n 40 install-opentofu.sh

echo "------------------------------------------------------------"

read -rp "Continue with installation? (y/n): " CONFIRM

if [[ "${CONFIRM}" != "y" ]]; then
    echo
    echo "[ABORTED] Installation cancelled by user."
    exit 1
fi

# ------------------------------------------------------------------------------
# STEP 4 - INSTALL OPENTOFU
# ------------------------------------------------------------------------------
#
# --install-method standalone
#
# Installs OpenTofu as a standalone binary on the system.
#
# ------------------------------------------------------------------------------

echo
echo "[STEP 4] Installing OpenTofu..."

./install-opentofu.sh --install-method standalone

echo
echo "[OK] OpenTofu installation completed."

# ------------------------------------------------------------------------------
# STEP 5 - VALIDATE INSTALLATION
# ------------------------------------------------------------------------------
#
# Confirms binary availability and version.
#
# ------------------------------------------------------------------------------

echo
echo "[STEP 5] Validating installation..."

if command -v tofu >/dev/null 2>&1; then
    echo "[OK] OpenTofu binary detected."

    echo
    echo "Installed Version:"
    tofu version
else
    echo "[ERROR] OpenTofu binary not found in PATH."
    exit 1
fi

# ------------------------------------------------------------------------------
# STEP 6 - CLEANUP (OPTIONAL)
# ------------------------------------------------------------------------------
#
# Removes installer after successful installation.
#
# Uncomment if desired.
#
# rm -f install-opentofu.sh
#
# ------------------------------------------------------------------------------

echo
echo "============================================================"
echo "OpenTofu installation completed successfully."
echo "============================================================"

echo
echo "Next Recommended Steps:"
echo " - Create Git repo for OpenTofu configs"
echo " - Configure MinIO S3 backend for remote state"
echo " - Install kubectl and Helm providers"
echo " - Validate with: tofu init"
echo