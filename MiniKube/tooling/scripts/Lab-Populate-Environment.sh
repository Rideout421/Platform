#!/usr/bin/env bash

# ==============================================================================
# Lab-Populate-Environment.sh
# ==============================================================================
#
# PURPOSE
# -------
# Guided lab walkthrough for populating the Kubernetes and infrastructure
# environment with workloads, metrics, objects, and functions.
#
# THIS FILE IS A LEARNING GUIDE
# -----------------------------
# This file is NOT intended to be executed directly.
#
# Instead:
# - Read each section
# - Run commands manually
# - Observe platform behavior
# - Learn relationships between components
#
# ENVIRONMENT
# -----------
# Host VM:
# - OpenTofu
# - MinIO
# - Docker
# - Minikube
#
# Kubernetes:
# - OpenFaaS
# - Prometheus
# - Grafana
#
# LEARNING OBJECTIVES
# -------------------
# - Kubernetes Deployments
# - Kubernetes Services
# - Pod Monitoring
# - Prometheus Metrics
# - Grafana Dashboards
# - OpenFaaS Functions
# - MinIO Object Storage
# - Infrastructure Visibility
#
# ==============================================================================



# ==============================================================================
# SECTION 1 - VERIFY CLUSTER STATUS
# ==============================================================================
#
# PURPOSE
# -------
# Verify Kubernetes cluster and nodes are operational before deploying
# workloads.
#
# WHAT YOU LEARN
# --------------
# - Cluster health validation
# - Kubernetes node visibility
# - Namespace inspection
#
# ------------------------------------------------------------------------------

# Check Minikube status
minikube status

# View Kubernetes nodes
kubectl get nodes

# View all namespaces
kubectl get namespaces

# View all running pods
kubectl get pods -A

# --- Output ---
# rideout421@Ubuntu-24-LTS:~$ minikube status
# minikube
# type: Control Plane
# host: Running
# kubelet: Running
# apiserver: Running
# kubeconfig: Configured
#
# rideout421@Ubuntu-24-LTS:~$ kubectl get nodes
# NAME       STATUS   ROLES           AGE    VERSION
# minikube   Ready    control-plane   4d1h   v1.35.1
#
# rideout421@Ubuntu-24-LTS:~$ kubectl get namespaces
# NAME                   STATUS   AGE
# default                Active   4d1h
# kube-node-lease        Active   4d1h
# kube-public            Active   4d1h
# kube-system            Active   4d1h
# kubernetes-dashboard   Active   22h
# openfaas               Active   4d1h
# openfaas-fn            Active   4d1h
#
# rideout421@Ubuntu-24-LTS:~$ kubectl get pods -A
# NAMESPACE              NAME                                        READY   STATUS    RESTARTS        AGE
# kube-system            coredns-7d764666f9-ps7s8                    1/1     Running   11 (143m ago)   4d1h
# kube-system            etcd-minikube                               1/1     Running   11 (143m ago)   4d1h
# kube-system            kube-apiserver-minikube                     1/1     Running   11 (143m ago)   4d1h
# kube-system            kube-controller-manager-minikube            1/1     Running   11 (143m ago)   4d1h
# kube-system            kube-proxy-2pfn2                            1/1     Running   11 (143m ago)   4d1h
# kube-system            kube-scheduler-minikube                     1/1     Running   11 (143m ago)   4d1h
# kube-system            storage-provisioner                         1/1     Running   23 (142m ago)   4d1h
# kubernetes-dashboard   dashboard-metrics-scraper-8d46b45f6-jl6xv   1/1     Running   4 (143m ago)    22h
# kubernetes-dashboard   kubernetes-dashboard-b44857bbb-795lc        1/1     Running   6 (143m ago)    22h
# openfaas-fn            figlet-7868f849bd-pvh6x                     1/1     Running   10 (143m ago)   37h
# openfaas-fn            nodeinfo-7b6c6b467b-4z7jr                   1/1     Running   11 (143m ago)   4d
# openfaas               alertmanager-684f4899cb-4nxqg               1/1     Running   10 (143m ago)   37h
# openfaas               gateway-76bb649c89-wfxgk                    2/2     Running   55 (142m ago)   37h
# openfaas               grafana                                     1/1     Running   2 (143m ago)    19h
# openfaas               nats-7cc5c654cf-nxk2g                       1/1     Running   10 (143m ago)   37h
# openfaas               prometheus-7fbcf5bfb5-hddbh                 1/1     Running   10 (143m ago)   37h
# openfaas               queue-worker-5df9c968d8-z7gsk               1/1     Running   2



# ==============================================================================
# SECTION 2 - DEPLOY NGINX WEB SERVER
# ==============================================================================
#
# PURPOSE
# -------
# Deploy a simple NGINX web server into Kubernetes.
#
# WHAT YOU LEARN
# --------------
# - Kubernetes deployments
# - Kubernetes services
# - NodePort networking
# - Pod lifecycle
#
# WHAT YOU WILL SEE
# -----------------
# - Pods appear in Kubernetes Dashboard
# - Metrics generated in Prometheus
# - Traffic visualized in Grafana
#
# ------------------------------------------------------------------------------

# Create NGINX deployment
kubectl create deployment nginx --image=nginx

# Expose deployment as NodePort service
kubectl expose deployment nginx \
  --type=NodePort \
  --port=80

# Verify deployment
kubectl get deployments

# Verify pods
kubectl get pods

# Verify services
kubectl get svc

# --- Output ---
# rideout421@Ubuntu-24-LTS:~$ kubectl create deployment nginx --image=nginx
# deployment.apps/nginx created
#
# rideout421@Ubuntu-24-LTS:~$ kubectl expose deployment nginx --type=NodePort --port=80
# service/nginx exposed
#
# rideout421@Ubuntu-24-LTS:~$ kubectl get deployments
# NAME    READY   UP-TO-DATE   AVAILABLE   AGE
# nginx   1/1     1            1           16s
#
# rideout421@Ubuntu-24-LTS:~$ kubectl get pods
# NAME                     READY   STATUS    RESTARTS   AGE
# nginx-56c45fd5ff-28586   1/1     Running   0          24s
#
# rideout421@Ubuntu-24-LTS:~$ kubectl get svc
# NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
# kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP        4d1h
# nginx        NodePort    10.107.156.149   <none>        80:30425/TCP   22s



# ==============================================================================
# SECTION 3 - DEPLOY APACHE WEB SERVER
# ==============================================================================
#
# PURPOSE
# -------
# Deploy Apache HTTP server as a second workload.
#
# WHAT YOU LEARN
# --------------
# - Multiple workloads in Kubernetes
# - Service exposure
# - Workload separation
#
# ------------------------------------------------------------------------------

# Create Apache deployment
kubectl create deployment apache --image=httpd

# Expose Apache service
kubectl expose deployment apache \
  --type=NodePort \
  --port=80

# Validate deployment
kubectl get deployments

# Validate services
kubectl get svc

# --- Output ---
# rideout421@Ubuntu-24-LTS:~$ kubectl create deployment apache --image=httpd
# deployment.apps/apache created
#
# rideout421@Ubuntu-24-LTS:~$ kubectl expose deployment apache --type=NodePort --port=80
# service/apache exposed
#
# rideout421@Ubuntu-24-LTS:~$ kubectl get deployments
# NAME     READY   UP-TO-DATE   AVAILABLE   AGE
# apache   0/1     1            0           14s
# nginx    1/1     1            1           105s
#
# rideout421@Ubuntu-24-LTS:~$ kubectl get svc
# NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
# apache       NodePort    10.97.116.200    <none>        80:31764/TCP   14s
# kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP        4d1h
# nginx        NodePort    10.107.156.149   <none>        80:30425/TCP   103s



# ==============================================================================
# SECTION 4 - DEPLOY BUSYBOX TEST POD
# ==============================================================================
#
# PURPOSE
# -------
# Deploy a lightweight utility pod for troubleshooting and testing.
#
# WHAT YOU LEARN
# --------------
# - Interactive Kubernetes workloads
# - Utility containers
# - Pod inspection
#
# ------------------------------------------------------------------------------

# Create BusyBox pod
kubectl run busybox \
  --image=busybox \
  --restart=Never \
  -- sleep 3600

# Verify pod
kubectl get pods

# Access BusyBox shell
kubectl exec -it busybox -- sh
# ctrl+d to exit BusyBox shell

# --- Output ---
# rideout421@Ubuntu-24-LTS:~$ kubectl run busybox --image=busybox --restart=Never -- sleep 3600
# pod/busybox created
#
# rideout421@Ubuntu-24-LTS:~$ kubectl get pods
# NAME                      READY   STATUS    RESTARTS   AGE
# apache-5959974c77-bv599   1/1     Running   0          68s
# busybox                   1/1     Running   0          7s
# nginx-56c45fd5ff-28586    1/1     Running   0          2m39s
#
# rideout421@Ubuntu-24-LTS:~$ kubectl exec -it busybox -- sh
# / #
# command terminated with exit code 130



# ==============================================================================
# SECTION 4A - NETWORK DEBUGGING POD (NETSHOOT)
# ==============================================================================
#
# PURPOSE
# -------
# Deploy an advanced Kubernetes troubleshooting container for network analysis.
#
# WHY THIS EXISTS
# ---------------
# BusyBox is minimal and limited.
# Netshoot provides a full networking toolkit for real-world debugging.
#
# WHAT YOU LEARN
# --------------
# - Kubernetes interactive debugging
# - DNS resolution inside cluster
# - Service connectivity testing
# - Network packet inspection
# - Routing and interface analysis
#
# TOOLSET INCLUDED
# ----------------
# - curl       (HTTP testing)
# - dig        (DNS lookup)
# - nslookup   (DNS validation)
# - tcpdump    (packet capture)
# - iproute2   (network configuration tools)
# - traceroute (path analysis)
# - ss/netstat (socket inspection)
#
# IMAGE USED
# ----------
# nicolaka/netshoot
#
# ------------------------------------------------------------------------------

# Create Netshoot debugging pod
kubectl run debug \
  --image=nicolaka/netshoot \
  --restart=Never \
  --command -- bash -c "sleep infinity"

# Enter Netshoot shell
kubectl exec -it debug -- bash

# ==============================================================================
# DEBUGGING EXAMPLES (RUN INSIDE POD)
# ==============================================================================
#
# Test DNS:
#   nslookup kubernetes.default
#
# Test HTTP service:
#   curl http://nginx
#
# Inspect network interfaces:
#   ip a
#
# View routing table:
#   ip route
#
# Test external connectivity:
#   curl https://google.com
#
# Trace network path:
#   traceroute 8.8.8.8
#
# Capture packets:
#   tcpdump -i any
#
# ------------------------------------------------------------------------------

# --- Output ---
# rideout421@Ubuntu-24-LTS:~$ kubectl run debug --image=nicolaka/netshoot --restart=Never --command -- bash -c "sleep infinity"
# pod/debug created
#
# rideout421@Ubuntu-24-LTS:~$ kubectl exec -it debug -- bash
#
# debug:~# nslookup kubernetes.default
# Server:  10.96.0.10
# Address: 10.96.0.10#53
# Name:    kubernetes.default.svc.cluster.local
# Address: 10.96.0.1
#
# debug:~# curl http://nginx
# <!DOCTYPE html>
# <html>
# <head><title>Welcome to nginx!</title></head>
# <body><h1>Welcome to nginx!</h1></body>
# </html>
#
# debug:~# ip a
# 1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536
#     inet 127.0.0.1/8
# 2: eth0@if20: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
#     inet 10.244.0.134/16
#
# debug:~# ip route
# default via 10.244.0.1 dev eth0
# 10.244.0.0/16 dev eth0 proto kernel scope link src 10.244.0.134
#
# debug:~# curl https://google.com
# <HTML><HEAD>...</HEAD><BODY><H1>301 Moved</H1></BODY></HTML>
#
# debug:~# traceroute 8.8.8.8
# traceroute to 8.8.8.8 (8.8.8.8), 30 hops max
#  1  10.244.0.1 (10.244.0.1)  0.006 ms
#  2  host.minikube.internal (192.168.49.1)  0.002 ms
#  3  _gateway (192.168.179.2)  0.005 ms
#  4-11  * * *
#
# debug:~# tcpdump -i any
# tcpdump: WARNING: any: That device doesn't support promiscuous mode
# 0 packets captured
# 0 packets received by filter
# 0 packets dropped by kernel



# ==============================================================================
# SECTION 5 - VIEW KUBERNETES DASHBOARD
# ==============================================================================
#
# PURPOSE
# -------
# Observe workloads visually in Kubernetes Dashboard.
#
# WHAT YOU LEARN
# --------------
# - Cluster visualization
# - Pod resource usage
# - Namespace inspection
#
# DASHBOARD URL
# -------------
# https://127.0.0.1:8001/#/workloads?namespace=default
#
# ------------------------------------------------------------------------------

# Start Kubernetes proxy if needed
# NOTE: If you see "address already in use" the proxy is already running - that is fine.
kubectl proxy

# --- Output ---
# rideout421@Ubuntu-24-LTS:~$ kubectl proxy
# error: listen tcp 127.0.0.1:8001: bind: address already in use
# (Proxy was already running - no action needed)



# ==============================================================================
# SECTION 6 - DEPLOY OPENFAAS FUNCTIONS
# ==============================================================================
#
# PURPOSE
# -------
# Deploy serverless functions into OpenFaaS.
#
# WHAT YOU LEARN
# --------------
# - Function deployment
# - Function invocation
# - Serverless execution
#
# WHAT YOU WILL SEE
# -----------------
# - OpenFaaS UI populated
# - Prometheus metrics increase
# - Function execution statistics
#
# ------------------------------------------------------------------------------

# Deploy Figlet function
faas-cli store deploy figlet

# Deploy NodeInfo function
faas-cli store deploy nodeinfo

# List deployed functions
faas-cli list

# Invoke Figlet function
echo "Hello Lab" | faas-cli invoke figlet

# Invoke NodeInfo function
faas-cli invoke nodeinfo

# --- Output ---
# rideout421@Ubuntu-24-LTS:~$ faas-cli store deploy figlet
# WARNING! You are not using an encrypted connection to the gateway, consider using HTTPS.
# Deployed. 202 Accepted.
# URL: http://192.168.49.2:31112/function/figlet
#
# rideout421@Ubuntu-24-LTS:~$ faas-cli store deploy nodeinfo
# WARNING! You are not using an encrypted connection to the gateway, consider using HTTPS.
# Deployed. 202 Accepted.
# URL: http://192.168.49.2:31112/function/nodeinfo
#
# rideout421@Ubuntu-24-LTS:~$ faas-cli list
# Function    Invocations   Replicas
# figlet      0             1
# nodeinfo    0             1
#
# rideout421@Ubuntu-24-LTS:~$ echo "Hello Lab" | faas-cli invoke figlet
#  _   _      _ _         _          _
# | | | | ___| | | ___   | |    __ _| |__
# | |_| |/ _ \ | |/ _ \  | |   / _` | '_ \
# |  _  |  __/ | | (_) | | |__| (_| | |_) |
# |_| |_|\___|_|_|\___/  |_____\__,_|_.__/
#
# rideout421@Ubuntu-24-LTS:~$ faas-cli invoke nodeinfo
# Hostname: nodeinfo-6749fbd57d-4qht2
# Arch: x64
# CPUs: 4
# Total mem: 7894MB
# Platform: linux
# Uptime: 10939.68



# ==============================================================================
# SECTION 7 - VIEW OPENFAAS PORTAL
# ==============================================================================
#
# PURPOSE
# -------
# Observe deployed functions and execution metrics.
#
# WHAT YOU LEARN
# --------------
# - Function monitoring
# - Invocation statistics
# - OpenFaaS gateway visibility
#
# URL
# ---
# http://192.168.49.2:31112/ui/
#
# ------------------------------------------------------------------------------

# Verify OpenFaaS pods
kubectl get pods -n openfaas

# Verify OpenFaaS services
kubectl get svc -n openfaas

# --- Output ---
# rideout421@Ubuntu-24-LTS:~$ kubectl get pods -n openfaas
# NAME                            READY   STATUS    RESTARTS         AGE
# alertmanager-684f4899cb-4nxqg   1/1     Running   10 (3h45m ago)   39h
# gateway-76bb649c89-wfxgk        2/2     Running   55 (3h43m ago)   39h
# grafana                         1/1     Running   2 (3h45m ago)    21h
# nats-7cc5c654cf-nxk2g           1/1     Running   10 (3h45m ago)   39h
# prometheus-7fbcf5bfb5-hddbh     1/1     Running   10 (3h45m ago)   39h
# queue-worker-5df9c968d8-z7gsk   1/1     Running   20 (3h43m ago)   39h
#
# rideout421@Ubuntu-24-LTS:~$ kubectl get svc -n openfaas
# NAME               TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
# alertmanager       ClusterIP   10.109.65.194    <none>        9093/TCP         4d2h
# gateway            ClusterIP   10.111.101.188   <none>        8080/TCP         4d2h
# gateway-external   NodePort    10.101.166.87    <none>        8080:31112/TCP   4d2h
# grafana            ClusterIP   10.111.224.103   <none>        3000/TCP         25h
# nats               ClusterIP   10.97.79.162     <none>        4222/TCP         4d2h
# prometheus         ClusterIP   10.98.187.244    <none>        9090/TCP         4d2h



# ==============================================================================
# SECTION 8 - CREATE MINIO BUCKETS
# ==============================================================================
#
# PURPOSE
# -------
# Populate MinIO object storage with buckets and files.
#
# WHAT YOU LEARN
# --------------
# - S3-compatible storage
# - Bucket management
# - Object uploads
# - Secure credential retrieval
#
# ------------------------------------------------------------------------------

# Retrieve credentials securely from systemd-managed env file
MINIO_ENV_FILE="/etc/minio/minio.env"

MINIO_ROOT_USER=$(sudo awk -F= '/MINIO_ROOT_USER/ {print $2}' "$MINIO_ENV_FILE")
MINIO_ROOT_PASSWORD=$(sudo awk -F= '/MINIO_ROOT_PASSWORD/ {print $2}' "$MINIO_ENV_FILE")

# Configure MinIO client alias safely
mc alias set local http://127.0.0.1:9000 \
  "$MINIO_ROOT_USER" \
  "$MINIO_ROOT_PASSWORD"

# Create infrastructure bucket
mc mb local/lab-backups || true

# Create logging bucket
mc mb local/log-archive || true

# Create OpenTofu state bucket
mc mb local/tofu-state || true

# --- Output ---
# Added `local` successfully.
# Bucket created successfully `local/lab-backups`.
# Bucket created successfully `local/log-archive`.
# Bucket created successfully `local/tofu-state`.



# ==============================================================================
# SECTION 9 - UPLOAD OBJECTS TO MINIO
# ==============================================================================
#
# PURPOSE
# -------
# Upload files into MinIO buckets.
#
# WHAT YOU LEARN
# --------------
# - Object uploads
# - S3 workflows
# - Storage visibility
#
# WHAT YOU WILL SEE
# -----------------
# - Buckets populated in MinIO UI
# - Object metadata
# - Storage consumption
#
# ------------------------------------------------------------------------------

# Create sample file
echo "OpenTofu Lab State" > state.txt

# Upload sample state file
mc cp state.txt local/tofu-state/

# Export system logs
journalctl -n 100 > system-log.txt

# Upload logs
mc cp system-log.txt local/log-archive/

# --- Output ---
# rideout421@Ubuntu-24-LTS:~$ echo "OpenTofu Lab State" > state.txt
# rideout421@Ubuntu-24-LTS:~$ mc cp state.txt local/tofu-state/
# rideout421@Ubuntu-24-LTS:~$ journalctl -n 100 > system-log.txt
# rideout421@Ubuntu-24-LTS:~$ mc cp system-log.txt local/log-archive/



# ==============================================================================
# SECTION 10 - VIEW MINIO OBJECT STORAGE
# ==============================================================================
#
# PURPOSE
# -------
# Observe uploaded buckets and objects in MinIO web console.
#
# URL
# ---
# http://127.0.0.1:9001/browser
#
# ------------------------------------------------------------------------------

# Verify MinIO service
systemctl status minio

# --- Output ---
# rideout421@Ubuntu-24-LTS:~$ systemctl status minio
# ● minio.service - MinIO OSS Object Storage
#      Loaded: loaded (/etc/systemd/system/minio.service; enabled; preset: enabled)
#      Active: active (running) since Tue 2026-05-12 11:49:39 EDT; 8min ago
#   Main PID: 77131 (minio)
#     Memory: 77.6M (peak: 78.5M)
#        CPU: 735ms
# May 12 11:49:40 Ubuntu-24-LTS minio[77131]: MinIO Object Storage Server
# May 12 11:49:40 Ubuntu-24-LTS minio[77131]: Version: RELEASE.2025-09-07T16-13-09Z
# May 12 11:49:40 Ubuntu-24-LTS minio[77131]: API: http://192.168.179.130:9000
# May 12 11:49:40 Ubuntu-24-LTS minio[77131]: WebUI: http://192.168.179.130:9001



# ==============================================================================
# SECTION 11 - PROMETHEUS VALIDATION
# ==============================================================================
#
# PURPOSE
# -------
# Validate Prometheus metrics collection.
#
# WHAT YOU LEARN
# --------------
# - Metrics scraping
# - Kubernetes telemetry
# - Query inspection
# - OpenFaaS observability
#
# ARCHITECTURE
# ------------
# Prometheus is deployed within the OpenFaaS namespace:
#
#   Namespace: openfaas
#
# URL
# ---
# http://127.0.0.1:9090/query
#
# ==============================================================================
# SECTION 11 - PROMETHEUS VALIDATION QUERIES
# ==============================================================================
# Overall health of all scraped targets (Prometheus, OpenFaaS gateway, etc.):
#   up
#
# Prometheus version and build information:
#   prometheus_build_info
#
# CPU usage of Prometheus and OpenFaaS components:
#   process_cpu_seconds_total
#
# Number of goroutines running in Prometheus and gateway:
#   go_goroutines
#
# Function invocation rate (requests per second) over last 5 minutes:
#   rate(gateway_function_invocation_total[5m])
#
# Total function invocations (cumulative count):
#   gateway_function_invocation_total
#
# Function invocation errors (non-200 responses):
#   gateway_function_invocation_total{code!="200"}
#
# 95th percentile function latency / response time:
#   histogram_quantile(0.95, sum(rate(gateway_function_latency_seconds_bucket[5m])) by (le))
#
# Total number of deployed OpenFaaS functions:
#   gateway_functions_total
#
# Information about registered OpenFaaS services and functions:
#   gateway_service_info
#
# Number of container restarts in OpenFaaS namespaces:
#   kube_pod_container_status_restarts_total{namespace=~"openfaas.*"}
#
# Current desired replicas per OpenFaaS function:
#   sum(kube_deployment_spec_replicas{namespace="openfaas-fn"}) by (deployment)
#
# All pods running in the OpenFaaS namespace:
#   kube_pod_info{namespace="openfaas"}
#
# Memory usage of containers in OpenFaaS namespace:
#   container_memory_working_set_bytes{namespace="openfaas"}
#
# Available memory percentage on the node:
#   node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100
#
# Persistent Volume usage (important after adding PVCs):
#   kubelet_volume_stats_used_bytes
#
# Persistent Volume total capacity:
#   kubelet_volume_stats_capacity_bytes
#
# NOTE
# ----
# The OpenFaaS invocation metric is especially useful because it
# validates Prometheus telemetry collection from the OpenFaaS gateway.
# Each was set up using the Prometheus Query UI at the URL above.
# You can run the queries and see results in real-time.
#
# ------------------------------------------------------------------------------

# Verify Prometheus pod
kubectl get pods -n openfaas | grep prometheus

# Verify Prometheus service
kubectl get svc -n openfaas | grep prometheus

# Live validation queries
curl -s "http://127.0.0.1:9090/api/v1/query?query=up"

curl -s "http://127.0.0.1:9090/api/v1/query?query=gateway_function_invocation_total"

# --- Output ---
# rideout421@Ubuntu-24-LTS:~$ kubectl get pods -n openfaas | grep prometheus
# prometheus-7fbcf5bfb5-hddbh     1/1     Running   10 (4h26m ago)   39h
#
# rideout421@Ubuntu-24-LTS:~$ kubectl get svc -n openfaas | grep prometheus
# prometheus         ClusterIP   10.98.187.244    <none>        9090/TCP         4d3h
#
# rideout421@Ubuntu-24-LTS:~$ curl -s "http://127.0.0.1:9090/api/v1/query?query=up"
# {"status":"success","data":{"resultType":"vector","result":[
#   {"metric":{"__name__":"up","instance":"localhost:9090","job":"prometheus"},"value":[1778603214.622,"1"]},
#   {"metric":{"__name__":"up","app":"gateway","instance":"10.244.0.121:8082","job":"openfaas-pods",
#    "kubernetes_namespace":"openfaas"},"value":[1778603214.622,"1"]}
# ]}}
#
# rideout421@Ubuntu-24-LTS:~$ curl -s "http://127.0.0.1:9090/api/v1/query?query=gateway_function_invocation_total"
# {"status":"success","data":{"resultType":"vector","result":[
#   {"metric":{"__name__":"gateway_function_invocation_total","function_name":"figlet.openfaas-fn","code":"200"},
#    "value":[1778603214.638,"1"]},
#   {"metric":{"__name__":"gateway_function_invocation_total","function_name":"nodeinfo.openfaas-fn","code":"200"},
#    "value":[1778603214.638,"2"]}
# ]}}



# ==============================================================================
# SECTION 12 - GRAFANA VALIDATION
# ==============================================================================
#
# PURPOSE
# -------
# Visualize metrics collected by Prometheus.
# Validate full observability stack: Grafana + Prometheus + OpenFaaS pipeline.
#
# WHAT YOU LEARN
# --------------
# - Dashboard visualization
# - Metrics graphing
# - Infrastructure observability
# - OpenFaaS telemetry visibility
#
# ARCHITECTURE
# ------------
# All services run inside the OpenFaaS namespace:
#
#   Grafana    → http://127.0.0.1:3000 (port-forward via kubectl)
#   Prometheus → http://prometheus:9090 (cluster DNS)
#
# Metrics flow:
#   OpenFaaS → Prometheus → Grafana
#
# URL
# ---
# http://127.0.0.1:3000/?orgId=1
#
# ------------------------------------------------------------------------------

# ==============================================================================
# STEP 1 - ACCESS GRAFANA
# ==============================================================================

echo "Grafana UI: http://127.0.0.1:3000"
echo "Login user: admin"

echo "Password:"
kubectl get secret -n openfaas grafana-admin \
  -o jsonpath="{.data.password}" | base64 --decode

# NOTE: Password can also be retrieved directly from the pod env:
#   kubectl exec -n openfaas grafana -- printenv GF_SECURITY_ADMIN_PASSWORD

# ==============================================================================
# STEP 2 - VERIFY BACKEND HEALTH
# ==============================================================================

kubectl get pods -n openfaas | grep grafana
kubectl get pods -n openfaas | grep prometheus

kubectl get svc -n openfaas | grep grafana
kubectl get svc -n openfaas | grep prometheus

# Verify port-forward is active
ss -tulpn | grep 3000

# --- Output ---
# rideout421@Ubuntu-24-LTS:~$ kubectl get pods -n openfaas | grep grafana
# grafana                         1/1     Running   2 (4h51m ago)    22h
#
# rideout421@Ubuntu-24-LTS:~$ kubectl get pods -n openfaas | grep prometheus
# prometheus-7fbcf5bfb5-hddbh     1/1     Running   10 (4h51m ago)   40h
#
# rideout421@Ubuntu-24-LTS:~$ kubectl get svc -n openfaas | grep grafana
# grafana            ClusterIP   10.111.224.103   <none>        3000/TCP         26h
#
# rideout421@Ubuntu-24-LTS:~$ kubectl get svc -n openfaas | grep prometheus
# prometheus         ClusterIP   10.98.187.244    <none>        9090/TCP         4d3h
#
# rideout421@Ubuntu-24-LTS:~$ ss -tulpn | grep 3000
# tcp   LISTEN 0  4096  127.0.0.1:3000  0.0.0.0:*  users:(("kubectl",pid=65317,fd=8))
# tcp   LISTEN 0  4096      [::1]:3000     [::]:*  users:(("kubectl",pid=65317,fd=9))

# ==============================================================================
# STEP 3 - CONNECT PROMETHEUS TO GRAFANA (CRITICAL STEP)
# ==============================================================================
#
# THIS IS THE MISSING STEP MOST USERS MISS
#
# In Grafana UI:
#
#   Settings → Data Sources → Add data source → Prometheus
#
# CONFIGURATION:
#   Name : Prometheus
#   URL  : http://prometheus:9090
#   Auth : None
#
# Click: Save & Test
#
# EXPECTED OUTPUT:
#   ✔ Data source is working
#
# IMPORTANT:
#   Do NOT use localhost here. Must use Kubernetes service DNS.
#
# ==============================================================================

# ==============================================================================
# STEP 4 - DASHBOARD SETUP
# ==============================================================================
#
# IMPORTANT:
# This lab does NOT use Grafana.com dashboard IDs.
# It uses manual JSON import only.
#
# In Grafana UI:
#   1. Click "Create"
#   2. Click "Import"
#   3. Paste JSON or upload JSON file
#
# DASHBOARD JSON:
# ---------------
#
#{
#  "title": "OpenFaaS Lab Observability Dashboard",
#  "schemaVersion": 38,
#  "version": 1,
#  "refresh": "10s",
#  "time": { "from": "now-15m", "to": "now" },
#  "panels": [
#    {
#      "type": "timeseries",
#      "title": "Cluster Health (UP Targets)",
#      "gridPos": { "x": 0, "y": 0, "w": 12, "h": 8 },
#      "targets": [
#        { "expr": "up", "legendFormat": "{{job}} - {{instance}}" }
#      ]
#    },
#    {
#      "type": "timeseries",
#      "title": "Prometheus Build Info",
#      "gridPos": { "x": 12, "y": 0, "w": 12, "h": 8 },
#      "targets": [
#        { "expr": "prometheus_build_info", "legendFormat": "build" }
#      ]
#    },
#    {
#      "type": "timeseries",
#      "title": "Go Goroutines",
#      "gridPos": { "x": 0, "y": 8, "w": 12, "h": 8 },
#      "targets": [
#        { "expr": "go_goroutines", "legendFormat": "goroutines" }
#      ]
#    },
#    {
#      "type": "timeseries",
#      "title": "Process CPU Seconds",
#      "gridPos": { "x": 12, "y": 8, "w": 12, "h": 8 },
#      "targets": [
#        { "expr": "process_cpu_seconds_total", "legendFormat": "{{job}} - {{instance}}" }
#      ]
#    }
#  ]
#}
#
# ==============================================================================
# STEP 5 - END-TO-END PIPELINE TEST
# ==============================================================================
#
# Invoke functions to generate metrics, then observe in Grafana dashboards.

echo "test" | faas-cli invoke figlet
echo "test" | faas-cli invoke nodeinfo

# Then validate in Grafana:
#   - Invocation counters increase
#   - Gateway metrics update
#   - Latency charts change
#   - Function activity visible in dashboards

# --- Output ---
# rideout421@Ubuntu-24-LTS:~$ echo "test" | faas-cli invoke figlet
#  _            _
# | |_ ___  ___| |_
# | __/ _ \/ __| __|
# | ||  __/\__ \ |_
#  \__\___||___/\__|
#
# rideout421@Ubuntu-24-LTS:~$ echo "test" | faas-cli invoke nodeinfo
# Hostname: nodeinfo-6749fbd57d-4qht2
# Arch: x64
# CPUs: 4
# Total mem: 7894MB
# Platform: linux
# Uptime: 19396.6

# ==============================================================================
# STEP 6 - VALIDATION CHECKLIST
# ==============================================================================

echo "VALIDATION CHECKLIST:"
echo "- Grafana reachable at http://127.0.0.1:3000"
echo "- Prometheus datasource = HEALTHY"
echo "- PromQL queries return data"
echo "- Dashboards render successfully"
echo "- Metrics update in real time"



# ==============================================================================
# SECTION 13 - OPENTOFU VALIDATION
# ==============================================================================
#
# PURPOSE
# -------
# Validate OpenTofu installation and initialize first project directory.
#
# WHAT YOU LEARN
# --------------
# - Infrastructure as Code
# - Provider initialization
# - Terraform/OpenTofu workflow
#
# ------------------------------------------------------------------------------

# Create OpenTofu project directory
mkdir -p ~/opentofu-lab

# Enter project directory
cd ~/opentofu-lab

# Validate OpenTofu installation
tofu version

# Initialize empty project
tofu init

# --- Output ---
# rideout421@Ubuntu-24-LTS:~$ tofu version
# OpenTofu v1.11.7
# on linux_amd64



# ==============================================================================
# SECTION 14 - FINAL VALIDATION
# ==============================================================================
#
# PURPOSE
# -------
# Validate complete lab environment health.
#
# WHAT YOU SHOULD SEE
# -------------------
# - Running Kubernetes pods
# - Active OpenFaaS functions
# - Populated MinIO buckets
# - Prometheus metrics
# - Grafana dashboards
# - OpenTofu operational
#
# ------------------------------------------------------------------------------

# View all Kubernetes resources
kubectl get all -A

# View Minikube status
minikube status

# View Docker containers
docker ps

# Verify MinIO service
systemctl status minio

# Verify OpenTofu
tofu version

# --- Output ---
# rideout421@Ubuntu-24-LTS:~$ kubectl get all -A
# NAMESPACE              NAME                                            READY   STATUS      RESTARTS       AGE
# default                pod/apache-5959974c77-bv599                     1/1     Running     0              9h
# default                pod/busybox                                     0/1     Completed   0              9h
# default                pod/debug                                       1/1     Running     0              8h
# default                pod/nginx-56c45fd5ff-28586                      1/1     Running     0              9h
# kube-system            pod/coredns-7d764666f9-ps7s8                    1/1     Running     11 (11h ago)   4d10h
# kube-system            pod/etcd-minikube                               1/1     Running     11 (11h ago)   4d10h
# kube-system            pod/kube-apiserver-minikube                     1/1     Running     11 (11h ago)   4d10h
# kube-system            pod/kube-controller-manager-minikube            1/1     Running     11 (11h ago)   4d10h
# kube-system            pod/kube-proxy-2pfn2                            1/1     Running     11 (11h ago)   4d10h
# kube-system            pod/kube-scheduler-minikube                     1/1     Running     11 (11h ago)   4d10h
# kube-system            pod/storage-provisioner                         1/1     Running     23 (11h ago)   4d10h
# kubernetes-dashboard   pod/dashboard-metrics-scraper-8d46b45f6-jl6xv   1/1     Running     4 (11h ago)    31h
# kubernetes-dashboard   pod/kubernetes-dashboard-b44857bbb-795lc        1/1     Running     6 (11h ago)    31h
# openfaas-fn            pod/figlet-6977948c59-bm5d5                     1/1     Running     0              8h
# openfaas-fn            pod/nodeinfo-6749fbd57d-4qht2                   1/1     Running     0              8h
# openfaas               pod/alertmanager-684f4899cb-4nxqg               1/1     Running     10 (11h ago)   46h
# openfaas               pod/gateway-76bb649c89-wfxgk                    2/2     Running     55 (11h ago)   46h
# openfaas               pod/grafana                                     1/1     Running     2 (11h ago)    28h
# openfaas               pod/nats-7cc5c654cf-nxk2g                       1/1     Running     10 (11h ago)   46h
# openfaas               pod/prometheus-7fbcf5bfb5-hddbh                 1/1     Running     10 (11h ago)   46h
# openfaas               pod/queue-worker-5df9c968d8-z7gsk               1/1     Running     20 (11h ago)   46h
#
# NAMESPACE              NAME                                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                  AGE
# default                service/apache                      NodePort    10.97.116.200    <none>        80:31764/TCP             9h
# default                service/kubernetes                  ClusterIP   10.96.0.1        <none>        443/TCP                  4d10h
# default                service/nginx                       NodePort    10.107.156.149   <none>        80:30425/TCP             9h
# openfaas               service/gateway-external            NodePort    10.101.166.87    <none>        8080:31112/TCP           4d10h
# openfaas               service/grafana                     ClusterIP   10.111.224.103   <none>        3000/TCP                 32h
# openfaas               service/prometheus                  ClusterIP   10.98.187.244    <none>        9090/TCP                 4d10h
#
# rideout421@Ubuntu-24-LTS:~$ minikube status
# minikube
# type: Control Plane
# host: Running
# kubelet: Running
# apiserver: Running
# kubeconfig: Configured
#
# rideout421@Ubuntu-24-LTS:~$ docker ps
# CONTAINER ID   IMAGE                                 COMMAND                  CREATED      STATUS        NAMES
# 3cfae63cb1a9   gcr.io/k8s-minikube/kicbase:v0.0.50   "/usr/local/bin/entr…"   4 days ago   Up 11 hours   minikube
#
# rideout421@Ubuntu-24-LTS:~$ tofu version
# OpenTofu v1.11.7
# on linux_amd64



# ==============================================================================
# SECTION 15 - BACKUP & RESTORE PIPELINE
# ==============================================================================
#
# STATUS: MANUAL BACKUP CONFIRMED WORKING
# ------------------------------------------------------------------------------
#
# Three scripts were created and stored locally on the VM under /usr/local/bin:
#
#   /usr/local/bin/InstallBackupControlPlane.sh
#     One-time installer. Run once to deploy the backup and restore scripts
#     onto the VM.
#
#   /usr/local/bin/BackupCurrentState.sh
#     Full lab backup pipeline covering OpenTofu, Minikube/Kubernetes,
#     OpenFaaS, Grafana, Prometheus, MinIO.
#     Uploads archive to MinIO local/lab-backups.
#     Retains latest 3 backups.
#
#   /usr/local/bin/RestoreCurrentState.sh
#     Restores lab state from latest MinIO backup artifact.
#     Defaults to dry-run (read + verify only).
#     Set ENABLE_APPLY=true to apply changes to the cluster.
#
# No automation, schedule, or trigger has been set up yet.
# Goal for now: confirm manual process works reliably before adding any trigger.
#
# ------------------------------------------------------------------------------
# HOW TO RUN
# ------------------------------------------------------------------------------
#
# Run the backup manually as your normal user (NOT sudo):
#
#   /usr/local/bin/BackupCurrentState.sh
#
# Running without sudo is correct and intentional.
# The script uses internal sudo calls only where needed
# (e.g. reading /etc/grafana/grafana.env).
#
# Running the whole script as sudo breaks kubectl because root does not have
# the kubeconfig pointing to the Minikube cluster (/home/<user>/.kube/config).
#
# Copy-paste into terminal also works and was used to validate the script
# before running it directly from /usr/local/bin.
#
# ------------------------------------------------------------------------------
# LESSONS LEARNED THIS SESSION
# ------------------------------------------------------------------------------
#
# 1. HEREDOC QUOTING BUG (RESOLVED)
#    The installer script used <<'EOF' heredocs to write the backup/restore
#    scripts to disk. Single quotes inside awk commands (e.g. awk '{print $NF}')
#    terminated the outer heredoc early, silently truncating the written scripts.
#
#    Fix: rewrote all awk calls inside heredocs using double quotes and escaped
#    dollar signs: awk "{print \$NF}"
#    Also renamed heredoc markers to BACKUP_EOF and RESTORE_EOF to avoid
#    any ambiguity about which EOF closes which block.
#
# 2. SUDO / KUBECONFIG BUG (RESOLVED)
#    Running sudo /usr/local/bin/BackupCurrentState.sh caused kubectl to fail:
#      "connection refused - did you specify the right host or port?"
#    Root cause: sudo runs as root, and root has no kubeconfig for Minikube.
#    Fix: run as normal user without sudo.
#
# ------------------------------------------------------------------------------
# NEXT STEPS (FUTURE - NOT YET STARTED)
# ------------------------------------------------------------------------------
#
# - Decide on a backup trigger model. Options to consider:
#     a) Pre-shutdown hook  - backup before the lab VM is powered off
#     b) OpenFaaS webhook   - event-driven trigger from within the cluster
#     c) Lightweight cron   - simple scheduled job if the lab stays on long
#
# - The lab does not stay on continuously so a pre-shutdown trigger likely
#   makes the most sense to capture state before power-off.
#
# - Restore process has not yet been tested end-to-end. That should be
#   validated before relying on backups for real recovery.



# ==============================================================================
# APPENDIX A - PYTHON ENVIRONMENT BOOTSTRAP
# ==============================================================================
#
# PURPOSE
# -------
# Install Python runtime and lab dependencies.
# Run this once if Python-based tooling is needed in the lab.
#
# NOTE: Ubuntu 24 requires a virtual environment for pip installs.
#
# ------------------------------------------------------------------------------

echo "[BOOTSTRAP] Installing Python runtime..."

sudo apt update

sudo apt install -y \
  python3 \
  python3-pip \
  python3-venv \
  python3-dev \
  build-essential

echo "[BOOTSTRAP] Python installed"

# Create lab virtual environment
echo "[BOOTSTRAP] Creating Python virtual environment..."

LAB_VENV="$HOME/k8s-lab-venv"

python3 -m venv "$LAB_VENV"

source "$LAB_VENV/bin/activate"

echo "[BOOTSTRAP] Virtual environment activated"

# Install lab packages
pip install --upgrade pip

pip install \
  requests \
  boto3 \
  kubernetes

echo "[BOOTSTRAP] Python lab libraries installed"

# Verify
python --version
pip --version

echo "[BOOTSTRAP] Python environment ready"

# --- Output ---
# Python 3.12.3
# pip 26.1.1 from /home/rideout421/k8s-lab-venv/lib/python3.12/site-packages/pip (python 3.12)
# [BOOTSTRAP] Python environment ready



# ==============================================================================
# END OF LAB
# ==============================================================================
#
# NEXT RECOMMENDED TOPICS
# -----------------------
# - Helm deployments
# - OpenTofu Kubernetes provider
# - Persistent volumes
# - Ingress controllers
# - GitOps
# - ArgoCD
# - Monitoring alerts
# - Kubernetes secrets
#
# ==============================================================================