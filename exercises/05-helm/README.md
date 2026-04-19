# Helm

**CKA Domain:** Cluster Architecture, Installation & Configuration (25%)
**Competencies covered:** Use Helm to install cluster components

---

## Rationale for Number of Assignments

Helm's CKA-relevant surface focuses on chart consumption (not authoring): repository management, chart installation with values customization, release lifecycle operations, and debugging workflows. This produces roughly 13-15 distinct subtopics. The material splits naturally into three focused progressions: Helm basics with chart discovery and installation, lifecycle management with upgrades and rollbacks, and template rendering with debugging strategies. Each assignment delivers 4-5 subtopics at depth, building from initial chart consumption through operational maintenance to advanced troubleshooting.

---

## Assignment Summary

| Assignment | Description | Prerequisites |
|---|---|---|
| assignment-1 | Helm Basics | Helm architecture and concepts (charts, releases, revisions), chart repositories (add, search, update, list), installing charts (helm install, release naming), values customization (--set flag), inspecting charts (helm show) | None |
| assignment-2 | Helm Lifecycle Management | Upgrading releases (helm upgrade), values files (-f values.yaml), reusing values (--reuse-values vs --reset-values), rolling back releases (helm rollback), release history (helm history), uninstalling releases (helm uninstall) | helm/assignment-1 |
| assignment-3 | Helm Templates and Debugging | Template rendering (helm template), debugging chart installations, Helm hooks (pre-install, post-install), chart dependencies, Helm secrets and sensitive data, Helm best practices | helm/assignment-2 |

## Scope Boundaries

This topic covers Helm as a chart consumer. The following related areas are handled by other topics:

- **Kustomize** (alternative manifest management approach): covered in `kustomize/`
- **Operators installed via Helm** (using Helm to install operators): covered in `crds-and-operators/`
- **Deployment rollouts** (Helm manages Deployments, but rollout mechanics are separate): covered in `pods/assignment-7`
- **Chart authoring** (writing chart templates, helpers, hooks): not in CKA scope, excluded from all assignments

Assignment-1 focuses on chart discovery and basic installation. Assignment-2 focuses on release lifecycle operations. Assignment-3 focuses on debugging and advanced patterns.

## Cluster Requirements

Single-node kind cluster for all three assignments. Helm operates against the cluster API server and does not require multi-node configuration. No special cluster setup needed.

## Recommended Order

1. No strict prerequisites (foundational manifest management skill)
2. Work through assignments 1, 2, 3 sequentially
3. Assignment-2 assumes understanding of basic Helm concepts from assignment-1
4. Assignment-3 assumes understanding of release lifecycle from assignment-2
5. Can be generated any time after the Helm course section (S12) is complete
