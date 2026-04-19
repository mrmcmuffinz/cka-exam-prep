# Assignment 1: User and Group Security Contexts

This is the first of three Security Contexts assignments, focused on the identity side of the pod's security configuration. It covers the fields that decide which Linux user, primary group, supplementary groups, and volume group the containers in a pod run as: `runAsUser`, `runAsGroup`, `fsGroup`, `supplementalGroups`, and the validator `runAsNonRoot`. Assignment 2 in the series picks up Linux capabilities and `allowPrivilegeEscalation`; assignment 3 picks up `readOnlyRootFilesystem` and seccomp profiles. Identity is the first concept because every later security control composes with it.

## Files

| File | Purpose |
|---|---|
| `prompt.md` | The generation prompt (input to the homework generator skill) |
| `README.md` | This overview |
| `security-contexts-tutorial.md` | Step-by-step tutorial teaching identity fields and their interaction with volumes |
| `security-contexts-homework.md` | 15 progressive exercises across five difficulty levels |
| `security-contexts-homework-answers.md` | Complete solutions with diagnostic reasoning and common mistakes |

## Recommended Workflow

Work through the tutorial end to end first. It starts with a container running as the image's default user (root, for `busybox`), proves that with `id` inside the container, and then walks through each identity field in turn, showing what changes at runtime when the field is set. The second half of the tutorial pairs identity with an `emptyDir` volume so that the relationship between `runAsUser`, `runAsGroup`, `fsGroup`, and volume ownership becomes mechanical rather than theoretical. Only after completing the tutorial should you attempt the homework. Level 3 debugging exercises assume you can diagnose a permission-denied error by looking at the effective UID/GID inside the container and the ownership on the mounted directory.

## Difficulty Progression

Level 1 exercises apply a single identity field at a time: run as a specific UID, then a specific GID, then verify with `id`. Level 2 introduces volumes, applying `fsGroup` to an `emptyDir` and adding `supplementalGroups` for shared-group access. Level 3 is debugging: the symptom is a write failure or a pod that will not start, and you identify whether the problem is the UID, the GID, or the volume permissions. Level 4 pushes into pod-vs-container precedence and multi-container pods where the containers run as different users. Level 5 is the comprehensive material: design a security context for an application with specific UID/GID requirements, diagnose a multi-container pod with overlapping permission issues, and construct the minimal identity configuration for a hypothetical microservice.

## Prerequisites

Complete `exercises/01-01-pods/assignment-1` (pod fundamentals) and `exercises/01-01-pods/assignment-2` (volume mounts). The exercises assume you can already author a pod spec and mount an `emptyDir` or projected volume; this assignment only adds the `securityContext` layer on top of those skills. Knowledge of Linux UID, GID, and supplementary groups from any general Linux background is assumed; the tutorial reinforces but does not teach these.

## Cluster Requirements

A single-node kind cluster is sufficient for every exercise in this assignment. No additional components are needed. See `docs/cluster-setup.md#single-node-kind-cluster` for the creation command. The container images used (`busybox:1.36`, `nginx:1.25`, `alpine:3.20`) all support being run as a non-root user when configured correctly; some exercises explicitly test what happens when they are not configured correctly.

## Estimated Time Commitment

The tutorial takes about 45 to 60 minutes if you run every command and read every output. The 15 homework exercises together take about four to six hours. Levels 1 and 2 each run 10 to 15 minutes per exercise; Level 3 debugging exercises take 15 to 25 minutes each because the symptoms (permission denied, pod stuck) require you to narrow the failure to a specific field; Level 4 runs 20 to 30 minutes per exercise; Level 5 takes 30 to 45 minutes per exercise because the multi-container and design exercises exercise several fields together.

## Scope Boundary and What Comes Next

This assignment deliberately stops at identity. Linux capabilities (`capabilities.add`, `capabilities.drop`) and `allowPrivilegeEscalation` are covered in `exercises/13-13-security-contexts/assignment-2`. Filesystem constraints (`readOnlyRootFilesystem`) and seccomp profiles (`seccompProfile`) are covered in `exercises/13-13-security-contexts/assignment-3`. The namespace-level policy that enforces these fields cluster-wide (Pod Security Admission) is covered in `exercises/14-14-pod-security/assignment-1`. PersistentVolumes and their interaction with `fsGroup` live in the `exercises/07-storage/` series; this assignment uses only `emptyDir` and projected volumes so that the focus stays on identity rather than storage.

## Key Takeaways After Completing This Assignment

After finishing all 15 exercises you should be able to set `runAsUser` and `runAsGroup` at either pod level or container level and predict which wins when both are present, explain what `runAsNonRoot` validates and why it is not a replacement for `runAsUser`, apply `fsGroup` to an `emptyDir` volume and describe how it changes the group ownership and `g+s` bit on the mount directory, use `supplementalGroups` to add memberships the image does not declare, read the output of `id` inside a pod and tie every number back to a specific field in the pod spec, choose between pod-level and container-level settings based on whether a field should apply uniformly or be overridden per container, and diagnose a permission-denied write by walking through effective UID, effective GID, supplementary groups, and volume ownership in order.
