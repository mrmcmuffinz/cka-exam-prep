# Jobs and CronJobs Tutorial

This tutorial walks through Jobs and CronJobs from the minimum viable spec to the production-realistic configurations you will see on the exam. It starts with a single-completion Job, adds parallelism and Indexed mode, then turns to failure handling, CronJob scheduling, concurrency control, and cleanup. Along the way every field is introduced with its default, its valid values, and what you see when it is misconfigured.

All tutorial resources go into a dedicated namespace called `tutorial-jobs-and-cronjobs` so nothing collides with the homework exercises.

## Prerequisites

Verify your cluster is up and kubectl is pointed at it before you start.

```bash
kubectl get nodes
kubectl cluster-info
```

You should see at least one node in `Ready` state. Then create the tutorial namespace and set it as your default to save typing.

```bash
kubectl create namespace tutorial-jobs-and-cronjobs
kubectl config set-context --current --namespace=tutorial-jobs-and-cronjobs
```

If you prefer to be explicit, skip that second command and add `-n tutorial-jobs-and-cronjobs` to every command below.

This tutorial assumes you have completed `exercises/01-01-pods/assignment-7` (Workload Controllers). A Job is a workload controller that manages pods, and the reconciliation behavior you saw with ReplicaSets applies directly.

## Part 1: The Simplest Job

The minimum viable Job spec needs four things: the `apiVersion` (`batch/v1`), the `kind` (`Job`), a `metadata.name`, and a `spec.template` that is a valid pod template. There is one hard constraint: the pod template's `restartPolicy` must be `OnFailure` or `Never`. Setting it to `Always` (the pod default) or omitting it (which defaults to `Always`) produces a validation error. That constraint exists because `Always` would make a Job loop forever, which contradicts a Job's finite-duration semantics.

Start with the imperative form, which is fastest on the exam.

```bash
kubectl create job hello --image=busybox:1.36 -- sh -c 'echo "hello from job"; exit 0'
```

The `-- sh -c "..."` syntax passes the command into the pod template's container. Without the explicit `sh -c` wrapper, the runtime would try to exec a binary literally named `echo "hello from job"`, fail, and the Job would retry six times before the Job itself transitions to Failed. The command-vs-args distinction from pod fundamentals applies here, too.

Watch the Job run.

```bash
kubectl get job hello -w
```

You will see `COMPLETIONS 0/1` while the pod is running and `COMPLETIONS 1/1` once the pod exits with code 0. Press Ctrl-C once the Job is complete.

Read the pod logs, which persist after the pod terminates because the Job keeps completed pods around for inspection.

```bash
kubectl get pods -l batch.kubernetes.io/job-name=hello
kubectl logs -l batch.kubernetes.io/job-name=hello
```

Kubernetes labels every pod a Job creates with `batch.kubernetes.io/job-name=<job-name>` and `batch.kubernetes.io/controller-uid=<uid>` so you can find and filter them.

### Reading the declarative form

Regenerate that Job as YAML so you can see every default Kubernetes filled in.

```bash
kubectl create job hello-yaml --image=busybox:1.36 --dry-run=client -o yaml -- sh -c 'echo hello; exit 0'
```

The shape you get back, trimmed to the interesting fields, is:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: hello-yaml
spec:
  template:
    spec:
      containers:
      - name: hello-yaml
        image: busybox:1.36
        command: ["sh", "-c", "echo hello; exit 0"]
      restartPolicy: Never
```

`parallelism` and `completions` are not set on the YAML, because both default to 1. `backoffLimit` is also not set; it defaults to 6. `activeDeadlineSeconds` is not set and has no default; without it, the Job runs until it either completes or exhausts `backoffLimit`.

Clean up before moving on.

```bash
kubectl delete job hello hello-yaml
```

## Part 2: Parallelism and Completions

`parallelism` and `completions` are two independent integer fields that together describe a parallel Job's workload shape. `completions` is the number of successful pod completions the Job needs to finish; `parallelism` is the maximum number of pods the Job runs concurrently. Both default to 1, which is why the hello Job above ran one pod once.

To run four copies of the same work, two at a time, set `completions: 4` and `parallelism: 2`.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-work
spec:
  completions: 4
  parallelism: 2
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c", "echo working on $$; sleep 3; echo done"]
EOF

kubectl get pods -l batch.kubernetes.io/job-name=parallel-work -w
```

You will see two pods run, complete, two more start, and so on until the Job reports `COMPLETIONS 4/4`. Press Ctrl-C once complete.

Read how many total pods the Job produced:

```bash
kubectl get pods -l batch.kubernetes.io/job-name=parallel-work --no-headers | wc -l
# Expected: 4
```

If one of the pods had failed with a nonzero exit, the Job controller would have created a replacement to work toward the 4 successful completions, up to `backoffLimit` total pod failures. You will see that behavior directly in Part 4.

Clean up.

```bash
kubectl delete job parallel-work
```

### Why this matters

The `parallelism` and `completions` split lets you express two different intents: "run this work N times total" (`completions`) and "do not exceed M concurrent pods" (`parallelism`). For embarrassingly-parallel work where order does not matter, `completions=N, parallelism=N` completes fastest (all pods at once). For rate-limited external systems, `completions=N, parallelism=1` runs serially. For a balance, `parallelism` below `completions` caps concurrency while still finishing all work.

## Part 3: Indexed Completion Mode

The default `completionMode: NonIndexed` treats pods as interchangeable: any pod reaching exit 0 increments the success counter. That is ideal for work where you do not care which pod does which unit.

When the pods must divide work by identity (process file 0, file 1, file 2, for example), set `completionMode: Indexed`. Kubernetes gives each pod a unique index in the range `[0, completions)`, exposed two ways: as the `JOB_COMPLETION_INDEX` environment variable, and as a pod annotation `batch.kubernetes.io/job-completion-index`.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: indexed-work
spec:
  completions: 3
  parallelism: 3
  completionMode: Indexed
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c"]
        args: ["echo 'working on shard' $JOB_COMPLETION_INDEX; sleep 2; echo done"]
EOF

# wait for completion
kubectl wait --for=condition=Complete job/indexed-work --timeout=60s

# inspect per-index output
for i in 0 1 2; do
  echo "=== index $i ==="
  kubectl logs -l batch.kubernetes.io/job-completion-index=$i
done
```

Each pod reports its shard number, which is how you would wire up parallel processing of a numeric-index set of work items. A common production pattern is a ConfigMap or script that maps the integer index to a specific input (a filename, a numeric range, a shard key).

Clean up.

```bash
kubectl delete job indexed-work
```

## Part 4: Failure Handling

Jobs fail in two ways: individual pod failures (retried based on `backoffLimit`) and an overall time budget (`activeDeadlineSeconds`). Understanding the difference matters because they produce different terminal states and interact with restart policy.

### backoffLimit

`backoffLimit` is the total number of pod failures the Job will tolerate before giving up. The default is 6. Each failing pod counts toward this limit; a Job with `backoffLimit: 2` will produce up to three failing pods total (the initial plus two retries) before being marked Failed.

Create a Job that fails deterministically.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: always-fails
spec:
  backoffLimit: 2
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: fail
        image: busybox:1.36
        command: ["sh", "-c", "echo 'about to fail'; exit 1"]
EOF

# wait for final state (needs a bit of time because of exponential backoff)
sleep 90
kubectl get job always-fails
kubectl describe job always-fails | grep -A 5 Events:
```

You will see the Job in a `Failed` condition with the message `Job has reached the specified backoff limit`. The pods list for the Job shows three pods (index 0: the original, index 1 and 2: the two retries), each in `Error` status. Read pod logs with `kubectl logs -l batch.kubernetes.io/job-name=always-fails --tail=-1 --prefix` to see output across all attempts at once.

Clean up.

```bash
kubectl delete job always-fails
```

### activeDeadlineSeconds

`activeDeadlineSeconds` is a wall-clock budget for the entire Job (across all pod retries). It has no default; without it, a Job that never completes just keeps retrying forever until it hits `backoffLimit`. With it set, the Job is killed after the deadline regardless of how many attempts remain.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: runs-too-long
spec:
  activeDeadlineSeconds: 10
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: long
        image: busybox:1.36
        command: ["sh", "-c", "echo starting; sleep 300; echo finished"]
EOF

sleep 20
kubectl describe job runs-too-long | grep -A 5 Events:
```

The Events section will show `DeadlineExceeded`, and the Job transitions to `Failed` with reason `DeadlineExceeded`. That is how you make long-running work fail predictably rather than block the controller or your exam clock.

Clean up.

```bash
kubectl delete job runs-too-long
```

### restartPolicy interaction

`restartPolicy: OnFailure` restarts the container in place on nonzero exit, up to `backoffLimit`. `restartPolicy: Never` creates a new pod for each retry. The difference is mostly invisible for your purposes except when you need to inspect logs: with `OnFailure` the same pod holds all attempts (use `kubectl logs POD --previous` to read earlier attempts), while with `Never` you see separate pods and can read each individually with `kubectl logs -l batch.kubernetes.io/job-name=NAME`. Both are valid; pick whichever is clearer for the exercise.

## Part 5: ttlSecondsAfterFinished

Completed Jobs and their pods accumulate in a namespace indefinitely by default. `ttlSecondsAfterFinished` sets a time-to-live: once a Job reaches `Complete` or `Failed`, the Job and its pods are garbage-collected after this many seconds. A value of 0 deletes immediately; a value of 300 cleans up five minutes after completion.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ephemeral
spec:
  ttlSecondsAfterFinished: 15
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: short
        image: busybox:1.36
        command: ["sh", "-c", "echo done"]
EOF

# wait for Complete then for the TTL to expire
sleep 5
kubectl get job ephemeral
# Expected: COMPLETIONS 1/1

sleep 20
kubectl get job ephemeral 2>&1 | head
# Expected: Error from server (NotFound) ... "ephemeral" not found
```

This is the mechanism most production CronJobs use to prevent Job-accumulation pressure on etcd. Set it per-Job or globally via a cluster-wide controller-manager flag.

## Part 6: A Simple CronJob

A CronJob is a controller over Jobs the way a Job is a controller over pods. Its `spec.schedule` is a cron expression; its `spec.jobTemplate` is an embedded Job template that produces a new Job each time the schedule fires.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: minute-hello
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: hello
            image: busybox:1.36
            command: ["sh", "-c", "echo 'cron hello at' $(date -u +%H:%M:%S)"]
EOF

# wait at least two minutes for the CronJob to fire twice
sleep 130
kubectl get cronjob minute-hello
kubectl get jobs -l batch.kubernetes.io/cronjob-name=minute-hello
kubectl get pods -l batch.kubernetes.io/cronjob-name=minute-hello
```

You will see the CronJob's `SCHEDULE` column, `LAST SCHEDULE` timestamp, and the Jobs and pods it has created. The naming convention is `<cronjob-name>-<timestamp>` for each Job.

### Schedule syntax

The `schedule` field takes a standard five-field cron expression: minute, hour, day-of-month, month, day-of-week. `*` means every value; `*/N` means every Nth value; ranges use `-` (as in `9-17`); lists use `,` (as in `0,15,30,45`). Macros shorthand common cases: `@hourly` is `0 * * * *`, `@daily` (or `@midnight`) is `0 0 * * *`, `@weekly` is `0 0 * * 0`, `@monthly` is `0 0 1 * *`, `@yearly` is `0 0 1 1 *`.

### Time zones

By default, the schedule is evaluated in the `kube-controller-manager`'s local time, which on kind is UTC. For production-realistic scheduling, use the `timeZone` field (stable since Kubernetes 1.27) with an IANA time zone identifier.

```yaml
spec:
  schedule: "0 3 * * *"
  timeZone: "America/New_York"
```

This runs daily at 3:00 America/New_York local time, handling daylight saving shifts automatically. Note that putting `CRON_TZ=` or `TZ=` in the schedule string itself is explicitly rejected by Kubernetes.

Do not clean up yet; you will use this CronJob for Part 7.

## Part 7: Concurrency Policy

The `concurrencyPolicy` field controls what happens when the schedule fires while the previous Job is still running. Valid values:

- **Allow** (default): start a new Job alongside the still-running one. Two or more Jobs can run concurrently. Use when Job instances are independent and overlap is safe.
- **Forbid**: skip the new Job if the previous has not finished. The skip is visible as a `MissingJob` event, but no Job is created. Use when instances must not overlap (shared resources, singleton workloads).
- **Replace**: kill the still-running Job and start the new one. Use when only the most recent invocation matters and old runs are not worth completing.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: no-overlap
spec:
  schedule: "*/1 * * * *"
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: slow
            image: busybox:1.36
            command: ["sh", "-c", "echo starting; sleep 90; echo done"]
EOF
```

Because the Job sleeps 90 seconds and the schedule fires every minute, each new firing arrives while the previous is still running. With `concurrencyPolicy: Forbid`, the new firing is skipped. Wait about three minutes and inspect:

```bash
sleep 180
kubectl get jobs -l batch.kubernetes.io/cronjob-name=no-overlap
kubectl describe cronjob no-overlap | tail -20
```

You will see fewer Jobs than minutes elapsed, and the Events section shows `MissingJob` entries for each skipped firing.

Clean up both CronJobs.

```bash
kubectl delete cronjob minute-hello no-overlap
```

## Part 8: History Limits

Completed and failed Jobs produced by a CronJob accumulate until the history limits trim them. The defaults are `successfulJobsHistoryLimit: 3` (keep the three most recent successful Jobs) and `failedJobsHistoryLimit: 1` (keep the single most recent failed Job). Both are settable. Setting either to 0 disables that history (Jobs are deleted as soon as they terminate).

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: trimmed-history
spec:
  schedule: "*/1 * * * *"
  successfulJobsHistoryLimit: 1
  failedJobsHistoryLimit: 0
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: ok
            image: busybox:1.36
            command: ["sh", "-c", "echo done"]
EOF

# let it run for 4 minutes
sleep 240
kubectl get jobs -l batch.kubernetes.io/cronjob-name=trimmed-history
```

You will see exactly one Job (the most recent successful one) despite at least three having been created. History limits are the reason most production CronJobs do not need explicit cleanup scripts.

Clean up.

```bash
kubectl delete cronjob trimmed-history
```

## Part 9: startingDeadlineSeconds and suspend

Two additional CronJob fields you should know exist, though they are less commonly tested.

`startingDeadlineSeconds` sets a window after each scheduled time during which the Job may start. If the controller is unavailable at the scheduled time (because the control plane was down) and comes back up later, the CronJob checks whether the delay exceeds this deadline; if it does, the firing is skipped. Without this field, the controller may try to catch up on many missed firings, which is rarely what you want.

`suspend: true` pauses scheduling without deleting the CronJob. The CronJob stays in place, but no new Jobs are created while `suspend` is true. Setting it back to `false` resumes scheduling.

```bash
kubectl patch cronjob minute-hello --type=merge -p '{"spec":{"suspend":true}}' 2>/dev/null || echo "CronJob already deleted, that's fine"
```

## Part 10: Diagnostic Workflow

When a Job or CronJob is not behaving as expected, follow this sequence.

For a Job:

```bash
kubectl get job NAME
# Check COMPLETIONS column for progress; STATUS column for Complete or Failed

kubectl describe job NAME
# Read the Conditions section (Complete, Failed with reason BackoffLimitExceeded or DeadlineExceeded)
# Read the Events section for pod creation and termination timeline

kubectl get pods -l batch.kubernetes.io/job-name=NAME
# See every pod the Job has produced (successful and failed)

kubectl logs -l batch.kubernetes.io/job-name=NAME --tail=-1 --prefix
# Logs from every pod with pod name prefix
```

For a CronJob:

```bash
kubectl get cronjob NAME
# LAST SCHEDULE column tells you the most recent firing time; empty means it has never fired yet

kubectl describe cronjob NAME
# Events include Created (per Job creation), MissingJob (per Forbid skip), and Scheduled Timer events

kubectl get jobs -l batch.kubernetes.io/cronjob-name=NAME
# Jobs the CronJob has created (limited by the history fields)
```

The most common CronJob issue is "why isn't it firing?" The answer is usually one of: the schedule expression is wrong (test it on crontab.guru or similar), the CronJob is suspended, `startingDeadlineSeconds` is too tight and all firings got skipped, or the namespace the CronJob lives in is being deleted.

## Part 11: Cleanup

Delete the tutorial namespace to remove everything you created.

```bash
kubectl config set-context --current --namespace=default
kubectl delete namespace tutorial-jobs-and-cronjobs
```

## Reference Commands

### Imperative Job creation

```bash
# simplest Job
kubectl create job NAME --image=IMAGE

# with command override (everything after -- becomes the container command)
kubectl create job NAME --image=IMAGE -- sh -c "echo hi; exit 0"

# from a CronJob (create a one-off Job using the CronJob's template)
kubectl create job NAME --from=cronjob/CRONJOB

# generate YAML without creating
kubectl create job NAME --image=IMAGE --dry-run=client -o yaml > job.yaml
```

### Imperative CronJob creation

```bash
# simplest CronJob
kubectl create cronjob NAME --image=IMAGE --schedule="*/5 * * * *"

# with command
kubectl create cronjob NAME --image=IMAGE --schedule="@hourly" -- sh -c "echo hi"

# generate YAML
kubectl create cronjob NAME --image=IMAGE --schedule="@daily" --dry-run=client -o yaml > cj.yaml
```

### Job spec field defaults and constraints

| Field | Default | Notes |
|---|---|---|
| `completions` | 1 | Number of successful pod completions required |
| `parallelism` | 1 | Maximum concurrent pods |
| `backoffLimit` | 6 | Total pod failures tolerated before Job fails |
| `activeDeadlineSeconds` | unset | Wall-clock budget; without it, Job retries until `backoffLimit` |
| `completionMode` | `NonIndexed` | Set to `Indexed` for per-pod `JOB_COMPLETION_INDEX` |
| `ttlSecondsAfterFinished` | unset | Auto-delete Job N seconds after terminal state |
| `template.spec.restartPolicy` | (pod default `Always`) | Must be `OnFailure` or `Never`; `Always` rejected |

### CronJob spec field defaults

| Field | Default | Notes |
|---|---|---|
| `schedule` | required | Cron expression or macro (`@hourly`, `@daily`, etc.) |
| `timeZone` | controller-manager local time | IANA zone name; stable since 1.27 |
| `concurrencyPolicy` | `Allow` | `Allow`, `Forbid`, or `Replace` |
| `startingDeadlineSeconds` | unset | Window after scheduled time within which Job may start |
| `successfulJobsHistoryLimit` | 3 | Most-recent successful Jobs retained |
| `failedJobsHistoryLimit` | 1 | Most-recent failed Jobs retained |
| `suspend` | `false` | When `true`, no new Jobs are created |

### Pod labels automatically applied

Every pod a Job creates is labeled with:

- `batch.kubernetes.io/job-name=<job-name>`
- `batch.kubernetes.io/controller-uid=<job-uid>`

And, in Indexed mode:

- `batch.kubernetes.io/job-completion-index=<index>` (as a label and pod annotation)

Every Job a CronJob creates is labeled with:

- `batch.kubernetes.io/cronjob-name=<cronjob-name>`

Use these selectors to find resources quickly.

## Where to Go Next

Work through `jobs-and-cronjobs-homework.md` starting at Level 1. The Reference Commands section above and the spec-field tables are designed for skim-lookup while doing the exercises.
