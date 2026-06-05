# Cluster Design

Architectural decisions and placement rationale for the cloud-native home lab.

---

## Design Philosophy

The lab is intentionally structured to mirror production platform engineering patterns at a local scale. Each component is placed where it would live in a real environment — not just where it's convenient — so the architecture translates directly to enterprise deployments.

---

## Host vs. Cluster Boundary

A deliberate boundary separates **host-level infrastructure** from  **cluster workloads** :

```
┌─────────────────────────────────────────────┐
│  Linux Host VM                              │
│                                             │
│  OpenTofu  ·  MinIO  ·  kubectl  ·  Helm   │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │  Minikube Kubernetes Cluster          │  │
│  │                                       │  │
│  │  OpenFaaS · Prometheus · Grafana      │  │
│  │  NGINX · Apache · Functions           │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

**Host-level components** are infrastructure primitives that manage or outlive the cluster. They need to be available before the cluster starts and remain available if the cluster is torn down.

**Cluster workloads** are application-layer services that benefit from Kubernetes scheduling, networking, and lifecycle management.

---

## Component Placement Rationale

### OpenTofu — Host VM

Infrastructure as code tooling belongs at the control plane layer, outside the cluster it provisions. Keeps IaC execution independent of cluster health.

### MinIO — Host VM

S3-compatible object storage serves as the backup target and state persistence layer. Placing it on the host ensures data survives cluster restarts, resets, and disaster recovery scenarios.

### Minikube — Host VM

The Kubernetes runtime itself runs on the host, providing the single-node cluster that all workloads deploy into.

### Prometheus + Grafana — Kubernetes

Observability tooling runs inside the cluster to natively scrape in-cluster metrics via the Kubernetes service discovery API. Co-location with the monitored workloads reduces network complexity.

### OpenFaaS — Kubernetes

Serverless platform requires Kubernetes-native scheduling, networking, and autoscaling. The Gateway, Queue Worker, and NATS components are designed as Kubernetes workloads.

---

## Service Exposure Strategy

| Method       | Used For                       | Notes                                    |
| ------------ | ------------------------------ | ---------------------------------------- |
| NodePort     | MinIO, OpenFaaS                | Persistent access, survives pod restarts |
| port-forward | Dashboard, Prometheus, Grafana | On-demand access, session-based          |

NodePort is used for services that need to be reliably reachable without an active terminal session. Port-forward is used for admin/observability tooling accessed interactively.

---

## Scaling Path

This single-node design is intentionally simple. The logical next steps to evolve toward production-grade:

* **Multi-node cluster** — HA control plane, worker node separation
* **GitOps (ArgoCD)** — declarative, Git-driven workload deployment
* **Ingress + TLS** — replace NodePort with proper ingress controller and cert-manager
* **Secrets management** — Vault or Sealed Secrets for credential handling
* **Service mesh** — Istio or Linkerd for mTLS, traffic management, and observability
