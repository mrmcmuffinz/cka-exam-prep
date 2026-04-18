# Cluster Lifecycle Assignment 2: Cluster Upgrades and Maintenance

This is the second of three assignments covering Kubernetes cluster lifecycle management. This assignment focuses on cluster version upgrades using kubeadm, node maintenance operations (drain, cordon, uncordon), and post-upgrade verification.

## Assignment Overview

Kubernetes clusters require regular upgrades to receive security patches, bug fixes, and new features. The upgrade process must be performed carefully to maintain cluster availability. This assignment teaches the kubeadm upgrade workflow, node maintenance operations, and how to verify successful upgrades.

Since kind clusters cannot be upgraded in place, hands-on exercises focus on drain, cordon, and uncordon operations, while upgrade workflows are covered conceptually with documentation exercises.

## Prerequisites

Before starting this assignment, you should have completed:

- **exercises/cluster-lifecycle/assignment-1 (Cluster Installation):** Understanding kubeadm artifacts and control plane components

## Estimated Time

Plan for 4 to 6 hours to complete this assignment.

## Cluster Requirements

Multi-node kind cluster (1 control-plane, 3 workers).

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

## Difficulty Progression

- **Level 1:** Version information and upgrade planning
- **Level 2:** Node maintenance operations (cordon, drain, uncordon)
- **Level 3:** Debugging drain issues
- **Level 4:** Upgrade workflow simulation
- **Level 5:** Complex maintenance scenarios

## Files in This Directory

| File | Description |
|------|-------------|
| README.md | This file |
| prompt.md | Generation prompt |
| cluster-lifecycle-tutorial.md | Tutorial covering upgrade workflows and maintenance |
| cluster-lifecycle-homework.md | 15 progressive exercises |
| cluster-lifecycle-homework-answers.md | Complete solutions |

## What Comes Next

- **exercises/cluster-lifecycle/assignment-3:** etcd operations and HA control plane
- **exercises/troubleshooting/assignment-2:** Control plane troubleshooting
