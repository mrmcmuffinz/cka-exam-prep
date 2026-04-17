# Kustomize

**CKA Domain:** Cluster Architecture, Installation & Configuration (25%)
**Competencies covered:** Use Kustomize to install cluster components

---

## Why One Assignment

Kustomize's CKA-relevant surface covers the kustomization.yaml structure, resource
management, transformers, patches (three types), overlays, and components. This
produces roughly 10-12 exercise areas. The concepts build on each other linearly
(basic resources, then transformers, then patches, then overlays, then components),
which makes a single progressive assignment the natural structure.

---

## Assignments

| Assignment | Title | Covers | Prerequisites |
|---|---|---|---|
| assignment-1 | Kustomize | kustomization.yaml structure, resource references, managing directories, common transformers (namePrefix, nameSuffix, commonLabels, commonAnnotations), image transformers, patches (strategic merge, JSON 6902, inline), overlays (base + overlay), components | None |

## Scope Boundaries

This topic covers Kustomize as a manifest management tool. The following related
areas are handled by other topics:

- **Helm** (alternative manifest management with templating): covered in `helm/`
- **kubectl apply** (Kustomize output is applied via kubectl): assumed knowledge from the pod series

## Cluster Requirements

Single-node kind cluster. Kustomize operates on manifests before they reach the
cluster, so no special cluster configuration is needed.

## Recommended Order

No strict prerequisites. Can be generated any time after the Kustomize course section
(S13) is complete.
