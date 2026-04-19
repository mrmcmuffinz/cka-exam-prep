# Assignment 3: Node and Kubelet Troubleshooting

This assignment is the third in the four-part troubleshooting series. It focuses on node-level issues: NotReady nodes, kubelet failures, container runtime problems, node conditions, and node recovery procedures.

## Prerequisites

Completed cluster-lifecycle assignments. Multi-node kind cluster (3+ workers).

## Cluster Requirements

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
```

## Kind Cluster Note

Kind nodes are containers, not VMs. Kubelet runs inside each kind container. Access nodes with `docker exec kind-worker bash`. Some exercises demonstrate concepts that apply to real clusters.

## Estimated Time

Tutorial: 45-60 minutes. Exercises: 6-8 hours.

## Key Takeaways

Diagnose NotReady nodes, troubleshoot kubelet failures, understand node conditions and taints, perform node drain and recovery, and analyze kubelet logs.
