# Ingress and Gateway API Assignment 3: Gateway API

This is the third of three assignments covering Ingress and Gateway API. This assignment focuses on Gateway API resources (GatewayClass, Gateway, HTTPRoute), comparing Gateway API to Ingress, traffic routing with HTTPRoute, and Gateway API troubleshooting. Ingress fundamentals are assumed from assignments 1 and 2.

## Prerequisites

- exercises/ingress-and-gateway-api/assignment-1 (Ingress Fundamentals)
- exercises/ingress-and-gateway-api/assignment-2 (Advanced Ingress and TLS)

## What You Will Learn

Gateway API is the next generation of Kubernetes ingress routing. It provides more expressiveness, better role separation, and improved multi-tenancy compared to Ingress. You will learn the Gateway API resource model, how to configure GatewayClass, Gateway, and HTTPRoute resources, and how to migrate from Ingress to Gateway API.

## Estimated Time

4 to 6 hours for the tutorial and all 15 exercises.

## Cluster Requirements

Kind cluster with Gateway API CRDs and a Gateway controller installed.

## Difficulty Progression

**Level 1:** Gateway API basics including listing GatewayClasses and creating simple routes.

**Level 2:** HTTPRoute routing with paths, headers, and multiple backends.

**Level 3:** Debugging Gateway API issues.

**Level 4:** Advanced routing with traffic splitting and TLS.

**Level 5:** Migration from Ingress and architecture design.

## Files in This Directory

| File | Description |
|------|-------------|
| README.md | This file. Assignment overview. |
| prompt.md | Generation prompt. |
| ingress-and-gateway-api-tutorial.md | Tutorial on Gateway API. |
| ingress-and-gateway-api-homework.md | 15 exercises. |
| ingress-and-gateway-api-homework-answers.md | Solutions. |
