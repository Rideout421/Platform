#!/bin/bash

# =============================================================================
# Minikube Auto-Start Service Setup
# =============================================================================
#
# PURPOSE
# -----------------------------------------------------------------------------
# This setup configures Minikube to automatically start after every VM reboot
# using a systemd service.
#
# Intended for:
#   - Ubuntu 24 LTS
#   - VMware VM environments
#   - Docker driver deployments
#   - Home lab Kubernetes clusters
#
# WHY THIS EXISTS
# -----------------------------------------------------------------------------
# By default, Minikube does NOT automatically start after reboot.
#
# Without automation:
#   - Kubernetes cluster remains stopped
#   - OpenFaaS and workloads remain unavailable
#   - Manual startup is required after every reboot
#
# This service solves that problem by:
#   - Waiting for networking to initialize
#   - Waiting for Docker to start
#   - Starting Minikube automatically
#
#
# IMPORTANT LESSONS LEARNED
# -----------------------------------------------------------------------------
# A previous implementation caused networking failures because:
#
#   - Minikube started too early during boot
#   - Docker networking initialized before DHCP completed
#   - NetworkManager was still configuring the interface
#
# Symptoms included:
#   - No IPv4 address on ens33
#   - "getting IP configuration" hangs
#   - Loss of SSH or MobaXterm connectivity
#
# To prevent this:
#
#   1. network-online.target is required
#   2. NetworkManager-wait-online.service is required
#   3. A startup delay is added
#   4. Correct Minikube binary path is required
#
#
# WHAT THIS SERVICE DOES
# -----------------------------------------------------------------------------
# Boot Sequence:
#
#   1. System boots
#   2. NetworkManager acquires DHCP lease
#   3. Docker service starts
#   4. Service waits 15 seconds
#   5. Minikube starts using Docker driver
#
#
# REQUIREMENTS
# -----------------------------------------------------------------------------
# These must already be installed:
#
#   - Docker
#   - Minikube
#   - NetworkManager
#
# Verify:
#
#   which minikube
#   docker --version
#   minikube version
#
#
# VERIFY MINIKUBE PATH
# -----------------------------------------------------------------------------
# IMPORTANT:
# The service MUST point to the actual Minikube binary location.
#
# Verify:
#
#   which minikube
#
# Expected:
#
#   /usr/local/bin/minikube
#
#
# CREATE SYSTEMD SERVICE FILE
# -----------------------------------------------------------------------------
# Create:
#
#   sudo vi /etc/systemd/system/minikube.service
#
# Paste the service configuration below.
#
#
# =============================================================================
# SYSTEMD SERVICE CONFIGURATION
# =============================================================================

cat <<EOF | sudo tee /etc/systemd/system/minikube.service

[Unit]
Description=Minikube Kubernetes Cluster
Documentation=https://minikube.sigs.k8s.io/docs/

Requires=docker.service network-online.target
After=docker.service network-online.target NetworkManager-wait-online.service

[Service]
Type=oneshot
RemainAfterExit=yes

User=rideout421
Group=rideout421

WorkingDirectory=/home/rideout421

ExecStartPre=/bin/sleep 15

ExecStart=/usr/local/bin/minikube start --driver=docker
ExecStop=/usr/local/bin/minikube stop

Environment="HOME=/home/rideout421"
Environment="CHANGE_MINIKUBE_NONE_USER=true"

TimeoutStartSec=900
TimeoutStopSec=300

[Install]
WantedBy=multi-user.target

EOF


# =============================================================================
# ENABLE AND START SERVICE
# =============================================================================
#
# Reload systemd after creating service file:
#
#   sudo systemctl daemon-reload
#
# Enable NetworkManager wait-online handling:
#
#   sudo systemctl enable NetworkManager-wait-online.service
#
# Enable Minikube auto-start at boot:
#
#   sudo systemctl enable minikube.service
#
# Start service immediately:
#
#   sudo systemctl start minikube.service
#
#
# =============================================================================
# VALIDATION STEPS
# =============================================================================
#
# Check service status:
#
#   systemctl status minikube --no-pager
#
# Check Kubernetes cluster:
#
#   minikube status
#
# Expected:
#
#   host: Running
#   kubelet: Running
#   apiserver: Running
#
#
# =============================================================================
# TROUBLESHOOTING
# =============================================================================
#
# SERVICE FAILS WITH:
#
#   status=203/EXEC
#
# Cause:
#   Incorrect Minikube binary path
#
# Fix:
#
#   which minikube
#
# Update ExecStart and ExecStop paths.
#
#
# NETWORK FAILS AFTER REBOOT
# -----------------------------------------------------------------------------
#
# Symptoms:
#
#   - No IPv4 on ens33
#   - "getting IP configuration"
#   - Cannot SSH into VM
#
# Verify:
#
#   nmcli device status
#   ip a show ens33
#
# Expected:
#
#   ens33 connected
#   inet 192.168.x.x
#
#
# MINIKUBE DOES NOT START
# -----------------------------------------------------------------------------
#
# Check logs:
#
#   journalctl -u minikube -b --no-pager
#
#
# RESTART SERVICE
# -----------------------------------------------------------------------------
#
#   sudo systemctl restart minikube
#
#
# STOP SERVICE
# -----------------------------------------------------------------------------
#
#   sudo systemctl stop minikube
#
#
# DISABLE AUTO START
# -----------------------------------------------------------------------------
#
#   sudo systemctl disable minikube
#
#
# REMOVE SERVICE COMPLETELY
# -----------------------------------------------------------------------------
#
#   sudo systemctl disable minikube
#   sudo rm -f /etc/systemd/system/minikube.service
#   sudo systemctl daemon-reload
#
#
# =============================================================================
# END OF FILE
# =============================================================================