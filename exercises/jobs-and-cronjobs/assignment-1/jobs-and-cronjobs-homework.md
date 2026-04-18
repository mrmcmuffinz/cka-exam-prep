# Jobs and CronJobs Homework

This homework file contains 15 progressive exercises organized into five difficulty levels. The exercises assume you have worked through `jobs-and-cronjobs-tutorial.md`. Each exercise uses its own namespace so working on one does not disturb any other. Complete them in order; the progression is designed to build the diagnostic instincts needed for Level 5.

## Setup

Verify the cluster is running.

```bash
kubectl get nodes
# Expected: at least one node, STATUS Ready
```

To clear leftover exercise namespaces from a prior attempt before starting, run the global cleanup. Safe to run any time.

```bash
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done
```

-----

## Level 1: Basic Single-Concept Tasks

### Exercise 1.1

**Objective:** Create a Job named `greeter` in namespace `ex-1-1` that runs `busybox:1.36`, prints `hello from homework` exactly once, and ends with a successful completion.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:**

The Job must have exactly one successful completion. Pick a `restartPolicy` that lets the pod exit cleanly and stay exited. The Job's pod template may use either the container image default command or an explicit `command` and `args`; either is fine as long as the final output on pod logs is the literal string `hello from homework`.

**Verification:**

```bash
# Job reached Complete condition
kubectl get job greeter -n ex-1-1 -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}'; echo
# Expected: True

# exactly one successful completion
kubectl get job greeter -n ex-1-1 -o jsonpath='{.status.succeeded}'; echo
# Expected: 1

# log output contains the literal greeting
kubectl logs -l batch.kubernetes.io/job-name=greeter -n ex-1-1 --tail=-1
# Expected: hello from homework

# restartPolicy is OnFailure or Never
kubectl get job greeter -n ex-1-1 -o jsonpath='{.spec.template.spec.restartPolicy}'; echo
# Expected: Never (or OnFailure)
```

-----

### Exercise 1.2

**Objective:** Create a Job named `retrier` in namespace `ex-1-2` that always exits with a nonzero status, and configure it so that the Job is marked Failed after exactly three total pod failures (the initial attempt plus two retries).

**Setup:**

```bash
kubectl create namespace ex-1-2
```

**Task:**

The Job must use `busybox:1.36` and run a command that exits with code 1. Configure `backoffLimit` so that three pod failures trigger the Job's Failed condition. Use `restartPolicy: Never` so that each retry creates a new pod (easier to count than the in-place restart form).

**Verification:**

```bash
# wait for terminal state (exponential backoff adds delay)
sleep 120

# Job reached Failed condition
kubectl get job retrier -n ex-1-2 -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}'; echo
# Expected: True

# Failed reason is BackoffLimitExceeded
kubectl get job retrier -n ex-1-2 -o jsonpath='{.status.conditions[?(@.type=="Failed")].reason}'; echo
# Expected: BackoffLimitExceeded

# backoffLimit is 2 (initial + 2 retries = 3 total failures)
kubectl get job retrier -n ex-1-2 -o jsonpath='{.spec.backoffLimit}'; echo
# Expected: 2

# exactly 3 failed pods exist
kubectl get pods -n ex-1-2 -l batch.kubernetes.io/job-name=retrier --no-headers | wc -l
# Expected: 3
```

-----

### Exercise 1.3

**Objective:** Create a CronJob named `hourly-tick` in namespace `ex-1-3` that uses the `@hourly` macro schedule and runs `busybox:1.36` printing the string `tick`.

**Setup:**

```bash
kubectl create namespace ex-1-3
```

**Task:**

Use the `@hourly` macro for the schedule (equivalent to `0 * * * *`). The CronJob does not need to fire during the exercise; the objective is to verify the spec is correct and accepted by the API server. The Job template must specify `restartPolicy: Never` or `OnFailure`.

**Verification:**

```bash
# CronJob exists with the @hourly schedule
kubectl get cronjob hourly-tick -n ex-1-3 -o jsonpath='{.spec.schedule}'; echo
# Expected: @hourly

# container image is busybox:1.36
kubectl get cronjob hourly-tick -n ex-1-3 -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}'; echo
# Expected: busybox:1.36

# restartPolicy is OnFailure or Never
kubectl get cronjob hourly-tick -n ex-1-3 -o jsonpath='{.spec.jobTemplate.spec.template.spec.restartPolicy}'; echo
# Expected: Never (or OnFailure)

# CronJob is accepted (LAST SCHEDULE is empty until it fires, that is fine)
kubectl get cronjob hourly-tick -n ex-1-3
# Expected: row appears with SCHEDULE @hourly and no errors
```

-----

## Level 2: Multi-Concept Tasks

### Exercise 2.1

**Objective:** Create a Job named `parallel-adder` in namespace `ex-2-1` that runs 6 total successful completions with up to 3 pods concurrently, producing 6 log lines across all pods.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:**

The Job uses `busybox:1.36`. Each pod prints the string `worker ready` and exits with code 0. Configure `completions: 6` and `parallelism: 3`. Use `restartPolicy: Never`.

**Verification:**

```bash
kubectl wait --for=condition=Complete job/parallel-adder -n ex-2-1 --timeout=120s
# Expected: job.batch/parallel-adder condition met

# 6 successful completions
kubectl get job parallel-adder -n ex-2-1 -o jsonpath='{.status.succeeded}'; echo
# Expected: 6

# parallelism is 3
kubectl get job parallel-adder -n ex-2-1 -o jsonpath='{.spec.parallelism}'; echo
# Expected: 3

# 6 total pods (one per completion)
kubectl get pods -n ex-2-1 -l batch.kubernetes.io/job-name=parallel-adder --no-headers | wc -l
# Expected: 6

# every pod log contains the literal string "worker ready"
kubectl logs -n ex-2-1 -l batch.kubernetes.io/job-name=parallel-adder --tail=-1 | grep -c "worker ready"
# Expected: 6
```

-----

### Exercise 2.2

**Objective:** Create a Job named `shardwork` in namespace `ex-2-2` that uses Indexed completion mode to process four shards in parallel, with each pod printing its shard index.

**Setup:**

```bash
kubectl create namespace ex-2-2
```

**Task:**

Configure `completions: 4`, `parallelism: 4`, and `completionMode: Indexed`. Each pod must print a line of the form `processing shard N` where N is the value of `$JOB_COMPLETION_INDEX`. Use `busybox:1.36`. The pod command should read the env var, print the message, and exit cleanly.

**Verification:**

```bash
kubectl wait --for=condition=Complete job/shardwork -n ex-2-2 --timeout=120s
# Expected: job.batch/shardwork condition met

# 4 successful completions
kubectl get job shardwork -n ex-2-2 -o jsonpath='{.status.succeeded}'; echo
# Expected: 4

# completionMode is Indexed
kubectl get job shardwork -n ex-2-2 -o jsonpath='{.spec.completionMode}'; echo
# Expected: Indexed

# each shard's pod logged its own index
for i in 0 1 2 3; do
  kubectl logs -n ex-2-2 -l batch.kubernetes.io/job-completion-index=$i --tail=1
done
# Expected: four lines, one per index, each in the form "processing shard N"
```

-----

### Exercise 2.3

**Objective:** Create a CronJob named `trimmed-nightly` in namespace `ex-2-3` with a schedule, concurrency policy, and history limits all explicitly set.

**Setup:**

```bash
kubectl create namespace ex-2-3
```

**Task:**

The CronJob must have `schedule: "@daily"`, `concurrencyPolicy: Forbid`, `successfulJobsHistoryLimit: 2`, and `failedJobsHistoryLimit: 0`. The Job template uses `busybox:1.36` and runs a trivial command that exits 0. The CronJob does not need to fire during the exercise; the objective is spec correctness.

**Verification:**

```bash
# schedule
kubectl get cronjob trimmed-nightly -n ex-2-3 -o jsonpath='{.spec.schedule}'; echo
# Expected: @daily

# concurrencyPolicy
kubectl get cronjob trimmed-nightly -n ex-2-3 -o jsonpath='{.spec.concurrencyPolicy}'; echo
# Expected: Forbid

# successfulJobsHistoryLimit
kubectl get cronjob trimmed-nightly -n ex-2-3 -o jsonpath='{.spec.successfulJobsHistoryLimit}'; echo
# Expected: 2

# failedJobsHistoryLimit
kubectl get cronjob trimmed-nightly -n ex-2-3 -o jsonpath='{.spec.failedJobsHistoryLimit}'; echo
# Expected: 0
```

-----

## Level 3: Debugging Broken Configurations

### Exercise 3.1

**Objective:** The setup below creates a Job that does not reach `Complete`. Diagnose the issue and fix it so that the Job runs to one successful completion.

**Setup:**

```bash
kubectl create namespace ex-3-1

cat <<'EOF' | kubectl apply -n ex-3-1 -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: broken-1
spec:
  template:
    spec:
      restartPolicy: Always
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c", "echo hello; exit 0"]
EOF
```

**Task:**

Fix whatever prevents the Job from reaching `Complete`. The Job must keep the name `broken-1` in namespace `ex-3-1`, keep `busybox:1.36` as the image, keep the container name `worker`, and keep `exit 0` so the completion succeeds.

**Verification:**

```bash
# Job reached Complete condition
kubectl get job broken-1 -n ex-3-1 -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}'; echo
# Expected: True

# one successful completion
kubectl get job broken-1 -n ex-3-1 -o jsonpath='{.status.succeeded}'; echo
# Expected: 1

# restartPolicy is now OnFailure or Never
kubectl get job broken-1 -n ex-3-1 -o jsonpath='{.spec.template.spec.restartPolicy}'; echo
# Expected: Never (or OnFailure)
```

-----

### Exercise 3.2

**Objective:** The setup below attempts to create a CronJob that the API server rejects. Diagnose why and produce a corrected CronJob.

**Setup:**

```bash
kubectl create namespace ex-3-2

# This manifest is deliberately broken; the apply command will fail.
cat <<'EOF' | kubectl apply -n ex-3-2 -f - || true
apiVersion: batch/v1
kind: CronJob
metadata:
  name: broken-2
spec:
  schedule: "every 5 minutes"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: ticker
            image: busybox:1.36
            command: ["sh", "-c", "echo tick"]
EOF
```

**Task:**

Produce a correctly-formed CronJob named `broken-2` in namespace `ex-3-2` that fires every 5 minutes (interpreted as an actual cron expression). Keep `busybox:1.36` as the image and `ticker` as the container name. Use either the `*/5 * * * *` cron expression or a macro that fires at least as often (not `@hourly`).

**Verification:**

```bash
# CronJob exists
kubectl get cronjob broken-2 -n ex-3-2
# Expected: row appears with no errors

# schedule fires every 5 minutes or more often
kubectl get cronjob broken-2 -n ex-3-2 -o jsonpath='{.spec.schedule}'; echo
# Expected: */5 * * * *

# image unchanged
kubectl get cronjob broken-2 -n ex-3-2 -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}'; echo
# Expected: busybox:1.36
```

-----

### Exercise 3.3

**Objective:** The setup below creates a Job that is marked Failed long before its work completes. Diagnose the cause and fix the Job so it runs to a successful completion.

**Setup:**

```bash
kubectl create namespace ex-3-3

cat <<'EOF' | kubectl apply -n ex-3-3 -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: broken-3
spec:
  activeDeadlineSeconds: 3
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: slow
        image: busybox:1.36
        command: ["sh", "-c", "echo starting; sleep 15; echo finished"]
EOF
```

**Task:**

The intent is that the container prints `starting`, sleeps 15 seconds, prints `finished`, and the Job completes successfully. Adjust the spec so this intent is realized. You may keep or change `activeDeadlineSeconds` as needed, but the sleep must remain 15 seconds and the container must run to completion. Keep the name `broken-3` and the container name `slow`.

**Verification:**

```bash
sleep 25
# Job reached Complete condition
kubectl get job broken-3 -n ex-3-3 -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}'; echo
# Expected: True

# one successful completion
kubectl get job broken-3 -n ex-3-3 -o jsonpath='{.status.succeeded}'; echo
# Expected: 1

# logs contain both starting and finished
kubectl logs -n ex-3-3 -l batch.kubernetes.io/job-name=broken-3 --tail=-1 | grep -E '^(starting|finished)$'
# Expected: two lines, starting then finished
```

-----

## Level 4: Complex Real-World Scenarios

### Exercise 4.1

**Objective:** Build a parallel processing Job named `shard-map` in namespace `ex-4-1` that maps a set of inputs to outputs using Indexed completion mode.

**Setup:**

```bash
kubectl create namespace ex-4-1
```

**Task:**

Create a Job with `completions: 5`, `parallelism: 5`, `completionMode: Indexed`. Each pod uses `busybox:1.36` and its shell command reads `$JOB_COMPLETION_INDEX` and prints a line of the form `shard N of 5 processed` where N is the zero-based index. The Job must use `restartPolicy: Never`, set `backoffLimit: 0` (because inputs are idempotent here, a retry is wasted work), and set `ttlSecondsAfterFinished: 300` so that the Job cleans itself up five minutes after completion.

**Verification:**

```bash
kubectl wait --for=condition=Complete job/shard-map -n ex-4-1 --timeout=120s
# Expected: job.batch/shard-map condition met

# Job config
kubectl get job shard-map -n ex-4-1 -o jsonpath='{.spec.completions}'; echo
# Expected: 5
kubectl get job shard-map -n ex-4-1 -o jsonpath='{.spec.parallelism}'; echo
# Expected: 5
kubectl get job shard-map -n ex-4-1 -o jsonpath='{.spec.completionMode}'; echo
# Expected: Indexed
kubectl get job shard-map -n ex-4-1 -o jsonpath='{.spec.backoffLimit}'; echo
# Expected: 0
kubectl get job shard-map -n ex-4-1 -o jsonpath='{.spec.ttlSecondsAfterFinished}'; echo
# Expected: 300

# 5 successful completions
kubectl get job shard-map -n ex-4-1 -o jsonpath='{.status.succeeded}'; echo
# Expected: 5

# all five shard log lines present
kubectl logs -n ex-4-1 -l batch.kubernetes.io/job-name=shard-map --tail=-1 | grep -E "^shard [0-4] of 5 processed$" | sort -u | wc -l
# Expected: 5
```

-----

### Exercise 4.2

**Objective:** Build a daily backup CronJob named `daily-backup` in namespace `ex-4-2` with appropriate concurrency and history configuration.

**Setup:**

```bash
kubectl create namespace ex-4-2
```

**Task:**

The CronJob runs at `@daily` in the `America/Los_Angeles` time zone. It uses `busybox:1.36` and runs a command that prints `backup complete at $(date -u +%FT%TZ)` and exits 0. Because backups overlap badly (they contend for the same shared state), use `concurrencyPolicy: Forbid`. Retain the three most recent successful runs and the one most recent failed run. Give each spawned Job a 7-day TTL via `ttlSecondsAfterFinished` (604800 seconds).

**Verification:**

```bash
# schedule and time zone
kubectl get cronjob daily-backup -n ex-4-2 -o jsonpath='{.spec.schedule}'; echo
# Expected: @daily
kubectl get cronjob daily-backup -n ex-4-2 -o jsonpath='{.spec.timeZone}'; echo
# Expected: America/Los_Angeles

# concurrency
kubectl get cronjob daily-backup -n ex-4-2 -o jsonpath='{.spec.concurrencyPolicy}'; echo
# Expected: Forbid

# history limits
kubectl get cronjob daily-backup -n ex-4-2 -o jsonpath='{.spec.successfulJobsHistoryLimit}'; echo
# Expected: 3
kubectl get cronjob daily-backup -n ex-4-2 -o jsonpath='{.spec.failedJobsHistoryLimit}'; echo
# Expected: 1

# Job TTL
kubectl get cronjob daily-backup -n ex-4-2 -o jsonpath='{.spec.jobTemplate.spec.ttlSecondsAfterFinished}'; echo
# Expected: 604800

# image
kubectl get cronjob daily-backup -n ex-4-2 -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}'; echo
# Expected: busybox:1.36
```

-----

### Exercise 4.3

**Objective:** Build a Job named `bounded-run` in namespace `ex-4-3` that must fail after a bounded time budget if it does not complete, so the controller never blocks on a stuck run.

**Setup:**

```bash
kubectl create namespace ex-4-3
```

**Task:**

Create a Job with `backoffLimit: 1` and `activeDeadlineSeconds: 20`. The pod uses `busybox:1.36` and runs a command that prints `working` and then sleeps for 60 seconds (so the deadline fires before the sleep ends). Use `restartPolicy: Never`. The Job must transition to the Failed condition with reason `DeadlineExceeded`.

**Verification:**

```bash
sleep 30
# Failed condition true
kubectl get job bounded-run -n ex-4-3 -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}'; echo
# Expected: True

# Failed reason is DeadlineExceeded
kubectl get job bounded-run -n ex-4-3 -o jsonpath='{.status.conditions[?(@.type=="Failed")].reason}'; echo
# Expected: DeadlineExceeded

# activeDeadlineSeconds is 20
kubectl get job bounded-run -n ex-4-3 -o jsonpath='{.spec.activeDeadlineSeconds}'; echo
# Expected: 20
```

-----

## Level 5: Advanced Debugging and Comprehensive Tasks

### Exercise 5.1

**Objective:** Build a CronJob named `complete-spec` in namespace `ex-5-1` that uses every commonly-tested CronJob field correctly.

**Setup:**

```bash
kubectl create namespace ex-5-1
```

**Task:**

The CronJob must satisfy all of the following, simultaneously:

- `schedule`: `*/2 * * * *`
- `timeZone`: `Etc/UTC`
- `concurrencyPolicy`: `Replace`
- `startingDeadlineSeconds`: `60`
- `successfulJobsHistoryLimit`: `5`
- `failedJobsHistoryLimit`: `2`
- `suspend`: `false`
- The Job template uses `busybox:1.36`, `restartPolicy: OnFailure`, a container named `runner`, and a command that prints `iteration at $(date -u +%H:%M:%S)` and exits 0.
- The spawned Job itself has `ttlSecondsAfterFinished: 600`.

**Verification:**

```bash
# schedule and timeZone
kubectl get cronjob complete-spec -n ex-5-1 -o jsonpath='{.spec.schedule}'; echo
# Expected: */2 * * * *
kubectl get cronjob complete-spec -n ex-5-1 -o jsonpath='{.spec.timeZone}'; echo
# Expected: Etc/UTC

# concurrencyPolicy
kubectl get cronjob complete-spec -n ex-5-1 -o jsonpath='{.spec.concurrencyPolicy}'; echo
# Expected: Replace

# startingDeadlineSeconds
kubectl get cronjob complete-spec -n ex-5-1 -o jsonpath='{.spec.startingDeadlineSeconds}'; echo
# Expected: 60

# history limits
kubectl get cronjob complete-spec -n ex-5-1 -o jsonpath='{.spec.successfulJobsHistoryLimit}'; echo
# Expected: 5
kubectl get cronjob complete-spec -n ex-5-1 -o jsonpath='{.spec.failedJobsHistoryLimit}'; echo
# Expected: 2

# suspend is false
kubectl get cronjob complete-spec -n ex-5-1 -o jsonpath='{.spec.suspend}'; echo
# Expected: false

# container config
kubectl get cronjob complete-spec -n ex-5-1 -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].name}'; echo
# Expected: runner
kubectl get cronjob complete-spec -n ex-5-1 -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}'; echo
# Expected: busybox:1.36
kubectl get cronjob complete-spec -n ex-5-1 -o jsonpath='{.spec.jobTemplate.spec.template.spec.restartPolicy}'; echo
# Expected: OnFailure

# Job TTL
kubectl get cronjob complete-spec -n ex-5-1 -o jsonpath='{.spec.jobTemplate.spec.ttlSecondsAfterFinished}'; echo
# Expected: 600

# wait for a firing and observe at least one Job was created
sleep 150
kubectl get jobs -n ex-5-1 -l batch.kubernetes.io/cronjob-name=complete-spec --no-headers | wc -l
# Expected: a number >= 1 (exact count depends on how long you waited)
```

-----

### Exercise 5.2

**Objective:** The setup below creates a Job with more than one problem. Diagnose every problem, fix them all, and get the Job into the intended working state.

**Setup:**

```bash
kubectl create namespace ex-5-2

cat <<'EOF' | kubectl apply -n ex-5-2 -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: multibug
spec:
  completions: 3
  parallelism: 3
  completionMode: Indexed
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Always
      containers:
      - name: worker
        image: busybox:2.99
        command: ["echo processing shard $JOB_COMPLETION_INDEX; exit 0"]
EOF
```

**Task:**

The intent for this Job is: three parallel pods run in Indexed mode, each prints `processing shard N` for its index, and all three reach successful completion. Fix every problem in the spec so that intent is realized. The Job must keep the name `multibug` in namespace `ex-5-2`, keep `completions: 3` and `parallelism: 3`, keep `completionMode: Indexed`, keep the container name `worker`, and use a valid `busybox` tag.

**Verification:**

```bash
kubectl wait --for=condition=Complete job/multibug -n ex-5-2 --timeout=120s
# Expected: job.batch/multibug condition met

# 3 successful completions
kubectl get job multibug -n ex-5-2 -o jsonpath='{.status.succeeded}'; echo
# Expected: 3

# restartPolicy is now valid for a Job
kubectl get job multibug -n ex-5-2 -o jsonpath='{.spec.template.spec.restartPolicy}'; echo
# Expected: Never (or OnFailure)

# image is a real busybox tag
kubectl get job multibug -n ex-5-2 -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
# Expected: busybox:1.36 (or another real tag, not 2.99)

# each shard logged its index
for i in 0 1 2; do
  kubectl logs -n ex-5-2 -l batch.kubernetes.io/job-completion-index=$i --tail=1
done
# Expected: three lines, each in the form "processing shard N"
```

-----

### Exercise 5.3

**Objective:** The setup below creates a CronJob that should be firing every minute but is not producing any Jobs. Diagnose why and fix it so that at least one Job is created within two minutes.

**Setup:**

```bash
kubectl create namespace ex-5-3

cat <<'EOF' | kubectl apply -n ex-5-3 -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: silent
spec:
  schedule: "*/1 * * * *"
  suspend: true
  startingDeadlineSeconds: 1
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
EOF
```

**Task:**

The intent for this CronJob is that it fires every minute and produces a Job that runs for two minutes. The current spec prevents any Job from ever being created. Fix whatever is needed so that at least one Job is created within two minutes of the fix. The CronJob must keep the name `silent` in namespace `ex-5-3`, keep a schedule that fires at least every minute, and keep `busybox:1.36` as the image. You may relax fields that are blocking Job creation, but `concurrencyPolicy: Forbid` is correct for the workload and should stay.

**Verification:**

```bash
# wait at least two minutes after the fix for a Job to be created
sleep 150

# CronJob is not suspended
kubectl get cronjob silent -n ex-5-3 -o jsonpath='{.spec.suspend}'; echo
# Expected: false

# schedule still fires at least every minute
kubectl get cronjob silent -n ex-5-3 -o jsonpath='{.spec.schedule}'; echo
# Expected: */1 * * * *

# concurrency policy unchanged
kubectl get cronjob silent -n ex-5-3 -o jsonpath='{.spec.concurrencyPolicy}'; echo
# Expected: Forbid

# at least one Job was created
kubectl get jobs -n ex-5-3 -l batch.kubernetes.io/cronjob-name=silent --no-headers | wc -l
# Expected: a number >= 1

# LAST SCHEDULE is populated on the CronJob
kubectl get cronjob silent -n ex-5-3 -o jsonpath='{.status.lastScheduleTime}'; echo
# Expected: a non-empty RFC3339 timestamp
```

-----

## Cleanup

Delete the exercise namespaces.

```bash
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done
```

-----

## Key Takeaways

Jobs and CronJobs are the API's way of saying "run this to completion" rather than "keep this running." Every field on the Job spec exists to bound that run: `completions` bounds how much work gets done, `parallelism` bounds how much runs concurrently, `backoffLimit` bounds the retry budget, `activeDeadlineSeconds` bounds the wall-clock budget, `ttlSecondsAfterFinished` bounds how long the result is kept. A Job that fails to complete is almost always a case of one of those bounds being too tight or `restartPolicy: Always` leaking in from the pod default (where it is rejected because it contradicts finite-duration semantics).

CronJobs add a time dimension. The `schedule` expression is just cron (plus macros and the `timeZone` field since 1.27). `concurrencyPolicy` controls what happens when a firing arrives while the previous is still running; history limits control what happens when Jobs accumulate; `startingDeadlineSeconds` protects against runaway catch-up when the controller has been down. The most common failure mode for "my CronJob is not firing" is the combination of a tight `startingDeadlineSeconds` and a recently-restarted controller, `suspend: true` left over from debugging, or a schedule the API accepted but that does not mean what the author thought it meant.

Move to the answer key only after genuine attempts. The answer key explains the diagnostic path as well as the fix, which is the skill the exam actually tests.
