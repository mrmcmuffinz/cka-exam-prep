# Assignment 2: Control Plane Troubleshooting

This assignment is the second in the four-part troubleshooting series for CKA exam preparation. It focuses on control plane component failures: API server issues, scheduler failures, controller manager problems, and etcd connectivity. This requires understanding Kubernetes architecture and static pod manifests.

## File Overview

The assignment is split across four files. `README.md` (this file) provides the overview. `troubleshooting-tutorial.md` covers control plane architecture, static pod debugging, certificate verification, and component log analysis. `troubleshooting-homework.md` contains 15 debugging exercises. `troubleshooting-homework-answers.md` contains solutions with diagnostic workflows.

## Difficulty Progression

Level 1: Component status verification. Level 2: Static pod manifest issues. Level 3: Component failures (API server, scheduler, controller manager). Level 4: Certificate issues. Level 5: Complex multi-component scenarios.

## Prerequisites

Completed cluster-lifecycle and tls-and-certificates assignments. Multi-node kind cluster.

## Cluster Requirements

Multi-node kind cluster with access to control plane container via nerdctl exec.

## Kind Cluster Note

Kind runs control plane components as containers within the kind node container. Some exercises require accessing the control plane node via `docker exec kind-control-plane` (or `nerdctl exec`). This is different from bare-metal clusters where you would SSH to nodes.

## Estimated Time

Tutorial: 45-60 minutes. Exercises: 6-8 hours.

## Key Takeaways

Verify control plane component health, debug static pod manifest errors, diagnose API server, scheduler, and controller manager failures, verify certificates and identify expiration issues, and analyze control plane component logs.
