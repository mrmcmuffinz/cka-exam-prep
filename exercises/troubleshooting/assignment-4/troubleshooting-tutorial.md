# Network Troubleshooting Tutorial

This tutorial covers network-layer troubleshooting: service connectivity, DNS resolution, NetworkPolicy issues, and external access debugging.

## Part 1: Service Connectivity

### Checking Service Endpoints

```bash
kubectl get endpoints <service> -n <namespace>
```

Empty endpoints indicate selector mismatch or pods not ready.

### Service to Pod Debugging

```bash
kubectl get svc <service> -n <namespace> -o yaml
kubectl get pods -n <namespace> --show-labels
```

Compare spec.selector with pod labels.

### Testing Connectivity

From another pod.

```bash
kubectl exec -it <test-pod> -- curl http://<service>.<namespace>.svc.cluster.local
```

## Part 2: DNS Troubleshooting

### Checking CoreDNS

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

### Testing DNS Resolution

```bash
kubectl exec -it <pod> -- nslookup <service>
kubectl exec -it <pod> -- nslookup kubernetes.default
```

### DNS Pod Configuration

Check pod DNS policy.

```bash
kubectl get pod <pod> -o jsonpath='{.spec.dnsPolicy}'
```

## Part 3: NetworkPolicy Issues

### Finding Policies

```bash
kubectl get networkpolicies -A
kubectl describe networkpolicy <policy> -n <namespace>
```

### Common Issues

Default deny blocking traffic, missing egress rule for DNS (port 53), namespaceSelector not matching, podSelector not matching.

### Testing Through Policies

Deploy a debug pod and test connectivity.

```bash
kubectl run test --image=busybox:1.36 --restart=Never -- sleep 3600
kubectl exec test -- wget -T5 -O- http://<target-service>
```

## Part 4: kube-proxy

### Checking kube-proxy

```bash
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy
```

### Verifying Proxy Mode

```bash
kubectl logs -n kube-system -l k8s-app=kube-proxy | grep "Using"
```

Usually shows "Using iptables Proxier" or "Using ipvs Proxier".

## Part 5: External Access

### NodePort Issues

```bash
kubectl get svc <service> -o jsonpath='{.spec.ports[*].nodePort}'
curl http://<node-ip>:<nodeport>
```

### LoadBalancer Issues

```bash
kubectl get svc <service>
```

External IP showing "pending" means no LoadBalancer provider (common in kind).

### Ingress Issues

```bash
kubectl get ingress -A
kubectl describe ingress <name> -n <namespace>
```

Check backend services and paths.

## Reference Commands

| Task | Command |
|------|---------|
| Service endpoints | `kubectl get endpoints <svc> -n <ns>` |
| Service selector | `kubectl get svc <svc> -o jsonpath='{.spec.selector}'` |
| Pod labels | `kubectl get pod <pod> --show-labels` |
| DNS test | `kubectl exec <pod> -- nslookup <service>` |
| CoreDNS logs | `kubectl logs -n kube-system -l k8s-app=kube-dns` |
| NetworkPolicies | `kubectl get networkpolicies -A` |
| kube-proxy logs | `kubectl logs -n kube-system -l k8s-app=kube-proxy` |
