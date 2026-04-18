# Network Troubleshooting Tutorial

Network layer failures in Kubernetes span six distinct checkpoints: the pod itself must be Running and Ready, the Service must have endpoints backing it, DNS must resolve the Service name to its ClusterIP, a client pod must be able to reach that ClusterIP, NetworkPolicy must permit the traffic, and any external ingress path (NodePort, LoadBalancer, or Ingress) must be routed correctly. A production outage usually manifests at the last layer (a user cannot reach the app) but the root cause often lives at one of the earlier layers. This tutorial walks every checkpoint in order, on one small application that lives in a namespace called `tutorial-troubleshooting`, so that the diagnostic habits are practiced before the exercises begin.

The tutorial assumes a multi-node kind cluster with Calico installed for NetworkPolicy enforcement, MetalLB for LoadBalancer provisioning, and the Traefik Ingress controller for the Ingress step. The authoritative cluster setup is in `docs/cluster-setup.md#multi-node-with-calico-networkpolicy-support`, `docs/cluster-setup.md#metallb-for-loadbalancer-services`, and the Traefik install described later in this tutorial.

## Prerequisites

Verify the cluster:

```bash
kubectl config current-context                   # expect: kind-kind
kubectl get nodes                                # expect: 4 nodes, all Ready
kubectl get pods -n kube-system | grep -E 'calico|coredns'   # expect: calico-* and coredns-* pods Running
```

If NetworkPolicy is not enforced (the default kindnet CNI ignores policies), recreate the cluster with Calico per the cluster-setup anchor above. The tutorial's Step 5 requires real NetworkPolicy enforcement; on a kindnet cluster the NetworkPolicy objects apply but have no effect.

Install MetalLB per `docs/cluster-setup.md#metallb-for-loadbalancer-services`. Install the Traefik Ingress controller via Helm or manifest; this tutorial uses Traefik v3.6.13:

```bash
kubectl create namespace traefik
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.6.13/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.6.13/docs/content/reference/dynamic-configuration/kubernetes-crd-rbac.yml
```

For this tutorial's Ingress step we only need the Ingress v1 resource support that Traefik enables by default; the full Helm install is not required. In a production cluster you would install Traefik via Helm; the minimal manifest set above is sufficient for exam-style Ingress resource practice.

Create the tutorial namespace:

```bash
kubectl create namespace tutorial-troubleshooting
```

## Step 1: The Small Application

Deploy a backend and a frontend. The backend is nginx serving a trivial page; the frontend is a curl loop that proves reachability:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: tutorial-troubleshooting
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: tutorial-troubleshooting
spec:
  ports:
    - port: 80
      targetPort: http
  selector:
    app: backend
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: tutorial-troubleshooting
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: probe
          image: busybox:1.36
          command: ["sh", "-c", "while true; do wget -q -O- http://backend/ > /dev/null && echo OK || echo FAIL; sleep 3; done"]
EOF

kubectl rollout status deployment/backend -n tutorial-troubleshooting --timeout=60s
kubectl rollout status deployment/frontend -n tutorial-troubleshooting --timeout=60s
```

Check the frontend's logs to confirm the baseline works:

```bash
kubectl logs -n tutorial-troubleshooting -l app=frontend --tail=5
```

Expected: several `OK` lines. That is the baseline. Every diagnostic step below is about what happens when one layer is broken.

## Step 2: Service Endpoints

A Service is a selector plus a port definition plus kube-proxy rules. When the selector does not match any Ready pods, the Service has no endpoints; every connection attempt returns connection-refused. Read the endpoints with:

```bash
kubectl get endpoints backend -n tutorial-troubleshooting
```

Expected: a single row with two IPs (the two backend pods' pod-network IPs) and port `80`. If the `ENDPOINTS` column is empty (`<none>`), the Service has no backing pods, and the first question is always "does the selector match?"

Check the Service's selector and the pods' labels:

```bash
kubectl get svc backend -n tutorial-troubleshooting \
  -o jsonpath='{.spec.selector}{"\n"}'

kubectl get pods -n tutorial-troubleshooting \
  -o jsonpath='{range .items[*]}{.metadata.name}:{.metadata.labels}{"\n"}{end}'
```

Expected: the selector is `{"app":"backend"}` and the backend pods have `app=backend` in their labels. If they differ, the Service has empty endpoints.

Then check that the endpoints' port matches the Service's `targetPort`. A Service with `targetPort: 8080` pointing at pods that listen on `80` shows populated endpoints (kube-proxy knows about the pods) but connections to the Service hang or get refused. The fix for a `targetPort` mismatch is to edit the Service (or the Deployment) so both ends agree.

EndpointSlices (the modern replacement for Endpoints) are also worth checking:

```bash
kubectl get endpointslices -n tutorial-troubleshooting -l kubernetes.io/service-name=backend
```

Expected: one or more rows, each with `READY` column showing the number of ready endpoints.

## Step 3: DNS Resolution

From inside the cluster, Services are reachable by their DNS name. The canonical form is `<service>.<namespace>.svc.cluster.local`; the short form `<service>` works when the requester is in the same namespace. The DNS name resolves to the Service's ClusterIP, and kube-proxy routes that IP to one of the endpoints.

Run a debug pod and test DNS:

```bash
kubectl run -n tutorial-troubleshooting dnsprobe --rm -it --restart=Never \
  --image=busybox:1.36 -- sh -c '
    nslookup backend
    echo "---"
    nslookup backend.tutorial-troubleshooting
    echo "---"
    nslookup backend.tutorial-troubleshooting.svc.cluster.local
'
```

Expected: three successful lookups, each returning the Service's ClusterIP. A `NXDOMAIN` result means the DNS name is wrong or CoreDNS does not know about the Service; a hang means CoreDNS is unreachable (the Service could be missing, the CoreDNS pods could be down, or a NetworkPolicy could be blocking egress to DNS).

Check CoreDNS health directly:

```bash
kubectl get deployment coredns -n kube-system
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=20
```

Expected: the CoreDNS Deployment is Available, the pods are Running, and the logs show DNS queries being served (often with `[INFO]` entries for plugin reloads). If CoreDNS is crash-looping, the Corefile may be malformed; inspect it with `kubectl get configmap coredns -n kube-system -o yaml`.

## Step 4: Pod-to-Pod Connectivity

Even when DNS and Services look correct, a policy-enforcing CNI (Calico) can block traffic between specific pods. The default behavior without any NetworkPolicy is "all pods can reach all other pods" (kubernetes-networking's all-to-all guarantee), so baseline connectivity is always unrestricted until a policy applies.

Test pod-to-pod connectivity from the frontend pod to the backend pod directly by its IP:

```bash
BACKEND_IP=$(kubectl get pod -n tutorial-troubleshooting -l app=backend \
  -o jsonpath='{.items[0].status.podIP}')
FRONTEND=$(kubectl get pod -n tutorial-troubleshooting -l app=frontend \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n tutorial-troubleshooting $FRONTEND -- \
  sh -c "wget -q -O- http://$BACKEND_IP/"
```

Expected: the nginx default index page, printed to stdout.

If this fails while `curl <service-IP>` also fails but the pods and endpoints look correct, the CNI itself is the suspect. On kind with Calico the typical cause is a Calico pod not Ready on the node hosting the frontend pod.

## Step 5: NetworkPolicy

NetworkPolicy is whitelist-only and direction-specific. A pod with any NetworkPolicy selecting it has ingress (and egress, separately) restricted to exactly what the policy lists; everything else is denied. The common mistake is to apply a default-deny without also allowing DNS, which breaks every Service lookup.

Apply a default-deny-all and observe the break:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: tutorial-troubleshooting
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
EOF
```

Watch the frontend's logs:

```bash
kubectl logs -n tutorial-troubleshooting -l app=frontend --tail=5
```

Expected: the `OK` lines stop; either `FAIL` appears (if DNS still works but reachability does not) or the frontend hangs because DNS is now blocked.

Add a minimal exception for DNS and for frontend-to-backend traffic:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: tutorial-troubleshooting
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: tutorial-troubleshooting
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - port: 80
          protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-egress-to-backend
  namespace: tutorial-troubleshooting
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: backend
      ports:
        - port: 80
          protocol: TCP
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - port: 53
          protocol: UDP
EOF
```

Watch the frontend's logs; `OK` should return within a few seconds. If it does not, one of the policies is incorrect; dump them all and walk through them one rule at a time:

```bash
kubectl get networkpolicies -n tutorial-troubleshooting
kubectl describe networkpolicy allow-dns -n tutorial-troubleshooting
kubectl describe networkpolicy allow-frontend-to-backend -n tutorial-troubleshooting
```

Clean up the policies before the next step (otherwise external access exercises below will fail):

```bash
kubectl delete networkpolicy --all -n tutorial-troubleshooting
```

## Step 6: NodePort Access

A NodePort Service opens a TCP port on every node at a number in the range 30000-32767. From outside the cluster, reach the Service at `<any-node-IP>:<nodePort>`. The internal `spec.ports[0].port` is still the Service port, but external access uses the `nodePort` instead.

Expose the backend as NodePort:

```bash
kubectl patch service backend -n tutorial-troubleshooting \
  --type=merge --patch '{"spec":{"type":"NodePort"}}'
kubectl get service backend -n tutorial-troubleshooting
```

Expected: a NodePort in the `PORT(S)` column (for example, `80:30123/TCP`). Get a node's IP:

```bash
kubectl get nodes -o wide
```

Expected: each node has an `INTERNAL-IP`. From the host (outside the kind cluster container), reach the NodePort:

```bash
NODEPORT=$(kubectl get service backend -n tutorial-troubleshooting \
  -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
curl -s http://$NODE_IP:$NODEPORT/ | head -3
```

Expected: nginx default index content. The connection goes through the host-to-kind-node network, then kube-proxy forwards to a backend pod.

If the NodePort is unreachable, check whether kube-proxy is running, whether the Service actually has the NodePort set (`spec.ports[0].nodePort` should be non-zero), and whether the host firewall blocks the port. On kind the "host" is the container, so it is rarely the problem.

Revert to ClusterIP:

```bash
kubectl patch service backend -n tutorial-troubleshooting \
  --type=merge --patch '{"spec":{"type":"ClusterIP"}}'
```

## Step 7: LoadBalancer with MetalLB

A LoadBalancer Service is usually provisioned by a cloud provider. In kind, MetalLB provides that capability. Without MetalLB, a LoadBalancer Service stays in `Pending` forever with no external IP.

Expose the backend as LoadBalancer:

```bash
kubectl patch service backend -n tutorial-troubleshooting \
  --type=merge --patch '{"spec":{"type":"LoadBalancer"}}'
kubectl get service backend -n tutorial-troubleshooting -w
```

Expected: within a few seconds, the `EXTERNAL-IP` column fills in with an IP from MetalLB's configured pool. Stop watching (Ctrl+C) and curl it:

```bash
EXT_IP=$(kubectl get service backend -n tutorial-troubleshooting \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -s http://$EXT_IP/ | head -3
```

If `EXTERNAL-IP` stays `<pending>`, MetalLB is either not installed or has no IP address pool configured. Check:

```bash
kubectl get pods -n metallb-system
kubectl get ipaddresspools -n metallb-system
```

Revert to ClusterIP:

```bash
kubectl patch service backend -n tutorial-troubleshooting \
  --type=merge --patch '{"spec":{"type":"ClusterIP"}}'
```

## Step 8: Ingress Routing

Ingress exposes HTTP/HTTPS routes via a controller (Traefik here). The Ingress resource names the backend Service and the Host header to match. The common mistake is to omit `ingressClassName`, which leaves no controller claiming the resource.

Create an Ingress:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backend
  namespace: tutorial-troubleshooting
spec:
  ingressClassName: traefik
  rules:
    - host: backend.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backend
                port:
                  number: 80
EOF
```

Check the controller picked it up:

```bash
kubectl get ingress backend -n tutorial-troubleshooting
```

Expected: the `ADDRESS` column eventually shows the controller's ingress IP (which on a kind cluster may be empty depending on Traefik's Service type; the configuration of the Traefik controller determines the external reachability path).

If the Ingress has no `ADDRESS`, the controller is either not claiming it (wrong `ingressClassName`) or the Traefik Service itself has no external IP. Check:

```bash
kubectl get ingressclass
kubectl get services -n traefik
```

Expected: an `IngressClass` named `traefik` exists (installed by the Traefik manifests); the Traefik service is configured as LoadBalancer (via MetalLB) or NodePort.

## Step 9: The Network Diagnostic Playbook

Given a "curl fails" report, the sequence is:

1. Confirm the pod. `kubectl get pod -n <ns>` and `kubectl describe pod` for Status and Events. If the pod is not Ready, solve that first (Assignment 1 territory).

2. Confirm the Service endpoints. `kubectl get endpoints <svc> -n <ns>`. If empty, the Service selector does not match any Ready pod; check `kubectl get svc <svc> -o yaml` and compare the selector to the pod labels.

3. Confirm DNS. From a debug pod, `nslookup <svc>.<ns>`. If NXDOMAIN, check the DNS name spelling and the namespace. If it hangs, check CoreDNS health and egress NetworkPolicies.

4. Confirm pod-to-Service reachability. From a debug pod, `curl <ClusterIP>:<port>` (bypassing DNS). If that works but curl by name fails, DNS is the problem. If it fails but the endpoints are populated, check NetworkPolicy and kube-proxy.

5. Confirm pod-to-pod directly. `curl <pod-IP>:<containerPort>`. If that fails, the problem is CNI or NetworkPolicy; `kubectl describe networkpolicies -n <ns>` to list applicable policies.

6. External access only if all the above work. `kubectl get svc <svc> -o wide` for the external IP, and then curl from outside the cluster.

Each step has a single diagnostic command and a specific expected output. A failure at step N means the problem is at layer N, and earlier layers can be skipped in the fix. The diagnostic playbook replaces guessing with the elimination of layers.

## Step 10: Clean Up

```bash
kubectl delete ingress backend -n tutorial-troubleshooting
kubectl delete namespace tutorial-troubleshooting
```

Traefik, MetalLB, and Calico stay installed for the homework exercises.

## Reference Commands

### Service debugging

```bash
kubectl get svc NAME -n NS
kubectl get svc NAME -n NS -o jsonpath='{.spec.selector}{"\n"}'
kubectl get endpoints NAME -n NS
kubectl get endpointslices -n NS -l kubernetes.io/service-name=NAME
kubectl describe svc NAME -n NS
```

### DNS debugging

```bash
kubectl run dns-debug --rm -it --restart=Never --image=busybox:1.36 -n NS \
  -- nslookup NAME
kubectl run dns-debug --rm -it --restart=Never --image=busybox:1.36 -n NS \
  -- nslookup NAME.NS.svc.cluster.local

kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=30
kubectl get configmap coredns -n kube-system -o yaml
```

### NetworkPolicy debugging

```bash
kubectl get networkpolicies -n NS
kubectl describe networkpolicy NAME -n NS
```

### External access debugging

```bash
# NodePort: find the port and a node IP
kubectl get svc NAME -n NS -o jsonpath='{.spec.ports[0].nodePort}{"\n"}'
kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}{"\n"}'

# LoadBalancer: check for the external IP
kubectl get svc NAME -n NS -o jsonpath='{.status.loadBalancer.ingress[*]}{"\n"}'
kubectl get ipaddresspools -n metallb-system

# Ingress
kubectl get ingress NAME -n NS
kubectl get ingressclass
```

### Common failure signatures

| Symptom | Layer | First command |
|---|---|---|
| Service has `<none>` in ENDPOINTS | Service selector | `kubectl get svc X -o jsonpath='{.spec.selector}'` vs pod labels |
| Endpoints populated; curl hangs | Service targetPort or CNI | Compare `spec.ports[0].targetPort` to pod's `containerPort` |
| nslookup returns NXDOMAIN | DNS name or Service namespace | Try the FQDN explicitly |
| nslookup hangs | CoreDNS or DNS egress policy | `kubectl get pods -n kube-system -l k8s-app=kube-dns` |
| curl times out from one pod but works from another | NetworkPolicy scoped to source pod | `kubectl get networkpolicies -n NS` |
| NodePort not reachable from host | NodePort range, kube-proxy, or host firewall | `kubectl get svc -o jsonpath='{...nodePort}'` |
| LoadBalancer stuck Pending | No LB provisioner | `kubectl get pods -n metallb-system` |
| Ingress has no ADDRESS | Missing `ingressClassName` or no controller | `kubectl get ingressclass` |
