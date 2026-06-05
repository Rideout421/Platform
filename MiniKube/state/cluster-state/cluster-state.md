# Cluster State Reference

Current state of the Minikube lab environment. Updated as the cluster evolves.

---

## Service Access URLs

| Service              | Access URL                        | Method                  |
| -------------------- | --------------------------------- | ----------------------- |
| MinIO Console        | `http://192.168.49.2:9001`      | NodePort (direct)       |
| MinIO S3 API         | `http://192.168.49.2:9000`      | NodePort (direct)       |
| Kubernetes Dashboard | `http://127.0.0.1:8001`         | port-forward            |
| OpenFaaS UI          | `http://192.168.49.2:31112/ui/` | NodePort (direct)       |
| Prometheus           | `http://127.0.0.1:9090`         | port-forward            |
| Grafana              | `http://127.0.0.1:3000`         | port-forward / NodePort |

> **Note:** `192.168.49.x` is the Minikube internal network. `127.0.0.1` services require an active `kubectl port-forward` session.

---

## Cluster Topology

```
Linux VM / Host
├── OpenTofu           (IaC — infrastructure provisioning)
├── MinIO              (S3-compatible object storage)
├── kubectl            (cluster management CLI)
├── Helm               (Kubernetes package manager)
├── Docker             (container runtime)
└── Minikube
    └── Kubernetes Single-Node Cluster
        ├── OpenFaaS   (serverless platform)
        ├── Prometheus (metrics collection)
        └── Grafana    (observability dashboards)
```

---

## Component Placement

| Component  | Placement  | Reason                                                                |
| ---------- | ---------- | --------------------------------------------------------------------- |
| OpenTofu   | Host VM    | Infrastructure control plane — manages resources outside the cluster |
| MinIO      | Host VM    | Persistent external storage, survives cluster restarts                |
| Minikube   | Host VM    | Local Kubernetes runtime                                              |
| Prometheus | Kubernetes | Native cluster observability, scrapes in-cluster metrics              |
| Grafana    | Kubernetes | Visualizes Prometheus data, lives alongside the stack it monitors     |
| OpenFaaS   | Kubernetes | Native K8s workload, uses cluster networking and scheduling           |
