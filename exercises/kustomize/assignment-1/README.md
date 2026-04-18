# Assignment 1: Kustomize Fundamentals

This assignment is the first in a three-part Kustomize series for CKA exam preparation. It covers the foundational concepts of Kustomize as a template-free configuration management tool for Kubernetes. You will learn the kustomization.yaml structure, resource references, common transformers (namePrefix, nameSuffix, commonLabels, commonAnnotations, namespace), and how to build and apply kustomizations. Patches are covered in assignment-2, and overlays with components are covered in assignment-3.

## File Overview

The assignment is split across four files. `README.md` (this file) gives you the map. `kustomize-tutorial.md` walks through Kustomize philosophy, kustomization.yaml structure, resource references, common transformers, and building kustomizations. `kustomize-homework.md` contains 15 progressive exercises organized into five difficulty levels. `kustomize-homework-answers.md` contains complete solutions, common mistakes, and a Kustomize commands cheat sheet.

## Recommended Workflow

Work through the tutorial first, end to end, in your own cluster. The tutorial uses a dedicated namespace (`tutorial-kustomize`) that will not collide with any exercise namespaces. Once the tutorial is complete, start the homework from Level 1 and work forward. Use the answer key only after you have genuinely attempted an exercise.

## Difficulty Progression

Level 1 exercises cover basic kustomization: creating kustomization.yaml files, adding resources, and building output. Level 2 exercises focus on common transformers: namePrefix, commonLabels, and namespace settings. Level 3 exercises are debugging scenarios where kustomizations fail to build or apply correctly. Level 4 exercises cover multi-resource kustomizations with multiple transformers. Level 5 exercises present application scenarios requiring complete kustomization structures.

## Prerequisites

You need a running kind cluster created with rootless nerdctl and kubectl configured to talk to it. Kustomize is built into kubectl (kubectl kustomize and kubectl apply -k), so no additional installation is required. General Kubernetes familiarity is assumed, but no specific prior assignments are required.

## Cluster Requirements

This assignment uses a single-node kind cluster. Create one with the following command if you do not already have a cluster running.

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## Estimated Time Commitment

Plan for about 45 to 60 minutes to work through the tutorial attentively. The 15 exercises combined should take roughly four to six hours.

## Scope Boundary

This assignment covers Kustomize fundamentals: kustomization.yaml structure, resource references, and common transformers. Patches (strategic merge and JSON 6902) are covered in assignment-2. Overlays and components are covered in assignment-3. Do not use patches or overlays in this assignment.

## Key Takeaways After Completing This Assignment

By the time you finish all 15 exercises, you should be able to create kustomization.yaml files from scratch, reference resource files in a kustomization, use kubectl kustomize to build and preview output, use kubectl apply -k to build and apply in one step, add prefixes and suffixes to all resource names, add common labels and annotations to all resources, set namespaces for all resources, combine multiple transformers in a single kustomization, and debug common kustomization errors.
