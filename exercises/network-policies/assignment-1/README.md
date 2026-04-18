# Network Policies Assignment 1: NetworkPolicy Fundamentals

This is the first of three assignments covering Network Policies in Kubernetes. This assignment focuses on the NetworkPolicy spec structure, podSelector mechanics, basic ingress and egress rules within a namespace, and port-level filtering. Advanced selectors (namespaceSelector, ipBlock) are covered in assignment 2. Network Policy debugging is covered in assignment 3.

## Prerequisites

Before starting this assignment, you should have completed:

- exercises/services/assignment-1 (Service Basics)

You should understand Services, Pods, and basic Kubernetes networking concepts.

## What You Will Learn

Network Policies provide firewall-like controls for pod-to-pod communication. By default, all pods can communicate with all other pods. Network Policies let you restrict this, implementing security boundaries and microsegmentation. This assignment teaches you how to create policies that control which pods can send traffic to and receive traffic from other pods, with filtering by port and protocol.

## Estimated Time

4 to 6 hours for the tutorial and all 15 exercises.

## Cluster Requirements

This assignment requires a multi-node kind cluster with Calico CNI. The default kind CNI (kindnet) does NOT support NetworkPolicy enforcement. You must create a cluster with the default CNI disabled and then install Calico.

Create the cluster:

```bash
cat <<EOF | KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
nodes:
- role: control-plane
- role: worker
- role: worker
EOF
```

Install Calico:

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
```

Wait for Calico pods to be ready:

```bash
kubectl wait --for=condition=Ready pods -l k8s-app=calico-node -n kube-system --timeout=120s
```

## Difficulty Progression

**Level 1 (Exercises 1.1 to 1.3):** Basic policy creation. You will create policies allowing specific pod ingress and egress, and verify with connectivity tests.

**Level 2 (Exercises 2.1 to 2.3):** Pod selection and rules. You will work with label-based pod selection, multiple from/to entries, and port filtering.

**Level 3 (Exercises 3.1 to 3.3):** Debugging policy effects. These exercises present policies that are too restrictive or incorrectly configured.

**Level 4 (Exercises 4.1 to 4.3):** Combined rules. You will configure policies with both ingress and egress, multiple ports, and named ports.

**Level 5 (Exercises 5.1 to 5.3):** Application scenarios. You will implement policies for multi-tier applications and debug complex policy interactions.

## Recommended Workflow

1. Read through the tutorial file (network-policies-tutorial.md) completely before starting any exercises. The tutorial includes Calico installation instructions.

2. Work through the exercises in order. Each level builds on skills from previous levels.

3. Always test connectivity both before and after applying policies to understand what changed.

4. Remember that pods not matched by any NetworkPolicy allow all traffic. The policy only affects pods it selects.

5. Compare your solutions with the answer key after attempting each exercise.

## Files in This Directory

| File | Description |
|------|-------------|
| README.md | This file. Assignment overview and guidance. |
| prompt.md | The generation prompt used to create this assignment. |
| network-policies-tutorial.md | Step-by-step tutorial teaching NetworkPolicy fundamentals. |
| network-policies-homework.md | 15 progressive exercises across 5 difficulty levels. |
| network-policies-homework-answers.md | Complete solutions with explanations for all exercises. |
