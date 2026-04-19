# Assignment 1: Helm Basics

This assignment is the first in a three-part Helm series for CKA exam preparation. It covers the foundational concepts of Helm as a package manager for Kubernetes, including chart repositories, installing charts, customizing values with the --set flag, and inspecting charts and releases. The assignment is deliberately scoped to installation and inspection operations only, with lifecycle management (upgrade, rollback) covered in assignment-2 and templates and debugging covered in assignment-3.

## File Overview

The assignment is split across four files. `README.md` (this file) gives you the map. `helm-tutorial.md` walks through Helm architecture and concepts, demonstrates repository management, chart installation, values customization, and chart inspection commands. `helm-homework.md` contains 15 progressive exercises organized into five difficulty levels of three exercises each. `helm-homework-answers.md` contains complete solutions, common mistakes, and a Helm commands cheat sheet.

## Recommended Workflow

Work through the tutorial first, end to end, in your own cluster. The tutorial uses a dedicated namespace (`tutorial-helm`) that will not collide with any exercise namespaces. Once the tutorial is complete, start the homework from Level 1 and work forward. Use the answer key only after you have genuinely attempted an exercise.

## Difficulty Progression

Level 1 exercises cover repository management: adding repositories, searching for charts, and updating the repository index. Level 2 exercises focus on chart installation: installing with default values, installing to custom namespaces, and listing releases. Level 3 exercises are debugging scenarios where something has gone wrong with an installation attempt. Level 4 exercises cover values customization using the --set flag for simple and nested values. Level 5 exercises present complex installation scenarios requiring multiple charts and comprehensive configuration.

## Prerequisites

You need a running kind cluster created with rootless nerdctl, kubectl configured to talk to it, and the Helm CLI installed. Verify your setup with `kubectl get nodes` and `helm version` before you start. Internet access is required for repository operations. General Kubernetes familiarity is assumed, but no specific prior assignments are required.

## Installing Helm

If you do not have Helm installed, follow these steps.

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

## Cluster Requirements

This assignment uses a single-node kind cluster. Create one with the following command if you do not already have a cluster running.

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## Estimated Time Commitment

Plan for about 45 to 60 minutes to work through the tutorial attentively. The 15 exercises combined should take roughly four to six hours, with Level 1 and 2 exercises running faster and Level 5 exercises taking the longest.

## Scope Boundary

This assignment covers Helm basics only: architecture, repositories, installation, values with --set, and inspection. Topics covered in later assignments are explicitly excluded. Assignment-2 covers upgrade, rollback, values files, and release history. Assignment-3 covers helm template, hooks, dependencies, and debugging techniques. Do not use helm upgrade or helm rollback in this assignment, as those belong to the next assignment.

## Key Takeaways After Completing This Assignment

By the time you finish all 15 exercises, you should be able to add and manage Helm repositories, search for charts in repositories and on Artifact Hub, install charts with default values or custom values using --set, inspect chart metadata, default values, and README content before installing, list installed releases and check their status, retrieve the manifest and values of a running release, and diagnose common installation failures such as repository not found, chart not found, or release name conflicts.
