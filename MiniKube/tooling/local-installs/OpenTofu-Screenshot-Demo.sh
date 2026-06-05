#!/bin/bash
set -euo pipefail

# ==============================================================================
# OPENTOFU SCREENSHOT DEMO PIPELINE
# ==============================================================================
#
# PURPOSE
# -------
# Creates a clean OpenTofu demo environment for:
#
# - LinkedIn screenshots
# - Portfolio visuals
# - Infrastructure-as-Code demonstrations
#
# FEATURES
# --------
# - Creates persistent demo repo
# - Builds demo OpenTofu config
# - Initializes providers
# - Runs tofu plan
# - Displays Kubernetes status
# - Displays Helm releases
# - Adds syntax highlighting tools
#
# SAFE
# ----
# - Does NOT modify live infrastructure
# - Does NOT destroy resources
# - Uses random provider only
#
#Location:
#~/OpenTofu-Screenshot-Demo.sh
#
#Permissions update:
#chmod +x ~/OpenTofu-Screenshot-Demo.sh
#~/OpenTofu-Screenshot-Demo.sh
#
# ==============================================================================

echo
echo "=============================================================================="
echo "OPENTOFU SCREENSHOT DEMO PIPELINE"
echo "=============================================================================="
echo

# ==============================================================================
# INSTALL OPTIONAL VISUAL TOOLS
# ==============================================================================

echo "[INFO] Installing visual helper packages..."
sudo apt-get update -qq
sudo apt-get install -y tree bat lolcat >/dev/null 2>&1 || true

# ==============================================================================
# CREATE PERSISTENT LAB STRUCTURE
# ==============================================================================

LAB_DIR="$HOME/lab-infra/opentofu"

echo
echo "[INFO] Creating lab directory structure..."
mkdir -p "$LAB_DIR"

cd "$LAB_DIR"

# ==============================================================================
# CREATE DEMO OPENTOFU CONFIGURATION
# ==============================================================================

echo
echo "[INFO] Creating demo OpenTofu configuration..."

cat > main.tf <<'EOF'
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "random" {}

resource "random_pet" "cluster" {
  length = 2
}

resource "random_string" "token" {
  length  = 24
  special = false
}

output "cluster_name" {
  value = random_pet.cluster.id
}

output "generated_token" {
  value     = random_string.token.result
  sensitive = true
}
EOF

# ==============================================================================
# SHOW DIRECTORY STRUCTURE
# ==============================================================================

echo
echo "=============================================================================="
echo "DIRECTORY STRUCTURE"
echo "=============================================================================="
echo

tree "$HOME/lab-infra"

# ==============================================================================
# SHOW CONFIGURATION FILE
# ==============================================================================

echo
echo "=============================================================================="
echo "OPENTOFU CONFIGURATION"
echo "=============================================================================="
echo

if command -v batcat >/dev/null 2>&1; then
    batcat main.tf
elif command -v bat >/dev/null 2>&1; then
    bat main.tf
else
    cat main.tf
fi

# ==============================================================================
# INITIALIZE OPENTOFU
# ==============================================================================

echo
echo "=============================================================================="
echo "OPENTOFU INIT"
echo "=============================================================================="
echo

tofu init

# ==============================================================================
# RUN PLAN
# ==============================================================================

echo
echo "=============================================================================="
echo "OPENTOFU PLAN"
echo "=============================================================================="
echo

tofu plan

# ==============================================================================
# KUBERNETES STATUS
# ==============================================================================

echo
echo "=============================================================================="
echo "KUBERNETES POD STATUS"
echo "=============================================================================="
echo

kubectl get pods -A || true

# ==============================================================================
# HELM STATUS
# ==============================================================================

echo
echo "=============================================================================="
echo "HELM RELEASES"
echo "=============================================================================="
echo

helm list -A || true

# ==============================================================================
# FINAL OUTPUT
# ==============================================================================

echo
echo "=============================================================================="
echo "SCREENSHOT READY"
echo "=============================================================================="
echo
echo "[SUCCESS] OpenTofu demo environment created."
echo
echo "Recommended screenshot area:"
echo
echo "  - OpenTofu plan output"
echo "  - Kubernetes pod status"
echo "  - Helm releases"
echo
echo "Directory:"
echo "  $LAB_DIR"
echo