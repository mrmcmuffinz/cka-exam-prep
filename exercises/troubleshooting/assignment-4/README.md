# Assignment 4: Network Troubleshooting

This assignment is the fourth and final part of the troubleshooting series. It covers network-layer issues: service connectivity, DNS resolution, NetworkPolicy problems, kube-proxy issues, and external access failures. This is a capstone combining failures from services, DNS, and NetworkPolicy topics.

## Prerequisites

Completed services, coredns, network-policies, and ingress assignments. Multi-node kind cluster with Calico CNI and nginx-ingress installed.

## Cluster Requirements

Multi-node kind cluster with Calico for NetworkPolicy support.

```bash
cat <<EOF | KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
networking:
  disableDefaultCNI: true
EOF

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.5/manifests/calico.yaml
```

## Estimated Time

Tutorial: 45-60 minutes. Exercises: 6-8 hours.

## Key Takeaways

Debug service connectivity issues, troubleshoot DNS resolution failures, diagnose NetworkPolicy blocking traffic, verify kube-proxy operation, and debug external access problems.
