# Services Assignment 3: Service Patterns and Troubleshooting

This is the third and final assignment in the Services series. This assignment covers advanced service patterns (multi-port services, session affinity, traffic policies) and systematic service troubleshooting techniques.

## Assignment Overview

Production services often require more than basic connectivity. Multi-port services expose multiple protocols or endpoints through a single service. Session affinity ensures clients connect to the same backend for stateful applications. Traffic policies control how traffic is distributed and whether source IPs are preserved.

This assignment also teaches systematic troubleshooting skills for diagnosing and resolving service issues. You will learn to trace problems from symptoms through service configuration, selectors, endpoints, and pod readiness.

## Prerequisites

Before starting this assignment, you should have completed:

- **exercises/services/assignment-1 (Service Fundamentals):** ClusterIP services, selectors, endpoints, service discovery
- **exercises/services/assignment-2 (External Service Types):** NodePort, LoadBalancer, ExternalName, manual endpoints

You should be comfortable creating and debugging basic service configurations.

## Estimated Time

Plan for 4 to 6 hours to complete this assignment:
- Tutorial: 1.5 to 2 hours
- Homework exercises: 2 to 3 hours
- Review and answer comparison: 1 hour

## Cluster Requirements

This assignment requires a multi-node kind cluster (1 control-plane, 3 workers) to demonstrate traffic policies across nodes.

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

## Difficulty Progression

- **Level 1 (Exercises 1.1 to 1.3):** Multi-port services with named ports, accessing different ports, configuring protocols
- **Level 2 (Exercises 2.1 to 2.3):** Session affinity configuration, external traffic policies, source IP preservation
- **Level 3 (Exercises 3.1 to 3.3):** Debugging service issues (empty endpoints, selector mismatches, wrong targetPort)
- **Level 4 (Exercises 4.1 to 4.3):** Advanced troubleshooting (readiness affecting endpoints, named port references, traffic policy effects)
- **Level 5 (Exercises 5.1 to 5.3):** Complex multi-service applications, multi-failure debugging, resilient service design

## Recommended Workflow

1. Read through the tutorial file (services-tutorial.md) and work through each section hands-on
2. Complete the homework exercises (services-homework.md) without looking at the answers
3. Compare your solutions with the answer key (services-homework-answers.md)
4. Study the service troubleshooting flowchart in the answer key
5. Re-attempt any exercises where your approach differed significantly

## Files in This Directory

| File | Description |
|------|-------------|
| README.md | This file, providing assignment overview and setup instructions |
| prompt.md | The generation prompt used to create this assignment (for reference) |
| services-tutorial.md | Step-by-step tutorial covering advanced patterns and troubleshooting |
| services-homework.md | 15 progressive exercises organized by difficulty level |
| services-homework-answers.md | Complete solutions with explanations and troubleshooting flowchart |

## What Comes Next

After completing this assignment, you have finished the Services series. Continue with:

- **exercises/coredns/assignment-1:** DNS configuration and debugging for service discovery
- **exercises/network-policies/assignment-1:** Filtering traffic to services with Network Policies
- **exercises/troubleshooting/assignment-4:** Network troubleshooting, including cross-domain service issues
