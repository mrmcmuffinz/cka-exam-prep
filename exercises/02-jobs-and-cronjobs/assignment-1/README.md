# Assignment 1: Jobs and CronJobs

Jobs run a set of pods to completion and then stop, and CronJobs wrap Jobs with a schedule so they repeat. This assignment, the only one in its series, covers the full CKA-relevant surface: Job spec fundamentals, completion modes (NonIndexed and Indexed), failure handling with `backoffLimit` and `activeDeadlineSeconds`, CronJob scheduling, concurrency policy, history limits, and time-to-live for finished Jobs. It assumes the pod and workload-controller mental model from the pod series, because a Job is a controller over a pod template, and because the diagnostic tools you will use are the same ones you have already applied to Deployments and DaemonSets.

## Files

| File | Purpose |
|---|---|
| `prompt.md` | The generation prompt (input to the homework generator skill) |
| `README.md` | This overview |
| `jobs-and-cronjobs-tutorial.md` | Step-by-step tutorial teaching every Job and CronJob feature the CKA tests |
| `jobs-and-cronjobs-homework.md` | 15 progressive exercises across five difficulty levels |
| `jobs-and-cronjobs-homework-answers.md` | Complete solutions with diagnostic reasoning and common mistakes |

## Recommended Workflow

Work through the tutorial first, in your own cluster, running every command as you read rather than just reading them. The tutorial builds a small library of Jobs and CronJobs, starting from the minimum viable spec and adding one layer at a time, so that the field defaults and failure modes become visible before you reach the homework. Once the tutorial is complete, move through the 15 exercises in order. The progression is designed so that the Level 5 debugging exercises only feel tractable after you have practiced the failure modes individually in Levels 1 through 3. Use the answer key only after a genuine attempt, and for debugging exercises read the diagnosis section first before jumping to the fix.

## Difficulty Progression

Level 1 covers basic construction: a single Job that runs once, a simple CronJob on a fixed schedule, and a Job that requires a specific completion count. Level 2 combines two or three concepts in one resource, for example parallel execution with a total completion target, or CronJob history limits with concurrency policy. Level 3 is debugging: you are given a broken Job or CronJob YAML and you diagnose the issue from pod status, Job events, and resource spec before fixing it. Level 4 is production-realistic build tasks: parallel batch processing with Indexed mode, a daily backup CronJob with retention constraints, a Job with active deadline handling. Level 5 is advanced debugging or comprehensive scenarios where several things are wrong at once or where the resource must meet a dense set of requirements.

## Prerequisites

Complete `exercises/01-01-pods/assignment-7` (Workload Controllers) before this assignment; Jobs and CronJobs are workload controllers that produce pods from a template, and the reconciliation model from ReplicaSets carries directly over. You should also be comfortable with pod spec fundamentals (`exercises/01-01-pods/assignment-1`) because the Job's pod template is a full pod spec with one constraint: `restartPolicy` must be `OnFailure` or `Never`, never `Always`.

## Cluster Requirements

A single-node kind cluster is sufficient for every exercise in this assignment. CronJobs rely on the controller-manager's clock, which is accurate enough in kind for the minute-granularity schedules the exercises use. See `docs/cluster-setup.md#single-node-kind-cluster` for the cluster creation command.

No extra components (MetalLB, Calico, metrics-server, Gateway API CRDs) are required.

## Estimated Time Commitment

Plan for about 45 to 60 minutes on the tutorial if you work through every command attentively. The 15 exercises together take three to five hours, weighted toward Levels 3 and 5 where diagnostic reasoning is the main work. Levels 1 and 2 run roughly 10 to 15 minutes each; Level 3 debugging exercises tend to take 15 to 25 minutes each because CronJobs have minute-level scheduling cadence and you will wait for events between attempts; Level 4 build tasks run 20 to 30 minutes each; Level 5 takes 25 to 40 minutes per exercise. If you time-box to match exam pressure, those numbers give you a useful baseline for how much faster you need to become.

## Scope Boundary and What Comes Next

This assignment covers finite-duration workloads. The long-running workload controllers (ReplicaSets, Deployments, DaemonSets) are `exercises/01-01-pods/assignment-7` territory; stateful workloads with ordered identity are covered in `exercises/03-statefulsets/`; horizontal autoscaling targets long-running workloads and is in `exercises/04-autoscaling/`. Scheduling constraints on the pod template (node affinity, taints, tolerations) are covered in `exercises/01-01-pods/assignment-4`, and resource requests and limits are `exercises/01-01-pods/assignment-5`; those fields all exist on the Job's pod template, but this assignment does not introduce them, leaning on the prerequisite assignments instead. Batch-workload troubleshooting at cross-domain scope reappears in `exercises/19-19-troubleshooting/assignment-1`.

## Key Takeaways After Completing This Assignment

By the time you finish all 15 exercises, you should be able to construct a Job from scratch in either imperative (`kubectl create job`) or declarative form, pick `restartPolicy` correctly knowing `Always` is rejected, reason about the interaction between `parallelism` and `completions` to design parallel batch workloads, use Indexed completion mode with `JOB_COMPLETION_INDEX` to partition work among parallel pods, tune `backoffLimit` and `activeDeadlineSeconds` to make a Job fail predictably instead of retrying forever, construct a CronJob with a specific schedule (including IANA time zones via `timeZone`), choose the right `concurrencyPolicy` for a workload's overlap tolerance, trim kept history with `successfulJobsHistoryLimit` and `failedJobsHistoryLimit`, set `ttlSecondsAfterFinished` to clean up finished Jobs automatically, and diagnose a failing or stuck batch workload by reading `kubectl describe job`, Events on both the Job and its pods, and pod logs retained by the kept-history behavior.
