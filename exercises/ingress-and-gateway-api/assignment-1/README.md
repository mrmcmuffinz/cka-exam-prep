# Ingress and Gateway API Assignment 1: Ingress Fundamentals

This is the first of three assignments covering Ingress and Gateway API in Kubernetes. This assignment focuses on Ingress resource structure, controller deployment, path types, host-based routing, and basic Ingress creation. Advanced Ingress patterns and TLS are covered in assignment 2. Gateway API is covered in assignment 3.

## Prerequisites

Before starting this assignment, you should have completed:

- exercises/services/assignment-1 (Service Basics)

You should understand Services, Pods, and how to expose applications within the cluster.

## What You Will Learn

Ingress provides HTTP and HTTPS routing from outside the cluster to services within. Unlike NodePort or LoadBalancer services that expose individual services, Ingress allows you to route traffic to multiple services based on URL paths or hostnames. This assignment teaches you how to deploy an Ingress controller, create Ingress resources for path-based and host-based routing, and troubleshoot common Ingress issues.

## Estimated Time

4 to 6 hours for the tutorial and all 15 exercises.

## Cluster Requirements

This assignment requires a multi-node kind cluster with special configuration for Ingress to work. Port mappings must be configured at cluster creation.

Create the cluster:

```bash
cat <<EOF | KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
EOF
```

Install nginx-ingress controller:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
```

## Difficulty Progression

**Level 1 (Exercises 1.1 to 1.3):** Basic Ingress creation, verifying address assignment, and testing with curl.

**Level 2 (Exercises 2.1 to 2.3):** Path and host routing with multiple paths and hosts.

**Level 3 (Exercises 3.1 to 3.3):** Debugging Ingress issues including backend not found, path mismatches, and no address assigned.

**Level 4 (Exercises 4.1 to 4.3):** Advanced routing with default backends, wildcard hosts, and multiple services.

**Level 5 (Exercises 5.1 to 5.3):** Application scenarios including multi-service applications and designing Ingress strategies.

## Recommended Workflow

1. Read through the tutorial file (ingress-and-gateway-api-tutorial.md) completely before starting.

2. Verify the nginx-ingress controller is running before starting exercises.

3. Test Ingress resources using curl with the Host header to simulate hostname-based routing.

4. When debugging, check that backend services exist and have ready endpoints.

## Files in This Directory

| File | Description |
|------|-------------|
| README.md | This file. Assignment overview and guidance. |
| prompt.md | The generation prompt used to create this assignment. |
| ingress-and-gateway-api-tutorial.md | Step-by-step tutorial teaching Ingress fundamentals. |
| ingress-and-gateway-api-homework.md | 15 progressive exercises across 5 difficulty levels. |
| ingress-and-gateway-api-homework-answers.md | Complete solutions with explanations for all exercises. |
