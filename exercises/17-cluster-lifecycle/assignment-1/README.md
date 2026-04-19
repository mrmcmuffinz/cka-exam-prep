# Cluster Lifecycle Assignment 1: Cluster Installation with kubeadm

This is the first of three assignments covering Kubernetes cluster lifecycle management. This assignment focuses on understanding cluster installation using kubeadm, including node prerequisites, the init and join workflows, control plane component verification, and extension interfaces.

## Assignment Overview

Kubeadm is the standard tool for bootstrapping production-ready Kubernetes clusters. Understanding how kubeadm works is essential for the CKA exam, which tests your ability to install, configure, and troubleshoot Kubernetes clusters.

Since we use kind clusters (which abstract away kubeadm operations), this assignment focuses on examining kubeadm artifacts, understanding the workflows conceptually, and verifying cluster health. You will explore static pod manifests, certificate directories, kubelet configuration, and control plane components by executing commands inside kind containers.

## Prerequisites

Before starting this assignment, you should have completed:

- **exercises/01-01-pods/assignment-7 (Workload Controllers):** Understanding Deployments and DaemonSets helps understand control plane components
- **exercises/12-12-rbac/assignment-1 (RBAC namespace-scoped):** Understanding ServiceAccounts and RBAC for verifying permissions

You should be comfortable with basic kubectl operations and understand the Kubernetes control plane architecture.

## Estimated Time

Plan for 4 to 6 hours to complete this assignment:
- Tutorial: 2 hours
- Homework exercises: 2 to 3 hours
- Review and answer comparison: 1 hour

## Cluster Requirements

This assignment requires a multi-node kind cluster (1 control-plane, 2 to 3 workers) to explore node-specific configurations.

Create the cluster:

```bash
cat <<EOF > kind-multi-node.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
EOF

KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster --config kind-multi-node.yaml
```

### Understanding Kind and Kubeadm

Kind (Kubernetes in Docker/nerdctl) uses kubeadm internally to bootstrap clusters. The kind control-plane and worker "nodes" are actually containers that run kubeadm during initialization. This means:

- You can examine kubeadm artifacts inside kind containers
- You cannot run kubeadm init/join yourself (kind manages this)
- Static pod manifests, certificates, and kubelet config are all accessible via exec

Access kind containers:

```bash
# List kind containers
nerdctl ps | grep kind

# Exec into control plane
nerdctl exec -it kind-control-plane /bin/bash

# From inside, explore kubeadm artifacts
ls /etc/kubernetes/
ls /etc/kubernetes/manifests/
ls /etc/kubernetes/pki/
```

## Difficulty Progression

- **Level 1 (Exercises 1.1 to 1.3):** Exploring kubeadm artifacts (static pod manifests, certificate directories, control plane pods)
- **Level 2 (Exercises 2.1 to 2.3):** Node verification (kernel modules, sysctl settings, kubelet status, cluster health)
- **Level 3 (Exercises 3.1 to 3.3):** Debugging cluster issues (node not Ready, kubelet not running, CNI not installed)
- **Level 4 (Exercises 4.1 to 4.3):** kubeadm configuration and token management (config files, bootstrap tokens, init phases)
- **Level 5 (Exercises 5.1 to 5.3):** Complex scenarios (workflow tracing, worker node simulation, cluster state documentation)

## Recommended Workflow

1. Read through the tutorial file (cluster-lifecycle-tutorial.md) and work through each section hands-on
2. Complete the homework exercises (cluster-lifecycle-homework.md) without looking at the answers
3. Compare your solutions with the answer key (cluster-lifecycle-homework-answers.md)
4. Review the common mistakes section in the answer key
5. Re-attempt any exercises where your approach differed significantly

## Files in This Directory

| File | Description |
|------|-------------|
| README.md | This file, providing assignment overview and setup instructions |
| prompt.md | The generation prompt used to create this assignment (for reference) |
| cluster-lifecycle-tutorial.md | Step-by-step tutorial covering kubeadm concepts and artifact exploration |
| cluster-lifecycle-homework.md | 15 progressive exercises organized by difficulty level |
| cluster-lifecycle-homework-answers.md | Complete solutions with explanations and common mistakes |

## What Comes Next

After completing this assignment, continue with:

- **exercises/17-17-cluster-lifecycle/assignment-2 (Cluster Upgrades and Maintenance):** Kubeadm upgrade workflows, drain, cordon, uncordon
- **exercises/17-17-cluster-lifecycle/assignment-3 (etcd Operations and HA):** etcd backup/restore, HA control plane concepts
- **exercises/18-18-tls-and-certificates/assignment-1 (TLS Fundamentals):** Certificate creation and management
