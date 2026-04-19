# CoreDNS Assignment 3: DNS Troubleshooting

This is the third of three assignments covering DNS in Kubernetes. This assignment focuses on diagnosing and resolving DNS issues, including resolution failures, CoreDNS problems, policy misconfigurations, and integration issues. DNS fundamentals (assignment 1) and CoreDNS configuration (assignment 2) are assumed knowledge.

## Prerequisites

Before starting this assignment, you should have completed:

- exercises/09-09-coredns/assignment-1 (DNS Fundamentals)
- exercises/09-09-coredns/assignment-2 (CoreDNS Configuration)

You should understand DNS record formats, DNS policies, CoreDNS Deployment and ConfigMap structure, and Corefile plugins.

## What You Will Learn

This assignment teaches systematic DNS troubleshooting. You will learn how to diagnose resolution failures, identify CoreDNS pod issues, find DNS policy misconfigurations, debug Network Policy impacts on DNS, and trace cross-namespace DNS problems. These skills are essential for resolving connectivity issues in production clusters and are frequently tested on the CKA exam.

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

**Level 1 (Exercises 1.1 to 1.3):** Basic DNS diagnostics. You will test resolution, compare resolv.conf between pods, and check CoreDNS availability.

**Level 2 (Exercises 2.1 to 2.3):** CoreDNS health checks. You will verify pod status, examine logs, and check endpoints.

**Level 3 (Exercises 3.1 to 3.3):** Debugging DNS failures. These exercises present broken configurations that you must diagnose and fix.

**Level 4 (Exercises 4.1 to 4.3):** Complex DNS issues including Network Policy impacts, caching problems, and cross-namespace failures.

**Level 5 (Exercises 5.1 to 5.3):** Multi-factor failures and creating a troubleshooting runbook.

## Recommended Workflow

1. Read through the tutorial file (coredns-tutorial.md) completely before starting any exercises.

2. Work through the exercises in order. Each level builds on skills from previous levels.

3. For debugging exercises, try to identify the root cause before looking at the answers. The diagnostic process is as important as the fix.

4. After completing each exercise, compare your solution with the answer key to learn alternative diagnostic approaches.

## Files in This Directory

| File | Description |
|------|-------------|
| README.md | This file. Assignment overview and guidance. |
| prompt.md | The generation prompt used to create this assignment. |
| coredns-tutorial.md | Step-by-step tutorial teaching DNS troubleshooting methodology. |
| coredns-homework.md | 15 progressive exercises across 5 difficulty levels. |
| coredns-homework-answers.md | Complete solutions with explanations for all exercises. |
