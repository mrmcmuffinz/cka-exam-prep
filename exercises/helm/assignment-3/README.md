# Assignment 3: Helm Templates and Debugging

This assignment is the third and final part of the Helm series for CKA exam preparation. It covers advanced topics: template rendering with `helm template`, debugging installations and upgrades, understanding Helm hooks, managing chart dependencies, and following Helm best practices. The assignment assumes you have completed assignments 1 and 2 and are comfortable with installation, values customization, and lifecycle management.

## File Overview

The assignment is split across four files. `README.md` (this file) gives you the map. `helm-tutorial.md` walks through template rendering, debugging techniques, hooks, dependencies, and best practices. `helm-homework.md` contains 15 progressive exercises organized into five difficulty levels. `helm-homework-answers.md` contains complete solutions, common mistakes, and a debugging commands cheat sheet.

## Recommended Workflow

Work through the tutorial first, end to end, in your own cluster. The tutorial uses a dedicated namespace (`tutorial-helm`) that will not collide with any exercise namespaces. Once the tutorial is complete, start the homework from Level 1 and work forward. Use the answer key only after you have genuinely attempted an exercise.

## Difficulty Progression

Level 1 exercises cover template rendering: using helm template to render charts locally and comparing outputs. Level 2 exercises focus on debugging: using --debug and --dry-run to diagnose issues. Level 3 exercises present debugging scenarios with template, hook, or dependency problems. Level 4 exercises cover advanced features: hooks, dependencies, and secrets handling. Level 5 exercises present production scenarios requiring comprehensive debugging and best practice audits.

## Prerequisites

You need a running kind cluster created with rootless nerdctl, kubectl configured to talk to it, and the Helm CLI installed. You should have completed helm/assignment-1 (Helm Basics) and helm/assignment-2 (Lifecycle Management) so that installation, values, and lifecycle operations are familiar.

## Cluster Requirements

This assignment uses a single-node kind cluster. Create one with the following command if you do not already have a cluster running.

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## Estimated Time Commitment

Plan for about 45 to 60 minutes to work through the tutorial attentively. The 15 exercises combined should take roughly four to six hours.

## Scope Boundary

This assignment covers templates, debugging, hooks, and dependencies. Installation basics, values customization, and lifecycle management are assumed from assignments 1 and 2. Chart authoring (creating your own charts from scratch) is not in CKA scope and is not covered.

## Key Takeaways After Completing This Assignment

By the time you finish all 15 exercises, you should be able to render chart templates locally without installing, validate rendered output before deployment, use --debug and --dry-run to diagnose problems, understand Helm hook types and their use cases, manage chart dependencies, handle secrets appropriately in Helm workflows, apply Helm best practices for production deployments, and debug complex chart installations effectively.
