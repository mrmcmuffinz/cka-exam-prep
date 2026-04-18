# Cluster Setup

This document is the single source of truth for the cluster configurations used
across the CKA exam prep assignments. Every assignment README references a section
of this document by anchor rather than inlining setup commands, so a version bump
or URL change happens in exactly one place.

All commands assume the Linux shell and target a local machine running rootless
containerd via `nerdctl`. If you use Docker instead of nerdctl, omit the
`KIND_EXPERIMENTAL_PROVIDER=nerdctl` prefix.

**Last verified:** 2026-04-18 (see the version matrix at the bottom of this file).

---

## Contents

- [Prerequisites](#prerequisites)
- [Single-node kind cluster](#single-node-kind-cluster)
- [Multi-node kind cluster](#multi-node-kind-cluster)
- [Multi-node with Calico (NetworkPolicy support)](#multi-node-with-calico-networkpolicy-support)
- [MetalLB for LoadBalancer services](#metallb-for-loadbalancer-services)
- [Metrics-server](#metrics-server)
- [Gateway API CRDs](#gateway-api-crds)
- [Ingress controllers](#ingress-controllers)
- [Teardown](#teardown)
- [Version matrix](#version-matrix)

---

## Prerequisites

The exercises assume the following tools are installed on the host.

| Tool | Minimum version | Purpose |
|---|---|---|
| `kind` | v0.31.0 | Creates local Kubernetes clusters as containers. v0.31.0 is the first release that ships a `kindest/node:v1.35.0` image. |
| `kubectl` | v1.34 or v1.35 | Kubernetes command-line tool. The Kubernetes version skew policy allows kubectl to be one minor version higher or lower than the cluster. |
| `nerdctl` | rootless mode | Container runtime frontend. Required for the `KIND_EXPERIMENTAL_PROVIDER=nerdctl` provider. |
| `openssl` | any recent | Used by the RBAC and TLS assignments. |
| `helm` | v3.x | Required only for the Helm topic. |

Verify:

```bash
kind version
kubectl version --client
nerdctl version
```

---

## Single-node kind cluster

The default cluster for most assignments. Uses the `kindest/node:v1.35.0` image.

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster \
  --image kindest/node:v1.35.0
```

Verify:

```bash
kubectl get nodes
```

Expected: a single `control-plane` node in `Ready` status.

---

## Multi-node kind cluster

Required for scheduling, workload controllers, services, networking, and
troubleshooting assignments. Three workers give enough surface area to demonstrate
node affinity, pod anti-affinity, topology spread, and DaemonSet behavior.

```bash
cat <<EOF | KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster \
  --image kindest/node:v1.35.0 --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
EOF
```

Verify:

```bash
kubectl get nodes
```

Expected: four nodes (1 control-plane, 3 workers) all in `Ready` status.

---

## Multi-node with Calico (NetworkPolicy support)

Required for `network-policies/` assignments and `troubleshooting/assignment-4`.
Kind's default CNI (kindnet) does not enforce `NetworkPolicy` resources, so
Calico is installed in its place. This differs from the plain multi-node setup
by disabling the default CNI before install.

Create the cluster with the default CNI disabled:

```bash
cat <<EOF | KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster \
  --image kindest/node:v1.35.0 --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
EOF
```

Install Calico:

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.5/manifests/calico.yaml
```

Wait for Calico to become ready:

```bash
kubectl wait --for=condition=Ready pods -l k8s-app=calico-node -n kube-system --timeout=180s
kubectl wait --for=condition=Ready pods -l k8s-app=calico-kube-controllers -n kube-system --timeout=180s
```

Verify pods on all nodes can reach each other (Calico initial programming takes
a few seconds after ready):

```bash
kubectl get nodes
kubectl get pods -n kube-system
```

All nodes should be `Ready` and kube-system pods `Running`.

---

## MetalLB for LoadBalancer services

Required for `services/assignment-1` and `services/assignment-2` LoadBalancer
exercises. Kind does not natively provision external load balancers, so MetalLB
provides an IP address pool drawn from the kind network.

Install MetalLB:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.3/config/manifests/metallb-native.yaml
```

Wait for MetalLB to be ready:

```bash
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=120s
```

Identify the kind network subnet:

```bash
nerdctl network inspect kind | grep -i subnet
```

Configure the IP address pool (adjust the address range to fall inside the kind
subnet output above; the `172.18.255.x` range below works for the default kind
subnet `172.18.0.0/16`):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: kind-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.18.255.200-172.18.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: kind-l2
  namespace: metallb-system
EOF
```

Verify a LoadBalancer Service receives an external IP:

```bash
kubectl create deployment nginx --image=nginx:1.27
kubectl expose deployment nginx --type=LoadBalancer --port=80
kubectl get svc nginx
```

The `EXTERNAL-IP` column should show an address from the configured pool.

---

## Metrics-server

Required for `troubleshooting/assignment-1` and any exercise using
`kubectl top`. The `--kubelet-insecure-tls` flag is needed on kind because
kind's kubelet uses self-signed certificates.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.8.1/components.yaml
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
kubectl wait --for=condition=Available deployment/metrics-server -n kube-system --timeout=180s
```

Verify:

```bash
kubectl top nodes
```

---

## Gateway API CRDs

Required for all `ingress-and-gateway-api/assignment-3` and later assignments
using Gateway API. Gateway API resources are delivered as CRDs that must be
installed before any Gateway API implementation.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml
```

Verify the CRDs are registered:

```bash
kubectl get crd gatewayclasses.gateway.networking.k8s.io
kubectl get crd gateways.gateway.networking.k8s.io
kubectl get crd httproutes.gateway.networking.k8s.io
```

All three should exist.

The `standard-install.yaml` bundle contains the stable resources (GatewayClass,
Gateway, HTTPRoute, ReferenceGrant). Experimental resources (TCPRoute, TLSRoute,
UDPRoute, GRPCRoute) require `experimental-install.yaml` instead.

---

## Ingress controllers

Each ingress-and-gateway-api assignment installs a different controller to build
breadth across Ingress API and Gateway API implementations. The per-assignment
controller install commands live in the assignment's own tutorial file, because
every controller has its own install flow. This section lists the pinned versions
for reference.

| Assignment | Controller | Version | API |
|---|---|---|---|
| `ingress-and-gateway-api/assignment-1` | Traefik | (pinned at regeneration time) | Ingress v1 |
| `ingress-and-gateway-api/assignment-2` | HAProxy Ingress | (pinned at regeneration time) | Ingress v1 |
| `ingress-and-gateway-api/assignment-3` | Envoy Gateway | (pinned at regeneration time) | Gateway API |
| `ingress-and-gateway-api/assignment-4` | NGINX Gateway Fabric | (pinned at regeneration time) | Gateway API |
| `ingress-and-gateway-api/assignment-5` | Traefik and Envoy Gateway from prior assignments, plus the `Ingress2Gateway` CLI | (pinned at regeneration time) | Both (migration) |

Controllers are pinned when each assignment is regenerated (see
`remediation-plan.md` tasks P4.9-P4.13). Until then, the existing content
pins `ingress-nginx controller-v1.15.1` as a transitional state.

---

## Teardown

Delete a cluster when finished:

```bash
kind delete cluster
```

Or, for a named multi-node cluster:

```bash
kind delete cluster --name <cluster-name>
```

---

## Version matrix

Every pinned version in this document is verified against the project's official
documentation or releases page. This section records the verification date and
source for each pin so future maintenance can re-verify efficiently.

| Component | Version | Verified against | Date |
|---|---|---|---|
| Kubernetes (exam target) | v1.35 | `github.com/cncf/curriculum` (`CKA_Curriculum_v1.35.pdf`) | 2026-04-18 |
| kind | v0.31.0 | `github.com/kubernetes-sigs/kind/releases` | 2026-04-18 |
| `kindest/node` | v1.35.0 | Default node image for kind v0.31.0 | 2026-04-18 |
| Calico | v3.31.5 | `docs.tigera.io/calico/latest/getting-started/kubernetes/requirements`, `github.com/projectcalico/calico/releases` | 2026-04-18 |
| MetalLB | v0.15.3 | `metallb.io/installation/`, `github.com/metallb/metallb/releases` | 2026-04-18 |
| metrics-server | v0.8.1 | `github.com/kubernetes-sigs/metrics-server` compatibility table | 2026-04-18 |
| Gateway API CRDs | v1.5.1 | `github.com/kubernetes-sigs/gateway-api/releases/tag/v1.5.1` (latest standard-channel release, March 2025) | 2026-04-18 |

When updating a pin, verify against the project's official source and update
both the pin and the verification date in this table. Do not rely on general
knowledge.
