# Assignment 2: Helm Lifecycle Management

This assignment is the second in the three-part Helm series for CKA exam preparation. It covers the complete release lifecycle: upgrading releases with new values or chart versions, using values files, understanding --reuse-values vs --reset-values, rolling back to previous revisions, viewing release history, and uninstalling releases. The assignment assumes you have completed assignment-1 (Helm Basics) and are comfortable with chart installation and inspection.

## File Overview

The assignment is split across four files. `README.md` (this file) gives you the map. `helm-tutorial.md` walks through the complete lifecycle of a Helm release from upgrade through rollback and uninstall. `helm-homework.md` contains 15 progressive exercises organized into five difficulty levels. `helm-homework-answers.md` contains complete solutions, common mistakes, and a lifecycle commands cheat sheet.

## Recommended Workflow

Work through the tutorial first, end to end, in your own cluster. The tutorial uses a dedicated namespace (`tutorial-helm`) that will not collide with any exercise namespaces. Once the tutorial is complete, start the homework from Level 1 and work forward. Use the answer key only after you have genuinely attempted an exercise.

## Difficulty Progression

Level 1 exercises cover upgrade operations: upgrading with new values and using dry-run to preview changes. Level 2 exercises focus on values files: creating files, combining with --set, and using multiple values files. Level 3 exercises are debugging scenarios involving failed upgrades or incorrect values. Level 4 exercises cover rollback operations and understanding how revisions work. Level 5 exercises present complete lifecycle scenarios that require managing a release through multiple states.

## Prerequisites

You need a running kind cluster created with rootless nerdctl, kubectl configured to talk to it, and the Helm CLI installed. You should have completed 05-helm/assignment-1 (Helm Basics) so that repository management, installation, and basic --set usage are familiar.

## Cluster Requirements

This assignment uses a single-node kind cluster. Create one with the following command if you do not already have a cluster running.

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## Estimated Time Commitment

Plan for about 45 to 60 minutes to work through the tutorial attentively. The 15 exercises combined should take roughly four to six hours.

## Scope Boundary

This assignment covers lifecycle management: upgrade, rollback, values files, release history, and uninstall. Installation basics, repository management, and --set usage are assumed from assignment-1. Helm template rendering, hooks, and debugging techniques are covered in assignment-3.

## Key Takeaways After Completing This Assignment

By the time you finish all 15 exercises, you should be able to upgrade releases with new configuration values, use values files instead of multiple --set flags, combine values files with --set overrides, understand when to use --reuse-values vs --reset-values, preview changes with --dry-run before applying them, roll back to any previous revision, understand that rollback creates a new revision, view release history and understand revision numbers, and cleanly uninstall releases.
