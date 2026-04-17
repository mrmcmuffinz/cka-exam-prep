# Helm

**CKA Domain:** Cluster Architecture, Installation & Configuration (25%)
**Competencies covered:** Use Helm to install cluster components

---

## Why One Assignment

Helm's CKA-relevant surface is focused on chart consumption, not chart authoring.
The exam tests the ability to add repositories, install and upgrade releases, customize
values, roll back, and inspect charts. This produces roughly 8-10 exercise areas, which
fits within a single assignment. Chart development (writing templates, helpers, hooks)
is a CKAD topic and is out of scope.

---

## Assignments

| Assignment | Title | Covers | Prerequisites |
|---|---|---|---|
| assignment-1 | Helm | Helm architecture, chart repositories (add, search, update), installing charts (helm install, --set, -f values.yaml), upgrading releases, rolling back, release lifecycle (list, history, uninstall), inspecting charts (show, template) | None |

## Scope Boundaries

This topic covers Helm as a chart consumer. The following related areas are handled
by other topics:

- **Kustomize** (alternative manifest management): covered in `kustomize/`
- **Operators installed via Helm**: covered in `crds-and-operators/`
- **Deployment rollouts** (Helm manages Deployments, but rollout mechanics are separate): covered in `pods/assignment-7`

## Cluster Requirements

Single-node kind cluster. Helm operates against the cluster API server and does not
require multi-node configuration.

## Recommended Order

No strict prerequisites. Can be generated any time after the Helm course section (S12)
is complete.
