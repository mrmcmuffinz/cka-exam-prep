# Kustomize

**CKA Domain:** Cluster Architecture, Installation & Configuration (25%)
**Competencies covered:** Use Kustomize to install cluster components

---

## Rationale for Number of Assignments

Kustomize's CKA-relevant surface covers kustomization.yaml structure, resource management, transformers (name, label, annotation, image), patches (strategic merge, JSON 6902, inline), overlays for environment-specific configuration, and components for reusable partials. This produces roughly 16-18 distinct subtopics. The material splits naturally into three focused progressions: Kustomize fundamentals with basic transformers, patches with multiple patch types, and overlays with components for advanced composition. Each assignment delivers 5-6 subtopics at depth, building from simple resource aggregation through declarative patching to multi-environment deployment patterns.

---

## Assignment Summary

| Assignment | Description | Prerequisites |
|---|---|---|
| assignment-1 | Kustomize Fundamentals | kustomization.yaml structure and purpose, resource references (resources field), managing directories (bases), common transformers (namePrefix, nameSuffix), commonLabels and commonAnnotations, building and applying kustomizations | None |
| assignment-2 | Patches and Transformers | Strategic merge patches, JSON 6902 patches, inline patches, image transformers, ConfigMap and Secret generators, patch targets and selectors | 06-kustomize/assignment-1 |
| assignment-3 | Overlays and Components | Base and overlay directory structure, environment-specific configurations (dev, staging, prod), components (reusable partial configurations), kustomization composition, namespace transformers, Kustomize best practices | 06-kustomize/assignment-2 |

## Scope Boundaries

This topic covers Kustomize as a manifest management tool. The following related areas are handled by other topics:

- **Helm** (alternative manifest management with templating): covered in `helm/`
- **kubectl apply** (Kustomize output is applied via kubectl): assumed knowledge from the pod series
- **GitOps workflows** (Kustomize used with ArgoCD/Flux): not in CKA scope, excluded

Assignment-1 focuses on basic kustomization structure and transformers. Assignment-2 focuses on patching strategies. Assignment-3 focuses on overlays and advanced composition patterns.

## Cluster Requirements

Single-node kind cluster for all three assignments. Kustomize operates on manifests before they reach the cluster, so no special cluster configuration is needed. Exercises verify the built output by applying it to the kind cluster.

## Recommended Order

1. No strict prerequisites (foundational manifest management skill)
2. Work through assignments 1, 2, 3 sequentially
3. Assignment-2 assumes understanding of basic kustomization structure from assignment-1
4. Assignment-3 assumes understanding of both transformers and patches from assignments 1 and 2
5. Can be generated any time after the Kustomize course section (S13) is complete
