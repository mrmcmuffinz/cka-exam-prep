# Services Assignment 2: External Service Types

This is the second of three assignments covering Kubernetes Services. This assignment focuses on external service types: NodePort, LoadBalancer, ExternalName, and services without selectors that use manual endpoints.

## Assignment Overview

While ClusterIP services provide internal cluster communication, external service types enable access from outside the cluster and integration with external resources. NodePort exposes services on a static port across all nodes. LoadBalancer provisions external load balancers in cloud environments. ExternalName creates DNS aliases for external services. Services without selectors allow manual endpoint management for external backends.

This assignment builds on the ClusterIP fundamentals from assignment-1 and prepares you for advanced service patterns and troubleshooting in assignment-3.

## Prerequisites

Before starting this assignment, you should have completed:

- **exercises/services/assignment-1 (Service Fundamentals):** You need to understand ClusterIP services, selectors, endpoints, and service discovery

You should be comfortable with creating services both imperatively and declaratively.

## Estimated Time

Plan for 4 to 6 hours to complete this assignment:
- Tutorial: 1.5 to 2 hours
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

### metallb Setup

If you did not install metallb during assignment-1, install it now:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.3/config/manifests/metallb-native.yaml

kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s

# Get the kind network IP range (adjust addresses based on your network)
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

- **Level 1 (Exercises 1.1 to 1.3):** NodePort service creation with automatic and manual port allocation, accessing via node IPs
- **Level 2 (Exercises 2.1 to 2.3):** LoadBalancer services with metallb, ExternalName services, comparing service types
- **Level 3 (Exercises 3.1 to 3.3):** Debugging external service issues (LoadBalancer pending, NodePort not accessible, ExternalName not resolving)
- **Level 4 (Exercises 4.1 to 4.3):** Services without selectors, manual Endpoints resources, updating endpoints
- **Level 5 (Exercises 5.1 to 5.3):** External database integration, service type migration, external access strategy design

## Recommended Workflow

1. Read through the tutorial file (services-tutorial.md) and work through each section hands-on
2. Complete the homework exercises (services-homework.md) without looking at the answers
3. Compare your solutions with the answer key (services-homework-answers.md)
4. Review the common mistakes section
5. Re-attempt any exercises where your approach differed significantly

## Files in This Directory

| File | Description |
|------|-------------|
| README.md | This file, providing assignment overview and setup instructions |
| prompt.md | The generation prompt used to create this assignment (for reference) |
| services-tutorial.md | Step-by-step tutorial covering external service types |
| services-homework.md | 15 progressive exercises organized by difficulty level |
| services-homework-answers.md | Complete solutions with explanations and common mistakes |

## What Comes Next

After completing this assignment, continue with:

- **exercises/services/assignment-3 (Service Patterns and Troubleshooting):** Multi-port services, session affinity, traffic policies, and systematic troubleshooting
- **exercises/ingress-and-gateway-api/assignment-1:** L7 routing to services with Ingress
