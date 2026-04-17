# Assignment Registry

**Last updated:** 2026-04-17

---

## Purpose

This file tracks every homework assignment in the cka-exam-prep repository: what exists,
what each assignment covers, and what it explicitly defers. The prompt builder consults
this registry before writing any new prompt to prevent scope overlap and to generate
accurate cross-references.

When a new assignment is generated, update this file with its scope summary and
cross-references.

---

## Completed Assignments

### exercises/pods/assignment-1: Pod Fundamentals

**Series:** Pod-focused (1 of 7)
**CKA domain:** Workloads & Scheduling
**Cluster:** Single-node kind

**Covers:**
- Pod spec structure and required fields
- Single-container pod construction (imperative and declarative)
- Multi-container pods (basic mechanics only, not named patterns)
- Container commands and arguments (command vs args, Docker ENTRYPOINT/CMD equivalence)
- Environment variables as literal values
- Environment variables via downward API (fieldRef, resourceFieldRef)
- Restart policy (Always, OnFailure, Never)
- Image pull policy (Always, IfNotPresent, Never)
- Labels and annotations on pods
- Basic init containers (sequential execution, blocking main containers)
- Pod phases and container statuses
- kubectl describe and kubectl logs for pod inspection

**Defers to:**
- Assignment 2: ConfigMaps and Secrets as env vars or volume mounts
- Assignment 3: Probes, lifecycle hooks, terminationGracePeriodSeconds
- Assignment 4: Node selectors, affinity, taints, tolerations, topology spread
- Assignment 5: Resource requests and limits, QoS classes
- Assignment 6: Sidecar, ambassador, adapter patterns, native sidecars
- Assignment 7: ReplicaSets, Deployments, DaemonSets

---

### exercises/pods/assignment-2: Pod Configuration Injection

**Series:** Pod-focused (2 of 7)
**CKA domain:** Workloads & Scheduling
**Cluster:** Single-node kind

**Covers:**
- ConfigMaps (create from literals, files, directories; consume as env vars and volumes)
- Secrets (create, consume, types, base64 encoding)
- Projected volumes (combining ConfigMap, Secret, downward API, serviceAccountToken)
- Downward API (fieldRef, resourceFieldRef as env vars and volume files)
- Immutable ConfigMaps and Secrets

**Defers to:**
- Assignment 3: How probes interact with configuration changes
- Storage assignment: PersistentVolumes (projected volumes are in-memory only)

---

### exercises/pods/assignment-3: Pod Health and Observability

**Series:** Pod-focused (3 of 7)
**CKA domain:** Workloads & Scheduling
**Cluster:** Single-node kind

**Covers:**
- Liveness probes (httpGet, tcpSocket, exec)
- Readiness probes (same three types, effect on service endpoints)
- Startup probes (for slow-starting containers)
- Probe parameters (initialDelaySeconds, periodSeconds, failureThreshold, successThreshold)
- Lifecycle hooks (postStart, preStop)
- terminationGracePeriodSeconds and SIGTERM/SIGKILL behavior
- Diagnostic workflow for unhealthy pods (events, logs, describe)

**Defers to:**
- Assignment 4: How probes interact with scheduling decisions
- Services assignment: How readiness affects service endpoint membership

---

### exercises/pods/assignment-4: Pod Scheduling and Placement

**Series:** Pod-focused (4 of 7)
**CKA domain:** Workloads & Scheduling
**Cluster:** Multi-node kind (1 control-plane, 3 workers, introduced in this assignment)

**Covers:**
- nodeSelector
- Node affinity (requiredDuringSchedulingIgnoredDuringExecution, preferredDuringSchedulingIgnoredDuringExecution)
- Pod affinity and anti-affinity
- Taints and tolerations (NoSchedule, PreferNoSchedule, NoExecute)
- Topology spread constraints
- Priority classes and preemption

**Defers to:**
- Assignment 5: How resource requests interact with scheduling
- Workload Controllers: How DaemonSets bypass normal scheduling

---

### exercises/pods/assignment-5: Pod Resources and QoS

**Series:** Pod-focused (5 of 7)
**CKA domain:** Workloads & Scheduling
**Cluster:** Multi-node kind

**Covers:**
- CPU and memory requests and limits
- QoS class assignment (Guaranteed, Burstable, BestEffort)
- OOMKill behavior and CPU throttling
- LimitRange (default requests/limits per namespace)
- ResourceQuota (aggregate limits per namespace)
- How resource requests affect scheduling decisions

**Defers to:**
- Assignment 7: How Deployment replicas interact with ResourceQuota
- HPA/VPA: Covered within this assignment as part of autoscaling

---

### exercises/pods/assignment-6: Multi-Container Patterns

**Series:** Pod-focused (6 of 7)
**CKA domain:** Workloads & Scheduling
**Cluster:** Multi-node kind

**Covers:**
- Sidecar pattern (log shipping, config reload, TLS proxy)
- Ambassador pattern (proxy for external services)
- Adapter pattern (format conversion, metric normalization)
- Native sidecars (init containers with restartPolicy: Always)
- Shared process namespace (shareProcessNamespace: true)
- Shared volumes between containers (emptyDir for inter-container communication)

**Defers to:**
- Services assignment: How multi-container pods interact with services
- Network Policies: Traffic rules apply at the pod level, not container level

---

### exercises/pods/assignment-7: Workload Controllers

**Series:** Pod-focused (7 of 7)
**CKA domain:** Workloads & Scheduling
**Cluster:** Multi-node kind

**Covers:**
- ReplicaSet spec (replicas, selector, template, selector-matches-template contract)
- ReplicaSet reconciliation, adoption of orphaned pods, scaling
- Deployments (spec, RollingUpdate vs Recreate strategy, maxSurge, maxUnavailable)
- Rollout workflow (status, history, undo, pause, resume, --to-revision)
- DaemonSets (spec, scheduling behavior, tolerations for control-plane nodes)
- Revision history and revisionHistoryLimit

**Defers to:**
- Helm: Deployment lifecycle managed via Helm releases
- Services: How Deployments are exposed via services
- Troubleshooting: Diagnosing failed rollouts and stuck deployments

---

### exercises/rbac: RBAC (namespace-scoped)

**Series:** Standalone (predates series structure)
**CKA domain:** Cluster Architecture, Installation & Configuration
**Cluster:** Single-node kind

**Covers:**
- Roles and RoleBindings (namespace-scoped)
- Service accounts
- User certificate creation for kind clusters
- kubeconfig context conventions (user@cluster format)
- kubectl auth can-i verification
- Permission design patterns for namespace-scoped access

**Defers to:**
- Future RBAC assignment: ClusterRoles, ClusterRoleBindings, cluster-scoped resources
- CRDs and Operators: RBAC for custom resources

---

## Planned Assignments

### exercises/cluster-lifecycle/assignment-1: Cluster Lifecycle

**CKA domain:** Cluster Architecture, Installation & Configuration
**Cluster:** Multi-node kind (may need custom kind config for etcd exercises)
**Generation order:** 1

**Planned scope:**
- kubeadm cluster installation workflow
- Cluster version upgrades with kubeadm (upgrade plan, upgrade apply, node upgrades)
- Node drain, cordon, uncordon during maintenance
- etcd backup with etcdctl snapshot save
- etcd restore with etcdctl snapshot restore
- Extension interfaces overview (CNI, CSI, CRI) at the conceptual level
- HA control plane concepts (stacked vs external etcd, may be conceptual only in kind)

**Adjacent assignments:** RBAC (security context for cluster admin operations)

---

### exercises/helm/assignment-1: Helm

**CKA domain:** Cluster Architecture, Installation & Configuration
**Cluster:** Single-node kind (sufficient for chart operations)
**Generation order:** 8

**Planned scope:**
- Helm architecture (client, charts, releases, revisions)
- Chart repositories (adding, searching, updating)
- Installing charts (helm install, values, --set, -f values.yaml)
- Upgrading releases (helm upgrade, --reuse-values)
- Rolling back releases (helm rollback, revision numbers)
- Helm release lifecycle (helm list, helm history, helm uninstall)
- Inspecting charts (helm show, helm template)

**Adjacent assignments:** Kustomize (alternative manifest management approach)

---

### exercises/kustomize/assignment-1: Kustomize

**CKA domain:** Cluster Architecture, Installation & Configuration
**Cluster:** Single-node kind
**Generation order:** 9

**Planned scope:**
- kustomization.yaml structure and purpose
- Resource references and managing directories
- Common transformers (namePrefix, nameSuffix, commonLabels, commonAnnotations)
- Image transformers
- Patches (strategic merge, JSON 6902, inline)
- Overlays (base + overlay directory structure, environment-specific configs)
- Components (reusable partial configurations)

**Adjacent assignments:** Helm (alternative manifest management approach)

---

### exercises/crds-and-operators/assignment-1: CRDs and Operators

**CKA domain:** Cluster Architecture, Installation & Configuration
**Cluster:** Single-node kind
**Generation order:** 2

**Planned scope:**
- CustomResourceDefinition spec (group, versions, scope, names, schema)
- Creating and applying CRDs
- Creating and managing custom resources
- Custom controller concept (watch, reconcile loop)
- Operator pattern (CRD + controller + operational logic)
- Installing existing operators (not writing custom controllers)
- RBAC for custom resources

**Adjacent assignments:** RBAC (permissions for custom resources), Helm (operators often installed via Helm)

---

### exercises/services/assignment-1: Services

**CKA domain:** Services & Networking
**Cluster:** Multi-node kind
**Generation order:** 4

**Planned scope:**
- ClusterIP services (default, internal access)
- NodePort services (external access on static port)
- LoadBalancer services (conceptual in kind, may use metallb or similar)
- Service selectors and label matching
- Endpoints and EndpointSlices
- Headless services (ClusterIP: None)
- Service discovery via environment variables and DNS
- ExternalName services

**Adjacent assignments:** CoreDNS (DNS-based service discovery), Ingress (L7 routing to services), pods/assignment-7 (Deployments as service backends)

---

### exercises/ingress-and-gateway-api/assignment-1: Ingress and Gateway API

**CKA domain:** Services & Networking
**Cluster:** Multi-node kind (needs ingress controller installed)
**Generation order:** 7

**Planned scope:**
- Ingress resource spec (rules, paths, backends, defaultBackend)
- Ingress controller deployment (nginx-ingress)
- Annotations and rewrite-target
- TLS termination with Ingress
- Path types (Prefix, Exact, ImplementationSpecific)
- Gateway API resources (GatewayClass, Gateway, HTTPRoute)
- Gateway API vs Ingress comparison
- Traffic routing with HTTPRoute (path matching, header matching)

**Adjacent assignments:** Services (Ingress routes to backend services), CoreDNS (DNS for ingress hostnames)

---

### exercises/coredns/assignment-1: CoreDNS and Cluster DNS

**CKA domain:** Services & Networking
**Cluster:** Multi-node kind
**Generation order:** 5

**Planned scope:**
- Service DNS format: `<service>.<namespace>.svc.cluster.local`
- Pod DNS records
- CoreDNS Deployment and ConfigMap in kube-system
- Corefile structure and plugins
- DNS debugging workflow (nslookup, dig from within pods using busybox/dnsutils)
- DNS policies in pod spec (ClusterFirst, Default, None, ClusterFirstWithHostNet)
- Troubleshooting DNS resolution failures

**Adjacent assignments:** Services (DNS resolves service names), troubleshooting/assignment-4 (DNS as failure domain)

---

### exercises/network-policies/assignment-1: Network Policies

**CKA domain:** Services & Networking
**Cluster:** Multi-node kind (needs CNI with NetworkPolicy support)
**Generation order:** 6

**Planned scope:**
- NetworkPolicy spec structure (podSelector, policyTypes, ingress, egress)
- Ingress rules (from: podSelector, namespaceSelector, ipBlock)
- Egress rules (to: podSelector, namespaceSelector, ipBlock)
- Default deny policies (deny all ingress, deny all egress, deny all)
- Namespace isolation patterns
- Combining podSelector and namespaceSelector (AND vs OR semantics)
- CIDR-based selectors for external traffic
- Port-level filtering
- Policy ordering and additive behavior (policies are unioned, not overridden)

**Adjacent assignments:** Services (policies filter traffic to services), troubleshooting/assignment-4 (network policy debugging)

**Kind cluster note:** The default kind CNI (kindnet) does not support NetworkPolicy.
The prompt must include instructions for installing a policy-capable CNI (Calico is
the most common choice for kind clusters).

---

### exercises/storage/assignment-1: Persistent Storage

**CKA domain:** Storage
**Cluster:** Single-node kind (sufficient for local storage exercises)
**Generation order:** 3

**Planned scope:**
- Volume types: emptyDir, hostPath, persistentVolumeClaim
- PersistentVolume spec (capacity, accessModes, persistentVolumeReclaimPolicy, storageClassName, hostPath)
- PersistentVolumeClaim spec (resources.requests.storage, accessModes, storageClassName)
- PV-to-PVC binding mechanics (capacity, access modes, storage class matching)
- Using PVCs in pod specs (volumes + volumeMounts)
- Access modes (ReadWriteOnce, ReadOnlyMany, ReadWriteMany, ReadWriteOncePod)
- Reclaim policies (Retain, Delete)
- StorageClass resources and dynamic provisioning
- Default StorageClass
- Volume expansion (allowVolumeExpansion)

**Adjacent assignments:** pods/assignment-2 (ConfigMap and Secret volumes), pods/assignment-6 (emptyDir for inter-container sharing)

---

### exercises/troubleshooting/assignment-1: Application Troubleshooting

**CKA domain:** Troubleshooting
**Cluster:** Multi-node kind
**Generation order:** 10

**Planned scope:**
- Pod failure states (CrashLoopBackOff, ImagePullBackOff, ErrImagePull, CreateContainerError)
- Diagnosing crashes from logs and events
- Resource exhaustion (OOMKilled, CPU throttling, eviction)
- Incorrect commands, arguments, or environment variables causing failures
- Missing or misconfigured ConfigMaps and Secrets
- Volume mount failures (wrong path, missing PVC, access mode mismatch)
- Service selector mismatches (endpoints empty)

**Cross-domain scenarios:** These exercises intentionally combine failures from multiple
topic areas (broken deployment + wrong service selector + missing configmap).

---

### exercises/troubleshooting/assignment-2: Control Plane Troubleshooting

**CKA domain:** Troubleshooting
**Cluster:** Multi-node kind
**Generation order:** 11

**Planned scope:**
- API server failures (static pod manifest errors, certificate issues, port conflicts)
- Scheduler failures (not running, misconfigured)
- Controller manager failures (not running, RBAC issues)
- etcd failures (not running, data corruption, connectivity)
- Static pod manifest debugging in /etc/kubernetes/manifests/
- Certificate expiration and verification
- Control plane component logs (kubectl logs for kube-system pods, crictl for static pods)

**Kind cluster note:** Some control plane failure scenarios may be limited in kind.
The prompt should identify which scenarios work in kind and which are conceptual.

---

### exercises/troubleshooting/assignment-3: Node and Kubelet Troubleshooting

**CKA domain:** Troubleshooting
**Cluster:** Multi-node kind
**Generation order:** 12

**Planned scope:**
- Node NotReady diagnosis (kubectl describe node, conditions)
- Kubelet not running (systemctl status kubelet, journalctl -u kubelet)
- Container runtime issues
- Node conditions (MemoryPressure, DiskPressure, PIDPressure)
- Taints applied automatically by node conditions
- Node drain and recovery
- Kubelet configuration issues

**Kind cluster note:** Kind nodes are containers, so kubelet management differs from
bare-metal. The prompt should note where kind behavior diverges from real clusters.

---

### exercises/troubleshooting/assignment-4: Network Troubleshooting

**CKA domain:** Troubleshooting
**Cluster:** Multi-node kind (with policy-capable CNI)
**Generation order:** 13

**Planned scope:**
- Service not reachable (empty endpoints, selector mismatch, wrong port)
- DNS resolution failures (CoreDNS not running, misconfigured, pod DNS policy)
- Network policy blocking expected traffic
- kube-proxy issues (not running, wrong mode)
- Pod-to-pod connectivity failures
- Cross-namespace connectivity issues
- External access failures (NodePort not reachable, Ingress misconfigured)

**Cross-domain scenarios:** These exercises combine networking failures with application
and service configuration issues.
