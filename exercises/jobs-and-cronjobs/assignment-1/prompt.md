# Prompt: Jobs and CronJobs (assignment-1)

## Header

- **Series:** Jobs and CronJobs (1 of 1)
- **CKA domain:** Workloads & Scheduling (15%)
- **Competencies covered:** Understand primitives for robust, self-healing application deployments (batch workloads); ReplicaSets contrasted with Jobs
- **Course sections referenced:** S2 (lectures 18-32, pods and controllers), S3 (lectures 69-71, DaemonSets for contrast with Jobs), and the general workload-controller grounding from S5
- **Prerequisites:** `pods/assignment-7` (Workload Controllers)

## Scope declaration

### In scope for this assignment

*Job spec fundamentals*
- `apiVersion: batch/v1`, `kind: Job` structure and required fields
- `template` (a pod template embedded in the Job spec) and its relationship to the pod spec learned in the pod series
- `spec.completions` (total successful pod completions required)
- `spec.parallelism` (maximum concurrent pods)
- `spec.backoffLimit` (retries before the Job is marked Failed)
- `spec.activeDeadlineSeconds` (wall-clock timeout across all retries)
- `spec.template.spec.restartPolicy` constraint (must be `OnFailure` or `Never`, never `Always`)

*Job completion modes*
- `spec.completionMode: NonIndexed` (default; success-count semantics)
- `spec.completionMode: Indexed` (per-index identity via `JOB_COMPLETION_INDEX` env var and `batch.kubernetes.io/job-completion-index` annotation)
- When to use Indexed (embarrassingly-parallel work with per-index output)

*CronJob spec*
- `apiVersion: batch/v1`, `kind: CronJob`
- `spec.schedule` (cron expression; time zone implications and `spec.timeZone` field)
- `spec.jobTemplate` (embedded Job template)
- `spec.concurrencyPolicy` (Allow, Forbid, Replace)
- `spec.startingDeadlineSeconds` (window for missed schedules)
- `spec.successfulJobsHistoryLimit` and `spec.failedJobsHistoryLimit`
- `spec.suspend` (temporarily pause scheduling)

*Lifecycle and cleanup*
- `spec.ttlSecondsAfterFinished` on Jobs (time-to-live for completed Jobs and their pods)
- Manual deletion of completed Jobs
- The relationship between a CronJob and the Jobs it creates (owner references)

*Diagnostic workflow for batch workloads*
- Reading `kubectl describe job` for status conditions (Complete, Failed, Suspended)
- Reading Job Events for BackoffLimitExceeded, DeadlineExceeded
- Accessing pod logs of a finished Job (pods from completed Jobs are retained until ttlSecondsAfterFinished expires or the Job is deleted)
- Debugging a CronJob that is not firing on schedule

### Out of scope (covered in other assignments, do not include)

- Long-running workloads (ReplicaSets, Deployments, DaemonSets): covered in `pods/assignment-7`
- StatefulSets: covered in `statefulsets/`
- Horizontal Pod Autoscaler on Jobs: HPA does not target Jobs; covered in `autoscaling/` for Deployments only
- Pod scheduling mechanics (node affinity, taints, tolerations): covered in `pods/assignment-4`
- Resource requests and limits, QoS classes: covered in `pods/assignment-5`
- Custom metrics and advanced scheduling for batch: out of CKA scope

## Environment requirements

- Single-node kind cluster per `docs/cluster-setup.md#single-node-kind-cluster`
- No special CNI, storage, or ingress components needed
- No additional tools beyond `kubectl`

## Resource gate

All CKA resources are in scope (this topic is generated after Networking and Storage are complete). The assignment should primarily use Jobs, CronJobs, and Pods, with ConfigMaps and Secrets where they help demonstrate data flow into a batch workload. Avoid introducing Services, Ingress, StatefulSets, or other topic-adjacent resources that would pull focus away from batch workload mechanics.

## Topic-specific conventions

- All container images must work for fast iteration in exercises. Prefer `busybox:1.36`, `alpine:3.20`, and `curlimages/curl:8.5.0` for short-duration work.
- CronJob schedule strings in exercises should use intervals that fire quickly enough to observe during the exercise (every minute or every two minutes) rather than realistic production schedules (daily or weekly).
- The tutorial should demonstrate both success and failure modes. A Job that completes successfully, a Job that fails every retry until BackoffLimitExceeded, and a Job that hits activeDeadlineSeconds are all needed.
- For Indexed completion mode, the tutorial should show a worked example where the pod uses `$JOB_COMPLETION_INDEX` to pick a shard or file to process.
- The diagnostic workflow section must explain how to read Job status conditions and how they differ from pod status conditions.

## Cross-references

**Prerequisites (must be completed first):**
- `exercises/pods/assignment-7`: ReplicaSets and Deployments mental model

**Adjacent topics:**
- `exercises/autoscaling/`: HPA for long-running workloads (contrasts with Jobs which are finite)
- `exercises/statefulsets/`: stateful long-running workloads
- `exercises/troubleshooting/assignment-1`: application-layer troubleshooting that will include Job failures as a category

**Forward references:**
None. This assignment is terminal for batch workload topics.
