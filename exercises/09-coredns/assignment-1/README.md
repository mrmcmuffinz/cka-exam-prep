# CoreDNS Assignment 1: DNS Fundamentals

This is the first of three assignments covering DNS in Kubernetes. This assignment focuses on DNS record formats for services and pods, DNS policies, service discovery via DNS, and DNS query mechanics. CoreDNS configuration is covered in assignment 2, and DNS troubleshooting is covered in assignment 3.

## Prerequisites

Before starting this assignment, you should have completed:

- exercises/08-08-services/assignment-1 (ClusterIP Services)

You should be comfortable creating Services and understanding how pods communicate with services using ClusterIP addresses.

## What You Will Learn

This assignment covers the DNS fundamentals that every Kubernetes administrator needs to understand. You will learn how Kubernetes translates service and pod names into IP addresses, how pods are configured to use cluster DNS, and how to query and debug DNS from within pods. These skills are essential for troubleshooting connectivity issues and understanding how service discovery works in Kubernetes.

## Estimated Time

4 to 6 hours for the tutorial and all 15 exercises.

## Cluster Requirements

This assignment requires a multi-node kind cluster. Create it with the following command:

```bash
cat <<EOF | KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
EOF
```

## Difficulty Progression

**Level 1 (Exercises 1.1 to 1.3):** Service DNS lookups using short names, FQDNs, and cross-namespace queries. These exercises build familiarity with the DNS name formats.

**Level 2 (Exercises 2.1 to 2.3):** Pod DNS records and DNS policies. You will examine how pods get their DNS records and how different DNS policies affect name resolution.

**Level 3 (Exercises 3.1 to 3.3):** Debugging DNS query issues. These exercises present broken configurations that you must diagnose and fix.

**Level 4 (Exercises 4.1 to 4.3):** Custom DNS configuration using dnsConfig and dnsPolicy settings. You will configure pods with custom nameservers and search domains.

**Level 5 (Exercises 5.1 to 5.3):** Complex scenarios including cross-namespace service discovery, host network DNS behavior, and designing DNS strategies for multi-tier applications.

## Recommended Workflow

1. Read through the tutorial file (coredns-tutorial.md) completely before starting any exercises. The tutorial teaches the concepts and commands you will need.

2. Work through the exercises in order. Each level builds on skills from previous levels.

3. Try each exercise yourself before looking at the answers. The learning happens when you work through problems, not when you read solutions.

4. After completing an exercise, compare your solution with the answer key (coredns-homework-answers.md) to learn alternative approaches and common mistakes.

5. Clean up resources between exercises to avoid conflicts.

## Files in This Directory

| File | Description |
|------|-------------|
| README.md | This file. Assignment overview and guidance. |
| prompt.md | The generation prompt used to create this assignment. |
| coredns-tutorial.md | Step-by-step tutorial teaching DNS fundamentals. |
| coredns-homework.md | 15 progressive exercises across 5 difficulty levels. |
| coredns-homework-answers.md | Complete solutions with explanations for all exercises. |
