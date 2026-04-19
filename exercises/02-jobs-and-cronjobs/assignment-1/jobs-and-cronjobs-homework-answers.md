# Jobs and CronJobs Homework Answers

Complete solutions for all 15 exercises. For every Level 3 and Level 5 debugging exercise, the answer follows a three-stage structure: Diagnosis (the exact commands to run and what to look for), What the bug is and why (the underlying cause), and Fix (the corrected spec). Solutions show a single canonical form per exercise; imperative vs declarative is called out where both are reasonable.

-----

## Exercise 1.1 Solution

### Imperative

```bash
kubectl create job greeter -n ex-1-1 --image=busybox:1.36 -- sh -c 'echo "hello from homework"; exit 0'
```

The `-- sh -c "..."` form passes the shell command into the pod template. `kubectl create job` sets `restartPolicy: Never` automatically (you can see this by appending `--dry-run=client -o yaml`).

### Declarative

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: greeter
  namespace: ex-1-1
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: greeter
        image: busybox:1.36
        command: ["sh", "-c", "echo 'hello from homework'; exit 0"]
```

The Job defaults `completions: 1` and `parallelism: 1`, both of which are what the exercise wants, so they need not be set explicitly. `backoffLimit` defaults to 6, unused here because the pod exits 0 on the first try. The `restartPolicy: Never` is required; the pod default of `Always` is rejected on a Job.

-----

## Exercise 1.2 Solution

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: retrier
  namespace: ex-1-2
spec:
  backoffLimit: 2
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: fail
        image: busybox:1.36
        command: ["sh", "-c", "exit 1"]
```

`backoffLimit: 2` tolerates two pod failures in addition to the initial one, for three total failures before the Job is marked Failed with reason `BackoffLimitExceeded`. With `restartPolicy: Never`, each attempt is a distinct pod, which is why the verification counts exactly three pods.

The exponential backoff between retries (`6s`, then `12s`, then `24s`) is why the verification sleeps 120 seconds; terminal state arrives roughly a minute after the initial failure, with some buffer for scheduling.

-----

## Exercise 1.3 Solution

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hourly-tick
  namespace: ex-1-3
spec:
  schedule: "@hourly"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: tick
            image: busybox:1.36
            command: ["sh", "-c", "echo tick"]
```

`@hourly` is a macro equivalent to `0 * * * *` (at the top of every hour). Any of the five standard macros (`@yearly`, `@monthly`, `@weekly`, `@daily`, `@hourly`) is accepted by the API server; arbitrary prose like `"every hour"` is not.

-----

## Exercise 2.1 Solution

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-adder
  namespace: ex-2-1
spec:
  completions: 6
  parallelism: 3
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c", "echo 'worker ready'; exit 0"]
```

With `parallelism: 3`, the Job runs three pods at a time. With `completions: 6`, it requires six total successes. The runtime shape is two waves of three pods each, producing six pods and six `worker ready` log lines.

-----

## Exercise 2.2 Solution

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: shardwork
  namespace: ex-2-2
spec:
  completions: 4
  parallelism: 4
  completionMode: Indexed
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c"]
        args: ["echo processing shard $JOB_COMPLETION_INDEX"]
```

`completionMode: Indexed` is what populates `JOB_COMPLETION_INDEX` in each pod's environment. The `sh -c` form is necessary so the shell expands the variable; without it, the container runtime would try to exec a literal binary whose name starts with `echo processing shard $JOB_COMPLETION_INDEX` and fail.

An alternative that keeps everything in `args` (equivalent):

```yaml
command: ["sh", "-c", "echo processing shard $JOB_COMPLETION_INDEX"]
```

Either works; both produce the same argv to the shell.

-----

## Exercise 2.3 Solution

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: trimmed-nightly
  namespace: ex-2-3
spec:
  schedule: "@daily"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 0
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: nightly
            image: busybox:1.36
            command: ["sh", "-c", "echo done"]
```

`failedJobsHistoryLimit: 0` means failed Jobs are deleted immediately on failure. That is appropriate when you trust another signal (alerting, logging) for failure visibility and do not want stale failed Jobs accumulating. `successfulJobsHistoryLimit: 2` retains the two most recent successes.

-----

## Exercise 3.1 Solution

### Diagnosis

```bash
kubectl get job broken-1 -n ex-3-1
# No rows, or the Job exists but with an error status
```

If the Job exists in the cluster, `kubectl describe job broken-1 -n ex-3-1` shows an invalid spec. More commonly, the API server rejects the apply outright and no Job is created.

```bash
kubectl apply -n ex-3-1 -f - <<'EOF'
# ... (the Setup spec, with restartPolicy: Always)
EOF
# Error from server: spec.template.spec.restartPolicy: Unsupported value:
#   "Always": supported values: "OnFailure", "Never"
```

### What the bug is and why

A Job's pod template must set `restartPolicy` to either `OnFailure` or `Never`. `Always` would cause the pod to restart forever regardless of exit code, which contradicts a Job's "run to completion" semantics. The API server rejects the spec at admission time. Pod defaults to `Always` if the field is omitted, so omitting the field also produces the same error when applied as a Job template.

### Fix

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: broken-1
  namespace: ex-3-1
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c", "echo hello; exit 0"]
```

Changing `restartPolicy: Always` to `restartPolicy: Never` lets the spec apply and the Job run once to successful completion. `OnFailure` would also be valid; the pod exits 0 so either produces the same outcome.

-----

## Exercise 3.2 Solution

### Diagnosis

```bash
kubectl apply -n ex-3-2 -f - <<'EOF'
# ... (the Setup spec, with schedule: "every 5 minutes")
EOF
# Error from server: spec.schedule: Invalid value: "every 5 minutes":
#   Expected exactly 5 fields, found 3: every 5 minutes
```

### What the bug is and why

The `schedule` field must be a valid cron expression or one of the supported macros (`@yearly`, `@monthly`, `@weekly`, `@daily`, `@hourly`). The API server validates the expression at admission time and rejects free-form English. `"every 5 minutes"` is the kind of string a human writes in a ticket but not a valid cron expression.

### Fix

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: broken-2
  namespace: ex-3-2
spec:
  schedule: "*/5 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: ticker
            image: busybox:1.36
            command: ["sh", "-c", "echo tick"]
```

`*/5 * * * *` means "fire at minutes 0, 5, 10, 15, ... of every hour." That is the cron expression equivalent to "every 5 minutes" in practice.

-----

## Exercise 3.3 Solution

### Diagnosis

```bash
kubectl get job broken-3 -n ex-3-3
# STATUS column likely shows 0/1 for a few seconds, then the Job is Failed

kubectl describe job broken-3 -n ex-3-3 | grep -A 5 Events:
# Events include "DeadlineExceeded: Job was active longer than specified deadline"

kubectl get job broken-3 -n ex-3-3 -o jsonpath='{.status.conditions[?(@.type=="Failed")].reason}'
# DeadlineExceeded
```

### What the bug is and why

`activeDeadlineSeconds: 3` gives the entire Job three seconds of wall-clock time. The container's command is `echo starting; sleep 15; echo finished`, which needs at least 15 seconds to reach the `finished` print. The deadline fires first, the pod is killed, and the Job transitions to `Failed` with `DeadlineExceeded`. The common reading failure is to look at the command and conclude "the sleep is too long," when the correct fix is the other way around: the command is the specification of what the Job must do, and the deadline must be large enough to accommodate it.

### Fix

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: broken-3
  namespace: ex-3-3
spec:
  activeDeadlineSeconds: 30
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: slow
        image: busybox:1.36
        command: ["sh", "-c", "echo starting; sleep 15; echo finished"]
```

Raising `activeDeadlineSeconds` to 30 (or removing the field entirely; its absence means no deadline) lets the 15-second sleep complete. The sleep itself must not change per the exercise constraints.

-----

## Exercise 4.1 Solution

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: shard-map
  namespace: ex-4-1
spec:
  completions: 5
  parallelism: 5
  completionMode: Indexed
  backoffLimit: 0
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c"]
        args: ["echo shard $JOB_COMPLETION_INDEX of 5 processed"]
```

`backoffLimit: 0` means the first pod failure marks the Job Failed. That is appropriate when retries are unproductive (idempotent work that either succeeds or has a deterministic bug worth surfacing). `ttlSecondsAfterFinished: 300` auto-deletes the Job and its pods five minutes after the Job reaches a terminal state.

-----

## Exercise 4.2 Solution

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: daily-backup
  namespace: ex-4-2
spec:
  schedule: "@daily"
  timeZone: "America/Los_Angeles"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      ttlSecondsAfterFinished: 604800
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: backup
            image: busybox:1.36
            command: ["sh", "-c", "echo \"backup complete at $(date -u +%FT%TZ)\""]
```

Note `ttlSecondsAfterFinished` sits on the embedded Job spec (`spec.jobTemplate.spec.ttlSecondsAfterFinished`), not on the CronJob spec itself. The CronJob's `successfulJobsHistoryLimit` caps how many Jobs are retained at any moment; `ttlSecondsAfterFinished` caps how long each retained Job sticks around after finishing. Both are useful and independent.

-----

## Exercise 4.3 Solution

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: bounded-run
  namespace: ex-4-3
spec:
  backoffLimit: 1
  activeDeadlineSeconds: 20
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: slow
        image: busybox:1.36
        command: ["sh", "-c", "echo working; sleep 60"]
```

The pod runs for 60 seconds; the deadline fires at 20 seconds. Because `activeDeadlineSeconds` is a wall-clock budget across all retries, the retry budget from `backoffLimit: 1` never matters; the Job is marked Failed with reason `DeadlineExceeded` as soon as the deadline fires. This is the recommended pattern for any batch workload that could otherwise stall indefinitely.

-----

## Exercise 5.1 Solution

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: complete-spec
  namespace: ex-5-1
spec:
  schedule: "*/2 * * * *"
  timeZone: "Etc/UTC"
  concurrencyPolicy: Replace
  startingDeadlineSeconds: 60
  successfulJobsHistoryLimit: 5
  failedJobsHistoryLimit: 2
  suspend: false
  jobTemplate:
    spec:
      ttlSecondsAfterFinished: 600
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: runner
            image: busybox:1.36
            command: ["sh", "-c", "echo \"iteration at $(date -u +%H:%M:%S)\""]
```

Every field in the exercise's requirement list maps to a single field on the CronJob or its nested Job template. The three levels of the structure (CronJob spec, embedded Job spec, embedded pod template) are easy to confuse; `ttlSecondsAfterFinished` belongs at the Job-spec level, and `restartPolicy` belongs at the pod-template level. The rest of the scheduling fields (`schedule`, `timeZone`, `concurrencyPolicy`, `startingDeadlineSeconds`, history limits, `suspend`) all sit on the CronJob spec itself.

-----

## Exercise 5.2 Solution

### Diagnosis

```bash
kubectl apply -n ex-5-2 -f - <<'EOF'
# ... (the broken Setup spec)
EOF
# Error from server on first apply:
# spec.template.spec.restartPolicy: Unsupported value: "Always"
```

If you fix `restartPolicy` and re-apply, you next hit:

```bash
kubectl get pods -n ex-5-2 -l batch.kubernetes.io/job-name=multibug
# STATUS Waiting / ErrImagePull

kubectl describe pod -n ex-5-2 -l batch.kubernetes.io/job-name=multibug
# Events: Failed to pull image "busybox:2.99": manifest for busybox:2.99 not found
```

And if you further fix the image but keep the command structure:

```bash
kubectl logs -n ex-5-2 -l batch.kubernetes.io/job-name=multibug
# exec: "echo processing shard $JOB_COMPLETION_INDEX; exit 0": no such file or directory
```

### What the bugs are and why

Three bugs stacked on top of each other, each fails independently:

1. `restartPolicy: Always` is rejected at admission time. Must be `OnFailure` or `Never`.
2. `busybox:2.99` does not exist on Docker Hub. Must be a real tag like `busybox:1.36`.
3. `command: ["echo processing shard $JOB_COMPLETION_INDEX; exit 0"]` passes the whole string as argv[0]. The container runtime tries to exec a binary whose literal name is that string (including the `$` and the semicolon). No such binary exists, so the exec fails. Shell semantics require `sh -c` as argv[0] with the shell command in argv[1].

Each bug has to be found and fixed independently; the error messages from each are specific and distinct, which is why Level 5 pays off: you learn to read the error, fix that one layer, and move on rather than trying to guess at all the problems at once.

### Fix

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: multibug
  namespace: ex-5-2
spec:
  completions: 3
  parallelism: 3
  completionMode: Indexed
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c"]
        args: ["echo processing shard $JOB_COMPLETION_INDEX; exit 0"]
```

Three fixes: `restartPolicy: Never`, image `busybox:1.36`, and `command: ["sh", "-c"]` with the shell command string in `args`. With those changes all three shards run, print their index, and the Job reaches `Complete` with succeeded=3.

-----

## Exercise 5.3 Solution

### Diagnosis

```bash
kubectl get cronjob silent -n ex-5-3
# LAST SCHEDULE column is <none> and stays that way

kubectl describe cronjob silent -n ex-5-3
# Suspend: true    <-- this is the primary cause
# Events: no Jobs created
```

If you set `suspend: false` and wait, you see:

```bash
sleep 70
kubectl get cronjob silent -n ex-5-3
# LAST SCHEDULE still empty after a full minute has elapsed

kubectl describe cronjob silent -n ex-5-3
# Events include "MissJob" messages or nothing; the 1-second
# startingDeadlineSeconds is almost always missed in practice
```

### What the bugs are and why

Two independent problems:

1. `suspend: true` unconditionally prevents any Job from being created. The CronJob sits inert until `suspend` flips to `false`.
2. `startingDeadlineSeconds: 1` sets a one-second window for the controller to start the Job after the scheduled time. The controller polls at its own cadence (usually every few seconds) plus a small queuing delay; by the time the controller is ready to create the Job, the one-second window has already elapsed and the firing is skipped. In practice almost every firing is skipped with this setting. A reasonable minimum is 10 to 30 seconds, and many production CronJobs pick a few minutes.

Both problems must be fixed; fixing only `suspend` does not help because the tight deadline still blocks creation.

### Fix

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: silent
  namespace: ex-5-3
spec:
  schedule: "*/1 * * * *"
  suspend: false
  startingDeadlineSeconds: 60
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: tick
            image: busybox:1.36
            command: ["sh", "-c", "sleep 120; echo done"]
```

Equivalent inline edits via `kubectl patch`:

```bash
kubectl patch cronjob silent -n ex-5-3 --type=merge \
  -p '{"spec":{"suspend":false,"startingDeadlineSeconds":60}}'
```

With `suspend: false` and `startingDeadlineSeconds: 60`, the controller has a generous window to start each firing, and a Job is created at the next minute boundary. `concurrencyPolicy: Forbid` stays because the 120-second sleep exceeds the one-minute cadence; overlapping runs would be undesirable.

-----

## Common Mistakes

### restartPolicy: Always on a Job

The most common class of Job-rejection bug. A pod template's default is `Always`, which is correct for ReplicaSets and Deployments but illegal on a Job. Setting it explicitly to `Never` or `OnFailure` is required. The difference between `Never` and `OnFailure` is whether a failure retries in the same pod (`OnFailure`) or in a new pod (`Never`); the end state is the same, but logs are harder to read across `OnFailure` retries, so `Never` is a good default for exercises unless you need in-place restart semantics.

### backoffLimit vs activeDeadlineSeconds confusion

Both bound failures, but they measure different things. `backoffLimit` counts pod failures: a Job with `backoffLimit: 3` tolerates four total failed pods (one initial plus three retries) before giving up. `activeDeadlineSeconds` is a wall-clock budget across all retries combined: a Job with `activeDeadlineSeconds: 30` is killed 30 seconds after the Job started, regardless of whether the current retry is the first or the sixth. Use `backoffLimit` when you want to stop after a specific number of attempts; use `activeDeadlineSeconds` when you want to cap the total time invested. Both can be set on the same Job; whichever limit is hit first marks the Job Failed, and the `reason` field on the Failed condition tells you which one.

### Cron schedule syntax versus human-readable strings

The `schedule` field requires a five-field cron expression or one of the documented macros. Arbitrary English like `"every 5 minutes"`, `"daily at 3am"`, or `"0 3 ***"` (note the spacing) is rejected. If your schedule is complicated, test it on a cron-expression validator before committing. The five fields, in order, are minute, hour, day-of-month, month, day-of-week; `*` means every, `*/N` means every N, `N-M` is a range, `N,M` is a list.

### Time zone assumptions

Without the `timeZone` field, the CronJob schedule is evaluated in the controller-manager's local time. On kind and most managed Kubernetes clusters that is UTC. A schedule of `"0 9 * * *"` is not "9 AM where I live"; it is "9 AM UTC," which is probably not what you want if you live in California or Tokyo. Always set `timeZone` to an IANA identifier (`America/Los_Angeles`, `Asia/Tokyo`, `Etc/UTC`, and so on) when the schedule matters in local time. `timeZone` has been stable since Kubernetes 1.27. Do not put `CRON_TZ=` or `TZ=` prefixes in the schedule string itself; the API server rejects those.

### Concurrency policy for workloads that share state

`concurrencyPolicy: Allow` is the default and the right choice for independent work (backups that have their own mutex, read-only reports, telemetry). For workloads that contend for shared state (writing to the same file, mutating the same row), `Forbid` is safer: a run in progress blocks the new firing instead of overlapping. `Replace` is for workloads where only the most recent run matters (a health-check-style CronJob; an always-refreshing cache builder). Picking the wrong policy rarely causes immediate errors; it produces subtle wrong results over time.

### startingDeadlineSeconds too tight

The `startingDeadlineSeconds` field protects against the controller catching up on hundreds of missed firings when it comes back from a long outage. A low value (below about 10 seconds) causes nearly every firing to be missed even in normal operation, because the controller has queuing and polling delays. If you want to skip missed firings after downtime, pick a value in the 60-300 second range; lower values are almost never what you want.

### Finding a Job's pods and their logs

The label selector `batch.kubernetes.io/job-name=<job-name>` returns every pod the Job has produced, including failed attempts. `kubectl logs -l batch.kubernetes.io/job-name=<job-name> --tail=-1 --prefix` dumps all of them at once with pod-name prefixes so you can correlate output to attempts. For Indexed Jobs, `batch.kubernetes.io/job-completion-index=<N>` filters to a specific shard. For CronJobs, `batch.kubernetes.io/cronjob-name=<cronjob-name>` is the selector on Jobs (not pods); to reach pods, chain through the Job name.

-----

## Verification Commands Cheat Sheet

### Basic status

```bash
kubectl get job NAME -n NS
kubectl get job NAME -n NS -o wide
kubectl get jobs -n NS -l batch.kubernetes.io/cronjob-name=CRONJOB_NAME
kubectl get cronjob NAME -n NS
kubectl get cronjob NAME -n NS -o yaml
```

### Conditions and terminal status

```bash
# Job reached Complete
kubectl get job NAME -n NS -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}'

# Job reached Failed and its reason
kubectl get job NAME -n NS -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}'
kubectl get job NAME -n NS -o jsonpath='{.status.conditions[?(@.type=="Failed")].reason}'

# Count of successful completions
kubectl get job NAME -n NS -o jsonpath='{.status.succeeded}'

# Count of failed pod attempts
kubectl get job NAME -n NS -o jsonpath='{.status.failed}'
```

### Finding Job pods

```bash
# every pod the Job has produced
kubectl get pods -n NS -l batch.kubernetes.io/job-name=NAME

# a specific index in Indexed mode
kubectl get pods -n NS -l batch.kubernetes.io/job-completion-index=N

# logs from every pod, with pod-name prefix
kubectl logs -n NS -l batch.kubernetes.io/job-name=NAME --tail=-1 --prefix
```

### CronJob inspection

```bash
# last firing time (empty until the first firing)
kubectl get cronjob NAME -n NS -o jsonpath='{.status.lastScheduleTime}'

# currently-running Jobs the CronJob is tracking
kubectl get cronjob NAME -n NS -o jsonpath='{.status.active[*].name}'

# Jobs the CronJob has produced (bounded by history limits)
kubectl get jobs -n NS -l batch.kubernetes.io/cronjob-name=NAME

# suspend state
kubectl get cronjob NAME -n NS -o jsonpath='{.spec.suspend}'
```

### Diagnostic deep dives

```bash
kubectl describe job NAME -n NS        # conditions, events, pod templates
kubectl describe cronjob NAME -n NS    # events including MissingJob (Forbid skips)
kubectl get job NAME -n NS -o yaml     # full spec and status
```

### Quick one-off Jobs from a CronJob

```bash
# manually trigger a Job using a CronJob's template (useful for testing)
kubectl create job --from=cronjob/CRONJOB_NAME MANUAL_JOB_NAME -n NS
```

### Imperative generation

```bash
# Job
kubectl create job NAME --image=IMAGE -n NS
kubectl create job NAME --image=IMAGE --dry-run=client -o yaml -n NS > job.yaml
kubectl create job NAME --image=IMAGE --dry-run=client -o yaml -- sh -c "echo hi" > job.yaml

# CronJob
kubectl create cronjob NAME --image=IMAGE --schedule="*/5 * * * *" -n NS
kubectl create cronjob NAME --image=IMAGE --schedule="@hourly" --dry-run=client -o yaml -n NS > cj.yaml
```

### Common patch examples

```bash
# suspend a CronJob
kubectl patch cronjob NAME -n NS --type=merge -p '{"spec":{"suspend":true}}'

# resume
kubectl patch cronjob NAME -n NS --type=merge -p '{"spec":{"suspend":false}}'

# change schedule
kubectl patch cronjob NAME -n NS --type=merge -p '{"spec":{"schedule":"@hourly"}}'
```
