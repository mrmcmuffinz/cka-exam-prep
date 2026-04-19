# TLS and Certificates Assignment 1: TLS Fundamentals and Certificate Creation

This is the first of three assignments covering TLS and certificates in Kubernetes. This assignment focuses on understanding the Kubernetes PKI structure, certificate anatomy, creating certificates with openssl, and exploring certificate file locations.

## Assignment Overview

Kubernetes uses TLS certificates extensively for secure communication between components. The API server, etcd, kubelet, and other components all use certificates for authentication and encryption. Understanding how to create, view, and validate certificates is essential for cluster administration.

This assignment teaches PKI fundamentals, certificate creation with openssl, and how to navigate the Kubernetes certificate structure.

## Prerequisites

- **exercises/17-17-cluster-lifecycle/assignment-1:** Understanding control plane components

## Estimated Time

4 to 6 hours.

## Cluster Requirements

Single-node kind cluster (sufficient for certificate exploration).

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## Files in This Directory

| File | Description |
|------|-------------|
| README.md | This file |
| prompt.md | Generation prompt |
| tls-and-certificates-tutorial.md | Tutorial covering PKI and certificate creation |
| tls-and-certificates-homework.md | 15 progressive exercises |
| tls-and-certificates-homework-answers.md | Complete solutions |

## What Comes Next

- **exercises/18-18-tls-and-certificates/assignment-2:** Certificates API and kubeconfig
- **exercises/18-18-tls-and-certificates/assignment-3:** Certificate troubleshooting
