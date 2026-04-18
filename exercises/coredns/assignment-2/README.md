# CoreDNS Assignment 2: CoreDNS Configuration

This is the second of three assignments covering DNS in Kubernetes. This assignment focuses on the CoreDNS Deployment, ConfigMap, Corefile structure, plugins, and configuration customization. DNS fundamentals are assumed knowledge from assignment 1. DNS troubleshooting is covered in assignment 3.

## Prerequisites

Before starting this assignment, you should have completed:

- exercises/coredns/assignment-1 (DNS Fundamentals)

You should understand service and pod DNS formats, DNS policies, and how to query DNS from within pods.

## What You Will Learn

This assignment teaches you how CoreDNS is deployed and configured in Kubernetes. You will learn how to examine the CoreDNS Deployment and ConfigMap, understand the Corefile structure and available plugins, customize CoreDNS for specific requirements like stub domains and custom DNS entries, and configure logging for debugging. These skills are essential for cluster administration and troubleshooting DNS issues at the infrastructure level.

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

## Important Warning

Editing the CoreDNS ConfigMap incorrectly can break DNS for the entire cluster. Always verify your changes work before considering them complete, and be prepared to revert if DNS stops functioning. The tutorial and exercises include verification steps to catch problems early.

## Difficulty Progression

**Level 1 (Exercises 1.1 to 1.3):** Exploring CoreDNS components. You will list pods, examine the ConfigMap, and identify plugins in the Corefile.

**Level 2 (Exercises 2.1 to 2.3):** Understanding configuration basics. You will examine the kubernetes and forward plugins and view CoreDNS logs.

**Level 3 (Exercises 3.1 to 3.3):** Debugging configuration issues. These exercises present broken CoreDNS configurations that you must diagnose and fix.

**Level 4 (Exercises 4.1 to 4.3):** Customizing CoreDNS configuration. You will add custom DNS entries, configure logging, and modify cache settings.

**Level 5 (Exercises 5.1 to 5.3):** Complex scenarios including stub domains for enterprise DNS, troubleshooting custom configurations, and designing CoreDNS configurations for requirements.

## Recommended Workflow

1. Read through the tutorial file (coredns-tutorial.md) completely before starting any exercises.

2. Work through the exercises in order. Each level builds on skills from previous levels.

3. Before editing the CoreDNS ConfigMap, always make a backup so you can restore if needed.

4. After any ConfigMap change, verify DNS still works by testing a simple lookup.

5. Compare your solutions with the answer key (coredns-homework-answers.md) after attempting each exercise.

## Files in This Directory

| File | Description |
|------|-------------|
| README.md | This file. Assignment overview and guidance. |
| prompt.md | The generation prompt used to create this assignment. |
| coredns-tutorial.md | Step-by-step tutorial teaching CoreDNS configuration. |
| coredns-homework.md | 15 progressive exercises across 5 difficulty levels. |
| coredns-homework-answers.md | Complete solutions with explanations for all exercises. |
