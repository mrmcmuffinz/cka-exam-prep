# Control Plane Troubleshooting Homework

This homework contains 15 debugging exercises for control plane troubleshooting. Due to the nature of control plane components, some exercises are conceptual or require careful execution to avoid breaking your cluster.

## Important Note

Control plane troubleshooting on kind clusters differs from production kubeadm clusters. Kind runs the control plane as containers within a Docker/nerdctl container. Access the control plane with `docker exec -it kind-control-plane bash` or `nerdctl exec -it kind-control-plane bash`.

## Setup

Ensure you have a working kind cluster.

```bash
kubectl get nodes
kubectl get pods -n kube-system
```

-----

## Level 1: Component Status

### Exercise 1.1

**Objective:**

Verify all control plane components are running and identify their container images.

**Verification:**

```bash
kubectl get pods -n kube-system -o wide | grep -E "(apiserver|scheduler|controller-manager|etcd)"
```

-----

### Exercise 1.2

**Objective:**

View the logs of the kube-scheduler component and identify the leader election status.

**Verification:**

```bash
kubectl logs -n kube-system $(kubectl get pods -n kube-system -l component=kube-scheduler -o name) | grep -i leader
```

-----

### Exercise 1.3

**Objective:**

Identify which node is running each control plane component using kubectl.

**Verification:**

```bash
kubectl get pods -n kube-system -o wide | grep -E "(apiserver|scheduler|controller-manager|etcd)" | awk '{print $1, $7}'
```

-----

## Level 2: Static Pod Issues

### Exercise 2.1

**Objective:**

Access the control plane node and list all static pod manifests.

**Verification:**

```bash
docker exec kind-control-plane ls -la /etc/kubernetes/manifests/
```

-----

### Exercise 2.2

**Objective:**

View the kube-apiserver manifest and identify its command-line arguments.

**Verification:**

```bash
docker exec kind-control-plane cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -A50 "command:"
```

-----

### Exercise 2.3

**Objective:**

Identify the etcd data directory from the etcd static pod manifest.

**Verification:**

```bash
docker exec kind-control-plane cat /etc/kubernetes/manifests/etcd.yaml | grep data-dir
```

-----

## Level 3: Component Failures

### Exercise 3.1

**Objective:**

A new cluster reports that pods are not being scheduled. Diagnose whether this is a scheduler issue or a node issue. Describe the diagnostic steps.

**Verification:**

Document the commands you would use and what output would indicate a scheduler problem vs a node problem.

-----

### Exercise 3.2

**Objective:**

The controller manager is not reconciling Deployments. Identify what logs to check and what symptoms to look for.

**Verification:**

```bash
kubectl logs -n kube-system $(kubectl get pods -n kube-system -l component=kube-controller-manager -o name) | tail -50
```

-----

### Exercise 3.3

**Objective:**

Describe how to diagnose an API server that is not responding to kubectl commands.

**Verification:**

Document the steps to take when kubectl returns connection errors.

-----

## Level 4: Certificate Issues

### Exercise 4.1

**Objective:**

Check the expiration dates of all cluster certificates using kubeadm.

**Note:** This may not work on kind clusters as kubeadm certs command requires specific setup.

**Alternative Verification:**

```bash
docker exec kind-control-plane find /etc/kubernetes/pki -name "*.crt" -exec openssl x509 -in {} -noout -subject -dates \;
```

-----

### Exercise 4.2

**Objective:**

Identify the Subject Alternative Names (SANs) configured for the API server certificate.

**Verification:**

```bash
docker exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text | grep -A1 "Subject Alternative Name"
```

-----

### Exercise 4.3

**Objective:**

Verify that the API server certificate is signed by the cluster CA.

**Verification:**

```bash
docker exec kind-control-plane openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/apiserver.crt
```

-----

## Level 5: Complex Scenarios

### Exercise 5.1

**Objective:**

Design a complete diagnostic workflow for when the API server is not responding. Document the sequence of commands and what each tells you.

**Verification:**

Create a troubleshooting checklist covering: network connectivity, container status, logs, certificates, and etcd connectivity.

-----

### Exercise 5.2

**Objective:**

Describe the etcd troubleshooting process including how to check etcd cluster health.

**Note:** On kind clusters, etcd runs as a single node. In production, you would check cluster membership and health.

**Verification:**

```bash
docker exec kind-control-plane crictl exec $(docker exec kind-control-plane crictl ps -q --name etcd) etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key endpoint health
```

-----

### Exercise 5.3

**Objective:**

Document a complete control plane recovery procedure for when multiple components are failing.

**Verification:**

Create a recovery checklist that prioritizes: etcd, API server, controller manager, scheduler, and validates each step.

-----

## Key Takeaways

Control plane troubleshooting requires understanding component dependencies, accessing nodes directly when kubectl fails, reading static pod manifests, analyzing component logs, and verifying certificates.
