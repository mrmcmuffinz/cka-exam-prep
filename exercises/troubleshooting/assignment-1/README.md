# Assignment 1: Application Troubleshooting

This assignment is the first in a four-part troubleshooting series for CKA exam preparation. It focuses on application-layer troubleshooting: diagnosing pod failure states, analyzing crash logs and events, identifying resource exhaustion, fixing configuration issues, resolving volume mount failures, and correcting service selector mismatches. This is a capstone assignment that combines failures from multiple topic areas.

## File Overview

The assignment is split across four files. `README.md` (this file) gives you the map. `troubleshooting-tutorial.md` walks through troubleshooting methodology, failure states, diagnostic commands, and systematic approaches. `troubleshooting-homework.md` contains 15 progressive exercises, all debugging scenarios with broken configurations to fix. `troubleshooting-homework-answers.md` contains complete diagnostic workflows and solutions.

## Recommended Workflow

Work through the tutorial first to learn the systematic troubleshooting approach. All 15 exercises are debugging exercises where you must diagnose and fix broken configurations. Exercise headings are intentionally bare (Exercise 1.1, Exercise 3.2, etc.) to avoid spoiling what the problem is.

## Difficulty Progression

Level 1 exercises have single, clear failures: a pod crashing due to wrong command, a pod pending due to missing PVC, a service with empty endpoints. Level 2 exercises involve configuration issues: missing ConfigMap, wrong Secret key, environment variable typos. Level 3 exercises cover resource and image issues: OOMKilled, ImagePullBackOff, resource quota blocking. Level 4 exercises present multi-factor failures where two things are wrong. Level 5 exercises are complex multi-tier application scenarios with multiple failures to find and fix.

## Prerequisites

You need a running multi-node kind cluster, kubectl configured to talk to it, and familiarity with all previous CKA topics. This is a capstone assignment that assumes knowledge from pods, deployments, services, ConfigMaps, Secrets, PersistentVolumes, and other core topics.

## Cluster Requirements

This assignment requires a multi-node kind cluster with metrics-server installed for resource monitoring.

```bash
cat <<EOF | KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
EOF

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

## Estimated Time Commitment

Plan for about 45 to 60 minutes to work through the tutorial. The 15 debugging exercises should take roughly six to eight hours, as each requires careful diagnosis and systematic problem-solving.

## Scope Boundary

This assignment covers application-layer troubleshooting only. Control plane failures are covered in assignment-2. Node and kubelet issues are covered in assignment-3. Network troubleshooting is covered in assignment-4.

## Key Takeaways After Completing This Assignment

By the time you finish all 15 exercises, you should be able to quickly identify pod failure states and their causes, use kubectl logs effectively including --previous for crash logs, interpret kubectl describe output especially the Events section, diagnose OOMKilled and resource exhaustion issues, find and fix ConfigMap and Secret reference errors, troubleshoot PVC binding and volume mount failures, debug service selector mismatches and empty endpoints, and apply a systematic troubleshooting methodology.
