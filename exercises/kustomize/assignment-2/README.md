# Assignment 2: Patches and Transformers

This assignment is the second in the three-part Kustomize series for CKA exam preparation. It covers advanced resource modification techniques: strategic merge patches, JSON 6902 patches, inline patches, image transformers, and ConfigMap/Secret generators. The assignment assumes you have completed assignment-1 (Kustomize Fundamentals) and are comfortable with basic kustomization structure and common transformers.

## File Overview

The assignment is split across four files. `README.md` (this file) gives you the map. `kustomize-tutorial.md` walks through strategic merge patches, JSON 6902 patches, inline patches, image transformers, and ConfigMap/Secret generators. `kustomize-homework.md` contains 15 progressive exercises organized into five difficulty levels. `kustomize-homework-answers.md` contains complete solutions, common mistakes, and a patch types comparison cheat sheet.

## Recommended Workflow

Work through the tutorial first, end to end, in your own cluster. The tutorial uses a dedicated namespace (`tutorial-kustomize`) that will not collide with any exercise namespaces. Once the tutorial is complete, start the homework from Level 1 and work forward. Use the answer key only after you have genuinely attempted an exercise.

## Difficulty Progression

Level 1 exercises cover strategic merge patches: modifying replicas, adding environment variables, and changing resources. Level 2 exercises focus on JSON 6902 patches and image transformers. Level 3 exercises are debugging scenarios with patch issues. Level 4 exercises cover ConfigMap and Secret generators. Level 5 exercises present complex patching scenarios with multiple patches on the same resource.

## Prerequisites

You need a running kind cluster created with rootless nerdctl and kubectl configured to talk to it. You should have completed kustomize/assignment-1 (Kustomize Fundamentals) so that basic kustomization structure is familiar.

## Cluster Requirements

This assignment uses a single-node kind cluster. Create one with the following command if you do not already have a cluster running.

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## Estimated Time Commitment

Plan for about 45 to 60 minutes to work through the tutorial attentively. The 15 exercises combined should take roughly four to six hours.

## Scope Boundary

This assignment covers patches and generators. Basic kustomization, common transformers, and resource references are assumed from assignment-1. Overlays and components are covered in assignment-3.

## Key Takeaways After Completing This Assignment

By the time you finish all 15 exercises, you should be able to create strategic merge patches to modify resource fields, use JSON 6902 patches for precise modifications, write inline patches for simple changes, use image transformers to change container images, generate ConfigMaps from literals and files, generate Secrets from literals and files, understand when to use each patch type, and debug common patch errors.
