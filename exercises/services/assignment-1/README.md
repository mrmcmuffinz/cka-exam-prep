# Services Assignment 1: Service Fundamentals and Discovery

This is the first of three assignments covering Kubernetes Services. This assignment focuses on how Services expose applications, the different service types and their mechanics, service discovery mechanisms, and debugging common service issues.

## Assignment Overview

Services provide stable network endpoints for accessing pod-based applications. While pods are ephemeral and their IP addresses change as they are created and destroyed, Services provide a consistent way to access workloads. This assignment builds the foundational understanding of how Services work, how pods discover them, and how to verify and troubleshoot service configuration.

The assignment covers ClusterIP, NodePort, LoadBalancer, ExternalName, and headless services. You will learn how to create services using both imperative and declarative approaches, understand the relationship between service ports and container ports, and master service discovery through DNS and environment variables.

## Prerequisites

Before starting this assignment, you should have completed:

- **exercises/pods/assignment-7 (Workload Controllers):** You need to understand Deployments, which serve as service backends throughout this assignment
- **exercises/pods/assignment-3 (Pod Health and Observability):** Understanding readiness probes is necessary because Services only include Ready pods in their endpoints

You should also be comfortable with basic kubectl operations and have a conceptual understanding of networking (IP addresses, ports, TCP/UDP).

## Estimated Time

Plan for 4 to 6 hours to complete this assignment:
- Tutorial: 2 hours
- Homework exercises: 2 to 3 hours
- Review and answer comparison: 1 hour

## Cluster Requirements

This assignment requires a multi-node kind cluster (1 control-plane, 3 workers) to demonstrate NodePort behavior across multiple nodes. LoadBalancer exercises require metallb for external IP assignment.

Create the cluster if you do not already have one:

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

### metallb Setup for LoadBalancer Services

Kind does not natively support LoadBalancer services. Install metallb to enable external IP assignment:

```bash
# Install metallb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.3/config/manifests/metallb-native.yaml

# Wait for metallb to be ready
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s

# Get the kind network IP range
# For nerdctl, check the network range
nerdctl network inspect kind | grep -i subnet

# Create IP address pool (adjust the range based on your kind network)
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

## Difficulty Progression

- **Level 1 (Exercises 1.1 to 1.3):** Basic ClusterIP service creation using imperative and declarative approaches, service verification, and connectivity testing
- **Level 2 (Exercises 2.1 to 2.3):** NodePort, LoadBalancer, headless, and ExternalName services, plus service discovery via DNS and environment variables
- **Level 3 (Exercises 3.1 to 3.3):** Debugging exercises with broken service configurations (selector mismatches, port errors, readiness issues)
- **Level 4 (Exercises 4.1 to 4.3):** Multi-port services, session affinity, traffic policies, and services without selectors
- **Level 5 (Exercises 5.1 to 5.3):** Complex multi-tier applications, multi-failure debugging, and service migration scenarios

## Recommended Workflow

1. Read through the tutorial file (services-tutorial.md) and work through each section hands-on
2. Complete the homework exercises (services-homework.md) without looking at the answers
3. Compare your solutions with the answer key (services-homework-answers.md)
4. Review the common mistakes section in the answer key
5. Re-attempt any exercises where your approach differed significantly

## Files in This Directory

| File | Description |
|------|-------------|
| README.md | This file, providing assignment overview and setup instructions |
| prompt.md | The generation prompt used to create this assignment (for reference) |
| services-tutorial.md | Step-by-step tutorial covering all service types and discovery mechanisms |
| services-homework.md | 15 progressive exercises organized by difficulty level |
| services-homework-answers.md | Complete solutions with explanations and common mistakes |

## What Comes Next

After completing this assignment, continue with:

- **exercises/services/assignment-2 (External Service Types):** Deep dive into NodePort, LoadBalancer, ExternalName, and manual endpoints
- **exercises/services/assignment-3 (Service Patterns and Troubleshooting):** Multi-port services, session affinity, traffic policies, and systematic troubleshooting
- **exercises/coredns/assignment-1:** DNS configuration and debugging
- **exercises/network-policies/assignment-1:** Filtering traffic to services with Network Policies
