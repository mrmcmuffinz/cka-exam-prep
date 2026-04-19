# Cluster Lifecycle Assignment 3: etcd Operations and High Availability

This is the third and final assignment covering Kubernetes cluster lifecycle management. This assignment focuses on etcd architecture, backup and restore operations, health verification, and HA control plane concepts.

## Assignment Overview

Etcd is the distributed key-value store that holds all Kubernetes cluster state. Understanding etcd operations is critical for disaster recovery. This assignment teaches etcd backup with etcdctl, restore workflows, health verification, and HA topologies.

Since kind runs single-node etcd and does not support HA control planes, exercises focus on hands-on backup operations and conceptual understanding of HA configurations.

## Prerequisites

- **exercises/cluster-lifecycle/assignment-1:** Cluster installation
- **exercises/cluster-lifecycle/assignment-2:** Cluster maintenance

## Estimated Time

4 to 6 hours.

## Cluster Requirements

Multi-node kind cluster (1 control-plane, 3 workers).

## Files in This Directory

| File | Description |
|------|-------------|
| README.md | This file |
| prompt.md | Generation prompt |
| cluster-lifecycle-tutorial.md | Tutorial covering etcd operations and HA |
| cluster-lifecycle-homework.md | 15 progressive exercises |
| cluster-lifecycle-homework-answers.md | Complete solutions |

## What Comes Next

- **exercises/tls-and-certificates/assignment-1:** Certificate management
- **exercises/troubleshooting/assignment-2:** Control plane troubleshooting
