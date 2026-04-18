# Control Plane Troubleshooting Tutorial

This tutorial covers troubleshooting Kubernetes control plane components. You will learn to diagnose API server, scheduler, controller manager, and etcd issues using logs, static pod manifests, and certificate verification.

## Prerequisites

Multi-node kind cluster with kubectl access.

```bash
kubectl get nodes
```

## Part 1: Control Plane Architecture

The Kubernetes control plane consists of: kube-apiserver (API gateway for all operations), kube-scheduler (assigns pods to nodes), kube-controller-manager (runs controllers like Deployment, ReplicaSet), and etcd (cluster state storage).

In kubeadm clusters, these run as static pods on control plane nodes. Manifests are in /etc/kubernetes/manifests/. Changes to these files cause kubelet to restart the component automatically.

## Part 2: Checking Component Health

### Component Status

Check control plane pods in kube-system.

```bash
kubectl get pods -n kube-system
```

Look for kube-apiserver, kube-scheduler, kube-controller-manager, and etcd pods.

### Component Logs

View logs for control plane components.

```bash
kubectl logs -n kube-system kube-apiserver-<node>
kubectl logs -n kube-system kube-scheduler-<node>
kubectl logs -n kube-system kube-controller-manager-<node>
kubectl logs -n kube-system etcd-<node>
```

### When kubectl Does Not Work

If the API server is down, kubectl will not work. Access the control plane node directly.

```bash
# For kind clusters
docker exec -it kind-control-plane bash

# Then use crictl to check containers
crictl ps
crictl logs <container-id>
```

## Part 3: Static Pod Manifests

Static pods are defined in /etc/kubernetes/manifests/. The kubelet watches this directory and manages these pods directly.

### Accessing Manifests (Kind)

```bash
docker exec -it kind-control-plane ls /etc/kubernetes/manifests/
```

You will see: kube-apiserver.yaml, kube-scheduler.yaml, kube-controller-manager.yaml, etcd.yaml.

### Common Manifest Issues

YAML syntax errors, wrong image tags, incorrect volume mounts, missing or wrong command arguments, and certificate path errors.

### Debugging Manifest Changes

After editing a manifest, kubelet automatically restarts the pod. If the pod fails to start, check.

```bash
# On the control plane node
journalctl -u kubelet | tail -50
crictl ps -a
crictl logs <container-id>
```

## Part 4: Certificate Verification

Control plane components use certificates for authentication and TLS.

### Checking Certificate Expiration

```bash
kubeadm certs check-expiration
```

### Viewing Certificate Details

```bash
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout
```

Check: Subject, Issuer, Not Before, Not After, Subject Alternative Names.

### Common Certificate Issues

Expired certificates, wrong CA, missing SANs for API server, certificate/key mismatch.

## Part 5: API Server Issues

### Symptoms

kubectl commands fail with connection errors. API server pod not running.

### Common Causes

Certificate expired or misconfigured, etcd connection failed, port conflict, manifest syntax error.

### Diagnosis

```bash
# Check if API server container is running
docker exec kind-control-plane crictl ps | grep kube-apiserver

# Check logs
docker exec kind-control-plane crictl logs <api-server-container-id>
```

## Part 6: Scheduler Issues

### Symptoms

Pods stay in Pending state (not scheduled). kubectl get events shows "No nodes available".

### Common Causes

Scheduler not running, scheduler misconfigured, all nodes tainted.

### Diagnosis

```bash
kubectl get pods -n kube-system | grep scheduler
kubectl logs -n kube-system kube-scheduler-<node>
```

## Part 7: Controller Manager Issues

### Symptoms

Deployments not creating ReplicaSets. Services not getting endpoints. Resources not reconciling.

### Common Causes

Controller manager not running, RBAC issues, leader election problems.

### Diagnosis

```bash
kubectl get pods -n kube-system | grep controller-manager
kubectl logs -n kube-system kube-controller-manager-<node>
```

## Part 8: etcd Issues

### Symptoms

API server cannot connect to etcd. Cluster state lost or corrupted.

### Common Causes

etcd not running, connectivity issues, disk full, quorum loss.

### Diagnosis

```bash
kubectl get pods -n kube-system | grep etcd
kubectl logs -n kube-system etcd-<node>
```

## Reference Commands

| Task | Command |
|------|---------|
| Control plane pods | `kubectl get pods -n kube-system` |
| Component logs | `kubectl logs -n kube-system <pod>` |
| Access kind control plane | `docker exec -it kind-control-plane bash` |
| Check containers (on node) | `crictl ps` |
| Container logs (on node) | `crictl logs <id>` |
| Kubelet logs | `journalctl -u kubelet` |
| Certificate expiration | `kubeadm certs check-expiration` |
| View certificate | `openssl x509 -in <cert> -text -noout` |
