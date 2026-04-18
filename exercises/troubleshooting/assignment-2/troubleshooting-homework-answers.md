# Control Plane Troubleshooting Homework Answers

This file contains solutions and diagnostic workflows for all 15 exercises.

-----

## Exercise 1.1 Solution

```bash
kubectl get pods -n kube-system -o wide | grep -E "(apiserver|scheduler|controller-manager|etcd)"
```

All components should show Running status. To get images.

```bash
kubectl get pods -n kube-system -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}' | grep -E "(apiserver|scheduler|controller-manager|etcd)"
```

-----

## Exercise 1.2 Solution

```bash
kubectl logs -n kube-system $(kubectl get pods -n kube-system -l component=kube-scheduler -o name) | grep -i leader
```

Look for "successfully acquired lease" indicating this scheduler is the leader, or "failed to acquire lease" if it is a follower in HA setup.

-----

## Exercise 1.3 Solution

```bash
kubectl get pods -n kube-system -o wide | grep -E "(apiserver|scheduler|controller-manager|etcd)" | awk '{print $1, $7}'
```

In a single control plane cluster, all components run on the same node (the control plane node).

-----

## Exercise 2.1 Solution

```bash
docker exec kind-control-plane ls -la /etc/kubernetes/manifests/
```

You should see: etcd.yaml, kube-apiserver.yaml, kube-controller-manager.yaml, kube-scheduler.yaml.

-----

## Exercise 2.2 Solution

```bash
docker exec kind-control-plane cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -A100 "command:" | head -60
```

Key arguments include: --advertise-address, --etcd-servers, --service-cluster-ip-range, --tls-cert-file, --tls-private-key-file.

-----

## Exercise 2.3 Solution

```bash
docker exec kind-control-plane cat /etc/kubernetes/manifests/etcd.yaml | grep data-dir
```

Typically: --data-dir=/var/lib/etcd. This is where etcd stores cluster state.

-----

## Exercise 3.1 Solution

Diagnostic workflow for pods not scheduling.

1. Check if scheduler is running.
```bash
kubectl get pods -n kube-system | grep scheduler
```

2. Check scheduler logs.
```bash
kubectl logs -n kube-system $(kubectl get pods -n kube-system -l component=kube-scheduler -o name)
```

3. Check pending pods.
```bash
kubectl get pods --all-namespaces | grep Pending
kubectl describe pod <pending-pod> -n <namespace>
```

4. Check node conditions.
```bash
kubectl get nodes
kubectl describe nodes | grep -A5 "Conditions:"
```

Scheduler problem indicators: scheduler pod not running, scheduler logs show errors, no scheduling decisions in events.

Node problem indicators: scheduler running but nodes show NotReady, nodes have resource pressure, all nodes are tainted.

-----

## Exercise 3.2 Solution

```bash
kubectl logs -n kube-system $(kubectl get pods -n kube-system -l component=kube-controller-manager -o name) | tail -50
```

Look for: "error" messages, "failed to sync" messages, RBAC denials, and reconciliation failures.

Symptoms of controller manager issues: Deployments not creating ReplicaSets, Services not having endpoints, resources stuck in terminating state.

-----

## Exercise 3.3 Solution

When kubectl returns connection errors.

1. Check if API server container is running (access node directly).
```bash
docker exec kind-control-plane crictl ps | grep kube-apiserver
```

2. Check API server logs.
```bash
docker exec kind-control-plane crictl logs <apiserver-container-id>
```

3. Check API server manifest.
```bash
docker exec kind-control-plane cat /etc/kubernetes/manifests/kube-apiserver.yaml
```

4. Check kubelet logs.
```bash
docker exec kind-control-plane journalctl -u kubelet | tail -100
```

5. Verify certificates.
```bash
docker exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates
```

-----

## Exercise 4.1 Solution

On kind clusters, access certificates directly.

```bash
docker exec kind-control-plane bash -c 'for cert in /etc/kubernetes/pki/*.crt; do echo "=== $cert ==="; openssl x509 -in $cert -noout -subject -dates; done'
```

In kubeadm clusters: `kubeadm certs check-expiration`.

-----

## Exercise 4.2 Solution

```bash
docker exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text | grep -A1 "Subject Alternative Name"
```

SANs typically include: kubernetes, kubernetes.default, kubernetes.default.svc, kubernetes.default.svc.cluster.local, control plane IP, and 10.96.0.1 (service IP).

-----

## Exercise 4.3 Solution

```bash
docker exec kind-control-plane openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/apiserver.crt
```

Should output: "/etc/kubernetes/pki/apiserver.crt: OK"

If verification fails, the certificate was not signed by the cluster CA.

-----

## Exercise 5.1 Solution

API Server Diagnostic Workflow.

1. Network connectivity check.
```bash
curl -k https://<apiserver-ip>:6443/healthz
```

2. Container status.
```bash
docker exec kind-control-plane crictl ps | grep kube-apiserver
docker exec kind-control-plane crictl ps -a | grep kube-apiserver  # includes stopped
```

3. Container logs.
```bash
docker exec kind-control-plane crictl logs <container-id>
```

4. Certificate check.
```bash
docker exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates
```

5. etcd connectivity.
```bash
docker exec kind-control-plane crictl exec <etcd-container-id> etcdctl endpoint health --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key
```

6. Kubelet status.
```bash
docker exec kind-control-plane systemctl status kubelet
docker exec kind-control-plane journalctl -u kubelet | tail -50
```

-----

## Exercise 5.2 Solution

etcd Troubleshooting.

1. Check etcd container status.
```bash
docker exec kind-control-plane crictl ps | grep etcd
```

2. Check etcd logs.
```bash
docker exec kind-control-plane crictl logs <etcd-container-id>
```

3. Check etcd health.
```bash
docker exec kind-control-plane crictl exec $(docker exec kind-control-plane crictl ps -q --name etcd) etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key endpoint health
```

4. Check disk space (etcd is sensitive to disk pressure).
```bash
docker exec kind-control-plane df -h /var/lib/etcd
```

-----

## Exercise 5.3 Solution

Control Plane Recovery Checklist.

1. etcd first (everything depends on it).
   - Check container status
   - Check logs for errors
   - Verify data directory exists and has data
   - Check disk space

2. API server second.
   - Check container status
   - Verify manifest syntax
   - Check certificate validity
   - Verify etcd connectivity settings

3. Controller manager third.
   - Check container status
   - Verify API server connectivity
   - Check leader election status

4. Scheduler fourth.
   - Check container status
   - Verify API server connectivity
   - Check leader election status

5. Validate each step.
   - After etcd: Can API server connect?
   - After API server: Does kubectl work?
   - After controller manager: Are controllers reconciling?
   - After scheduler: Are pods being scheduled?

-----

## Common Mistakes

1. Trying to use kubectl when API server is down
2. Forgetting to check kubelet logs for static pod issues
3. Not checking certificate expiration
4. Editing manifests without backing up first
5. Not understanding component dependencies
