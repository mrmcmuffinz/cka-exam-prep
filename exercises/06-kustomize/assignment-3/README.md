# Assignment 3: Overlays and Components

This assignment is the third and final part of the Kustomize series for CKA exam preparation. It covers advanced composition patterns: base and overlay directory structures, environment-specific configurations, reusable components, and Kustomize best practices. The assignment assumes you have completed assignments 1 and 2 and are comfortable with basic kustomization and patches.

## File Overview

The assignment is split across four files. `README.md` (this file) gives you the map. `kustomize-tutorial.md` walks through base/overlay structures, environment overlays, components, and best practices. `kustomize-homework.md` contains 15 progressive exercises organized into five difficulty levels. `kustomize-homework-answers.md` contains complete solutions, common mistakes, and an overlay structure cheat sheet.

## Recommended Workflow

Work through the tutorial first, end to end, in your own cluster. The tutorial uses a dedicated namespace (`tutorial-kustomize`) that will not collide with any exercise namespaces. Once the tutorial is complete, start the homework from Level 1 and work forward. Use the answer key only after you have genuinely attempted an exercise.

## Difficulty Progression

Level 1 exercises cover base and overlay creation. Level 2 exercises focus on environment-specific configurations (dev, prod). Level 3 exercises are debugging scenarios with overlay path and patch issues. Level 4 exercises cover Kustomize components for reusable partial configurations. Level 5 exercises present complete multi-environment application structures.

## Prerequisites

You need a running kind cluster created with rootless nerdctl and kubectl configured to talk to it. You should have completed kustomize/assignment-1 (Fundamentals) and kustomize/assignment-2 (Patches and Transformers).

## Cluster Requirements

This assignment uses a single-node kind cluster. Create one with the following command if you do not already have a cluster running.

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## Estimated Time Commitment

Plan for about 45 to 60 minutes to work through the tutorial attentively. The 15 exercises combined should take roughly four to six hours.

## Scope Boundary

This assignment covers overlays and components. Basic kustomization and patches are assumed from assignments 1 and 2. GitOps workflows are not in CKA scope and are not covered.

## Key Takeaways After Completing This Assignment

By the time you finish all 15 exercises, you should be able to create base kustomizations with shared resources, create overlay kustomizations that customize bases, design environment-specific overlays (dev, staging, prod), use namespace transformers per environment, create reusable components for partial configurations, combine components with overlays, follow Kustomize directory organization best practices, and debug overlay and component issues.
