# Assignment 2: Linux Capabilities and Privilege Escalation

This is the second of three Security Contexts assignments. Assignment 1 covered the identity side of the securityContext (UID, GID, groups, `fsGroup`). This assignment covers what those identities are allowed to do, expressed through Linux capabilities, and how privilege escalation is controlled via `allowPrivilegeEscalation`. Assignment 3 closes the series with filesystem constraints and seccomp profiles. The exam's "application security mechanisms" competency expects familiarity with all three layers.

## Files

| File | Purpose |
|---|---|
| `prompt.md` | The generation prompt (input to the homework generator skill) |
| `README.md` | This overview |
| `security-contexts-tutorial.md` | Step-by-step tutorial teaching capabilities, drop/add patterns, and `allowPrivilegeEscalation` |
| `security-contexts-homework.md` | 15 progressive exercises across five difficulty levels |
| `security-contexts-homework-answers.md` | Complete solutions with diagnostic reasoning and common mistakes |

## Recommended Workflow

Work through the tutorial first. It begins by inspecting the capability set that containerd grants a vanilla container, then walks through adding `NET_ADMIN` to prove it enables a specific operation (`ip link set down`), dropping `NET_RAW` to prove it disables another (`ping` via raw sockets), and then the defense-in-depth drop-ALL-add-specific pattern. The second half demonstrates `allowPrivilegeEscalation: false` in detail, including the counterintuitive interaction with setuid binaries. Only attempt the homework after the tutorial, because Level 3 debugging assumes you can read `/proc/self/status` to identify the capability set a container actually has and map that back to a missing `capabilities.add` or an over-restrictive `capabilities.drop`.

## Difficulty Progression

Level 1 inspects capabilities: read the default set from `/proc/self/status` in one container, compare against a `privileged: true` container, and compare against a container with `drop: [ALL]`. Level 2 is build tasks around adding and dropping specific capabilities: add `NET_ADMIN`, drop `NET_RAW`, and do the drop-ALL-add-specific minimal pattern. Level 3 is debugging: something an application needs to do is failing and you must identify which capability (or lack thereof) is at fault. Level 4 drills on `allowPrivilegeEscalation: false` and its interactions. Level 5 is the comprehensive material: design a minimal capability set for a described application, debug a failure where several security controls interact to block a legal operation, and produce a capability strategy for a multi-container pod.

## Prerequisites

Complete `exercises/security-contexts/assignment-1` first. Some of the exercises use `runAsUser` and `runAsNonRoot` from that assignment without reteaching them. A general familiarity with Linux capabilities (what `CAP_NET_ADMIN`, `CAP_SYS_TIME`, and `CAP_CHOWN` do at the syscall level) is assumed; the tutorial reinforces by showing each one in use but does not teach capabilities from scratch. The `capabilities(7)` man page is an excellent external reference.

## Cluster Requirements

A single-node kind cluster is sufficient for every exercise. See `docs/cluster-setup.md#single-node-kind-cluster` for the creation command. The exercises use `alpine:3.20` and `nicolaka/netshoot:v0.13` pinned tags; the first is small and has `libcap` tools (`capsh`, `getcap`, `setcap`), the second has the full network diagnostic toolkit (`ip`, `tcpdump`, `ping`).

## Estimated Time Commitment

The tutorial takes 45 to 60 minutes. The 15 exercises together take four to six hours. Level 1 runs 10 to 15 minutes per exercise; Level 2 takes 15 to 20 minutes because verifying the effect of each capability change requires running the specific operation inside the container; Level 3 debugging runs 15 to 25 minutes per exercise; Level 4 runs 20 to 30 minutes; Level 5 runs 30 to 45 minutes per exercise.

## Scope Boundary and What Comes Next

This assignment covers Linux capabilities and the `allowPrivilegeEscalation` field. `readOnlyRootFilesystem` and seccomp profiles are the third layer of the container security story, covered in `exercises/security-contexts/assignment-3`. The namespace-level policy that enforces "drop ALL" and "allowPrivilegeEscalation: false" cluster-wide is Pod Security Admission, covered in `exercises/pod-security/assignment-1`. Custom admission policies that enforce capability restrictions via CEL live in `exercises/admission-controllers/assignment-1`. Seccomp profiles specifically are the other half of the syscall-filtering story and are covered in assignment-3.

## Key Takeaways After Completing This Assignment

After finishing all 15 exercises you should be able to list the default capability set granted to a containerd-run container and explain what each of the common capabilities allows at the syscall level, add a single capability via `capabilities.add` and confirm its presence in `/proc/self/status`, drop a single capability via `capabilities.drop` and prove the expected operation fails, apply the defense-in-depth drop-ALL-add-specific pattern and explain why it is considered the hardened baseline, set `allowPrivilegeEscalation: false` and describe the mechanism (Linux `no_new_privs`) and which operations it blocks, read a container's error output when an operation fails for capability reasons and distinguish that from a UID mismatch, debug a failure that combines identity constraints (from assignment 1) with capability constraints, and design a capability configuration for a multi-container pod where different containers need different capability sets.
