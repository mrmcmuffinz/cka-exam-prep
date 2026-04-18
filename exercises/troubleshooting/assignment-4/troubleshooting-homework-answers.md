# Network Troubleshooting Homework Answers

Complete solutions for all 15 exercises. Every exercise in this assignment is a debugging scenario, so every answer follows the three-stage structure: Diagnosis, What the bug is and why, Fix.

---

## Exercise 1.1 Solution

### Diagnosis

Read the Service's selector and compare to the pod labels:

```bash
kubectl get svc web -n ex-1-1 -o jsonpath='{.spec.selector}{"\n"}'
kubectl get pods -n ex-1-1 -l app=web -o jsonpath='{range .items[*]}{.metadata.name}:{.metadata.labels.app}{"\n"}{end}'
```

Expected: the Service selector is `{"app":"webapp"}`; the pods have `app=web`. The selector does not match any pod.

Confirm with endpoints:

```bash
kubectl get endpoints web -n ex-1-1
```

Expected: `ENDPOINTS` column shows `<none>`.

### What the bug is and why it happens

The Service's `spec.selector` is `{app: webapp}` but the backing pods are labeled `app=web`. When the selector does not match any pod, the Endpoints controller produces no endpoints, and kube-proxy has nothing to forward to; every connection attempt returns connection-refused or hangs.

### Fix

Patch the Service to match the pods:

```bash
kubectl patch svc web -n ex-1-1 --type=merge \
  --patch '{"spec":{"selector":{"app":"web"}}}'
```

Confirm endpoints now list two IPs and curl succeeds.

---

## Exercise 1.2 Solution

### Diagnosis

Endpoints are populated (the selector is correct), so the problem is not the selector. Check the Service's `targetPort` versus the container's `containerPort`:

```bash
kubectl get svc api -n ex-1-2 -o jsonpath='{.spec.ports[0]}{"\n"}'
kubectl get deployment api -n ex-1-2 -o jsonpath='{.spec.template.spec.containers[0].ports[0]}{"\n"}'
```

Expected: Service `targetPort: 8080`; container `containerPort: 80`. The Service forwards to port 8080 on the pod; nothing listens there.

### What the bug is and why it happens

kube-proxy routes traffic from the Service's `port` (80) to each endpoint pod's `targetPort` (8080). The pod's nginx is listening on port 80, not 8080. Every connection hangs because there is no listener on 8080 inside the pod.

### Fix

Patch the Service to target the correct port (`80`):

```bash
kubectl patch svc api -n ex-1-2 --type=merge \
  --patch '{"spec":{"ports":[{"port":80,"targetPort":80}]}}'
```

Or, for clarity and future-proofing, name the container port and use the name (`http`) as the `targetPort`, which the tutorial demonstrates.

---

## Exercise 1.3 Solution

### Diagnosis

Check the Service's protocol:

```bash
kubectl get svc cache -n ex-1-3 -o jsonpath='{.spec.ports[0].protocol}{"\n"}'
```

Expected: `UDP`. Redis serves TCP, not UDP; kube-proxy routes UDP packets to port 6379 but the container refuses them.

### What the bug is and why it happens

The Service's `spec.ports[0].protocol` is `UDP`, but Redis listens on TCP. A protocol mismatch on a Service is a silent failure: the Service object applies, kube-proxy installs the rule, but no real traffic succeeds because the application does not accept the protocol the Service forwards.

### Fix

Patch the Service to use TCP (or omit the field; `TCP` is the default):

```bash
kubectl patch svc cache -n ex-1-3 --type=merge \
  --patch '{"spec":{"ports":[{"port":6379,"targetPort":6379,"protocol":"TCP"}]}}'
```

Retest with the Redis `PING` command from the verification block.

---

## Exercise 2.1 Solution

### Diagnosis

DNS failures cluster-wide point at CoreDNS. Check:

```bash
kubectl get deployment coredns -n kube-system
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

Expected: `READY` column is `0/2` (or `0/N`); no Pods exist. The Deployment has been scaled to zero.

### What the bug is and why it happens

CoreDNS is the cluster DNS service; it runs as a Deployment in `kube-system` labeled `k8s-app: kube-dns`. When the Deployment is scaled to 0, no pods exist to serve DNS queries; every `nslookup` from inside the cluster hangs and eventually times out. This is not a NetworkPolicy block or a Service selector problem; it is an operational issue with the controller.

### Fix

Scale CoreDNS back up:

```bash
kubectl scale deployment coredns -n kube-system --replicas=2
kubectl rollout status deployment/coredns -n kube-system --timeout=60s
```

Two replicas is the kind default. Wait for `READY: 2/2` and retest the nslookup.

---

## Exercise 2.2 Solution

### Diagnosis

The client logs `FAIL`. From a debug pod in the same namespace, try the name:

```bash
kubectl run probe -n ex-2-2 --rm -it --restart=Never --image=busybox:1.36 \
  -- nslookup target
```

Expected: NXDOMAIN. The name `target` does not resolve in namespace `ex-2-2` because the Service `target` lives in `ex-2-2-target`, not in `ex-2-2`.

Confirm the Service's namespace:

```bash
kubectl get svc target -A
```

Expected: one row, namespace `ex-2-2-target`.

### What the bug is and why it happens

The DNS short name `target` resolves only within the same namespace. The client's command uses `http://target/`, which resolves to `target.ex-2-2.svc.cluster.local` (nonexistent). The correct cross-namespace name is `target.ex-2-2-target`, `target.ex-2-2-target.svc`, or the fully qualified `target.ex-2-2-target.svc.cluster.local`.

### Fix

Update the client Deployment's command to use the cross-namespace name:

```bash
kubectl patch deployment client -n ex-2-2 --type=json \
  --patch '[{"op":"replace","path":"/spec/template/spec/containers/0/command","value":["sh","-c","while true; do wget -q -O- http://target.ex-2-2-target/ > /dev/null && echo OK || echo FAIL; sleep 3; done"]}]'
```

Wait for the new pod to roll out and confirm `OK` in the logs.

---

## Exercise 2.3 Solution

### Diagnosis

A default-deny egress blocks everything, including DNS queries to `kube-system/kube-dns`. Any pod in `ex-2-3` attempting a DNS lookup hangs.

### What the bug is and why it happens

The `deny-all-egress` policy selects every pod (`podSelector: {}`) and declares `Egress` without any `egress` rules, which means every egress flow is denied. DNS queries to CoreDNS are egress from the client pod's perspective, so they are blocked.

### Fix

Add a NetworkPolicy that allows egress to CoreDNS on UDP and TCP port 53. The `deny-all-egress` policy stays in place; NetworkPolicy is additive (multiple policies combine; a flow is allowed if any applicable policy permits it):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: ex-2-3
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
EOF
```

Retest the nslookup; it succeeds because DNS egress is now explicitly allowed. Other egress remains denied.

---

## Exercise 3.1 Solution

### Diagnosis

The `default-deny-ingress` policy selects backend pods and declares `Ingress` without any allow rules. Every incoming connection to a backend pod is denied.

### What the bug is and why it happens

Direction-specific NetworkPolicy: a policy that declares `policyTypes: [Ingress]` with no `ingress` rules blocks all ingress to the selected pods. Without a permit rule, the frontend's curl to backend returns timeout or connection-refused depending on CNI semantics (Calico returns timeout).

### Fix

Add a policy that allows ingress from frontend pods:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: ex-3-1
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
EOF
```

The two policies combine (deny-all plus allow-from-frontend); the effective behavior is "backend accepts ingress only from frontend." Retest the frontend's logs; `OK` should appear within a few seconds.

---

## Exercise 3.2 Solution

### Diagnosis

The `deny-all-egress` policy blocks every outbound flow from the client pod. The client tries to reach the API server on port 443 and fails; DNS lookups for `kubernetes.default.svc` also fail.

### What the bug is and why it happens

Same class as Exercise 2.3: `policyTypes: [Egress]` with no `egress` rules denies all egress. The client needs two egress rules: one for DNS (to resolve `kubernetes.default.svc`), and one for the API server itself (TCP port 443).

### Fix

Add two NetworkPolicies (or a single policy with two egress entries). The split form is clearer:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: ex-3-2
spec:
  podSelector:
    matchLabels:
      app: client
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
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-apiserver
  namespace: ex-3-2
spec:
  podSelector:
    matchLabels:
      app: client
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: default
      ports:
        - port: 443
          protocol: TCP
EOF
```

DNS resolves; the TCP connection to `kubernetes.default.svc:443` succeeds; the client's `OK` lines return.

---

## Exercise 3.3 Solution

### Diagnosis

Read the NetworkPolicy and compare to the real source namespace:

```bash
kubectl get networkpolicy allow-from-caller -n ex-3-3 -o yaml \
  | grep -A3 'namespaceSelector'
kubectl get namespace ex-3-3-src --show-labels
```

Expected: the policy selects namespaces with `kubernetes.io/metadata.name: caller-ns`, but the source namespace is `ex-3-3-src`. The selector matches no namespace.

### What the bug is and why it happens

The `kubernetes.io/metadata.name` label is automatically set on every namespace with the namespace's own name as the value. The policy's selector requires `kubernetes.io/metadata.name: caller-ns`, which would match a namespace named `caller-ns`. The real source namespace is named `ex-3-3-src`, so the match is empty, so no ingress is permitted.

### Fix

Patch the policy to name the actual source namespace:

```bash
kubectl patch networkpolicy allow-from-caller -n ex-3-3 --type=json \
  --patch '[{"op":"replace","path":"/spec/ingress/0/from/0/namespaceSelector/matchLabels","value":{"kubernetes.io/metadata.name":"ex-3-3-src"}}]'
```

The caller's next poll cycle produces `OK`.

---

## Exercise 4.1 Solution

### Diagnosis

Read the Ingress `ingressClassName`:

```bash
kubectl get ingress app -n ex-4-1 -o jsonpath='{.spec.ingressClassName}{"\n"}'
```

Expected: empty. The Ingress has no class, so no controller (including Traefik) claims it.

### What the bug is and why it happens

`spec.ingressClassName` tells Ingress controllers which resources belong to them. A controller watches for Ingresses whose `ingressClassName` matches its configured class. Without the field, no controller claims the Ingress; it stays as metadata with no routing effect.

### Fix

Set the class to `traefik`:

```bash
kubectl patch ingress app -n ex-4-1 --type=merge \
  --patch '{"spec":{"ingressClassName":"traefik"}}'
```

Within seconds, Traefik picks up the Ingress and the `ADDRESS` column populates (the exact address depends on the Traefik Service's configuration; on a MetalLB-equipped cluster it will be the Traefik Service's external IP).

---

## Exercise 4.2 Solution

### Diagnosis

Inspect the Ingress host:

```bash
kubectl get ingress site -n ex-4-2 -o jsonpath='{.spec.rules[0].host}{"\n"}'
```

Expected: `wrong-host.local`. The Ingress only routes requests whose `Host:` header matches this value; a request with `Host: site.ex-4-2.local` returns 404.

### What the bug is and why it happens

The Ingress resource's `spec.rules[0].host` is a string that the controller matches against the `Host:` header on incoming HTTP requests. The expected host (`site.ex-4-2.local`) does not match `wrong-host.local`, so the controller returns a 404.

### Fix

Patch the Ingress to expect the correct host:

```bash
kubectl patch ingress site -n ex-4-2 --type=json \
  --patch '[{"op":"replace","path":"/spec/rules/0/host","value":"site.ex-4-2.local"}]'
```

Retest with a curl using `Host: site.ex-4-2.local`.

---

## Exercise 4.3 Solution

### Diagnosis

Inspect the LoadBalancer Service's status:

```bash
kubectl get svc app -n ex-4-3
kubectl describe svc app -n ex-4-3 | tail -10
```

Expected: `EXTERNAL-IP` is `<pending>`; Events include a MetalLB `AllocationFailed` message citing no available IP pool.

Check MetalLB's IP pools:

```bash
kubectl get ipaddresspools -n metallb-system
```

Expected: no rows. The pool has been deleted (the setup removed it).

### What the bug is and why it happens

MetalLB provisions LoadBalancer external IPs from one or more configured `IPAddressPool` resources. Without a pool, MetalLB has no IPs to hand out, so the Service stays in `Pending`. The Service itself is correct; the operational configuration is missing.

### Fix

Recreate the pool and an L2Advertisement so the pool is reachable via ARP:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: kind-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.18.255.200-172.18.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: kind-l2
  namespace: metallb-system
EOF
```

MetalLB picks an address from the pool for the Service within a few seconds. The address may differ from what a prior setup produced; `kubectl get svc app -n ex-4-3` shows the assigned IP.

---

## Exercise 5.1 Solution

### Diagnosis

Two symptoms: endpoints empty, and a NetworkPolicy exists. Read both:

```bash
kubectl get endpoints backend -n ex-5-1
kubectl get networkpolicies -n ex-5-1
kubectl get svc backend -n ex-5-1 -o jsonpath='{.spec.selector}{"\n"}'
kubectl get pods -n ex-5-1 -l app=backend -o jsonpath='{.items[0].metadata.labels}{"\n"}'
```

Expected: empty endpoints; a `deny-ingress` policy on `app=backend`; Service selector `{app: backend-v2}`; pod labels contain `app=backend`.

### What the bug is and why it happens

Two independent problems: the Service's selector (`app=backend-v2`) does not match the pods' labels (`app=backend`), and a NetworkPolicy denies all ingress to backend pods. Each alone would block traffic; both together mean there are two fixes to apply.

### Fix

Patch both:

```bash
kubectl patch svc backend -n ex-5-1 --type=merge \
  --patch '{"spec":{"selector":{"app":"backend"}}}'

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-client
  namespace: ex-5-1
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
              app: client
      ports:
        - port: 80
          protocol: TCP
EOF
```

Endpoints populate (selector fix); NetworkPolicy now permits client-to-backend; `OK` returns.

---

## Exercise 5.2 Solution

### Diagnosis

Three symptoms. Walk the diagnostic playbook:

1. DNS from the client: `kubectl exec client-<hash> -n ex-5-2 -- nslookup web.wrong-ns` returns NXDOMAIN. First bug: wrong DNS name.
2. Endpoints of the Service: populated; targetPort is 8080; containerPort is 80. Second bug: wrong targetPort.
3. NetworkPolicy: `restrict-web` allows ingress only from `app=admin-client` but the client is labeled `app=client`. Third bug: wrong podSelector in the policy.

### What the bug is and why it happens

Three independent mistakes layered on one request path. Each is a silent failure in its own right; together they prevent any request from succeeding.

### Fix

Three patches:

```bash
# Fix the client's DNS name:
kubectl patch deployment client -n ex-5-2 --type=json \
  --patch '[{"op":"replace","path":"/spec/template/spec/containers/0/command","value":["sh","-c","while true; do wget -q -O- http://web/ > /dev/null && echo OK || echo FAIL; sleep 3; done"]}]'

# Fix the Service targetPort:
kubectl patch svc web -n ex-5-2 --type=merge \
  --patch '{"spec":{"ports":[{"port":80,"targetPort":80}]}}'

# Fix the NetworkPolicy's source selector:
kubectl patch networkpolicy restrict-web -n ex-5-2 --type=json \
  --patch '[{"op":"replace","path":"/spec/ingress/0/from/0/podSelector/matchLabels","value":{"app":"client"}}]'
```

Wait for the client's new pod to roll out, then check the logs.

---

## Exercise 5.3 Solution

The runbook is an authoring exercise; the learner writes a document that captures the diagnostic playbook for a specific incident. A correct runbook covers at least six steps and names the specific kubectl command at each one. A reasonable template is:

```markdown
# Runbook: prod-web.ex-5-3.local returns 503

## Step 1: Confirm the alert

Reproduce from outside the cluster:
`curl -H 'Host: prod-web.ex-5-3.local' http://<ingress-IP>/`
Expected: HTTP 200 with the nginx page. Actual: HTTP 503.

## Step 2: Inspect the Ingress

`kubectl describe ingress prod-web -n ex-5-3`
Look at: ingressClassName, Rules, and Events. A 503 from the ingress controller usually means the controller cannot reach the backend Service.

## Step 3: Inspect the Service endpoints

`kubectl get endpoints prod-web -n ex-5-3`
Expected: three IPs. If empty, the Service selector does not match any Ready pod; go to Step 5.

## Step 4: Inspect the backend Deployment and pods

`kubectl get deployment prod-web -n ex-5-3`
`kubectl get pods -n ex-5-3 -l app=prod-web -o wide`
Expected: three Ready pods. If zero are Ready, the pods are crash-looping or stuck; inspect individual pods.

## Step 5: If endpoints are empty: compare the selector to the labels

`kubectl get svc prod-web -n ex-5-3 -o jsonpath='{.spec.selector}'`
`kubectl get pods -n ex-5-3 -o jsonpath='{.items[*].metadata.labels.app}'`
If they differ, patch the Service's selector.

## Step 6: Inspect network policies

`kubectl get networkpolicies -n ex-5-3`
`kubectl describe networkpolicy <name> -n ex-5-3`
A policy on `app=prod-web` that denies ingress from the Traefik namespace blocks the controller from reaching the pods; add an explicit allow-from-traefik policy.

## Step 7: Inspect pod logs

`kubectl logs -n ex-5-3 -l app=prod-web --tail=50`
Check for application-level errors that would cause the container to return 503.
```

A runbook at that granularity satisfies the verification grep. Production runbooks in real on-call rotations are structured similarly; the goal is that the on-call engineer can follow the steps in order without having to remember which `kubectl` command to run next.

---

## Common Mistakes

Checking the Service directly before checking the endpoints. `kubectl describe svc X` shows the selector, ports, and IPs, but it does not show whether the Service actually has endpoints; the Service object can exist forever with an empty endpoints list and nothing in its description indicates anything is wrong. `kubectl get endpoints X -n NS` is the authoritative command.

Applying a default-deny NetworkPolicy without also allowing DNS. The default-deny breaks every `nslookup` in the affected pods. The canonical DNS allow rule is egress to the `kube-system` namespace's `k8s-app: kube-dns` pods on UDP (and TCP) port 53. Every other NetworkPolicy rollout in production starts with this rule, because rollouts that skip it break everything that relies on Service names.

Writing `namespaceSelector` against an arbitrary label instead of `kubernetes.io/metadata.name`. Every namespace carries a `kubernetes.io/metadata.name` label with its own name as the value; that is the most reliable selector for "this policy applies when the source namespace is X." Matching against labels that might or might not exist on the namespace leads to silent failures.

Forgetting that `targetPort` uses the port on the pod, not the port on the Service. The Service's `port` is the virtual port users connect to; the Service's `targetPort` is what kube-proxy forwards to on each endpoint. A mismatch produces populated endpoints with connections that hang; the Service looks correct in a describe but serves nothing.

Testing Ingress through the wrong client. `curl <ingress-IP>` without a `Host:` header returns whatever the controller serves by default (usually a 404 page). The controller's Rules match on the Host header; the request must include `Host: <spec.rules[0].host>` or a matching wildcard. The `-H` flag is the common way: `curl -H 'Host: app.example.com' http://<ingress-IP>/`.

Assuming LoadBalancer Services get IPs automatically in kind. Kind has no built-in cloud-provider integration; MetalLB must be installed and configured with an IPAddressPool, or every LoadBalancer Service stays in `Pending`. The fix is never to change the Service type; it is to install or configure the provisioner.

Treating NetworkPolicy as a firewall with deny rules. NetworkPolicy is allow-only; there are no deny rules. "Deny all ingress" is expressed by selecting pods with an `ingress: []` (empty allow list). Additional policies add allows; they never subtract. The canonical pattern is to layer: a default-deny policy that selects everything, plus specific allow policies for the flows that should succeed.

---

## Verification Commands Cheat Sheet

```bash
# Service and endpoints
kubectl get svc NAME -n NS
kubectl get svc NAME -n NS -o jsonpath='{.spec.selector}{"\n"}'
kubectl get endpoints NAME -n NS
kubectl get endpointslices -n NS -l kubernetes.io/service-name=NAME
kubectl describe svc NAME -n NS

# DNS
kubectl run dns-debug --rm -it --restart=Never --image=busybox:1.36 -n NS -- nslookup HOST
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=30

# NetworkPolicy
kubectl get networkpolicies -n NS
kubectl describe networkpolicy NAME -n NS

# External access
kubectl get svc NAME -n NS -o wide
kubectl get ingress -n NS
kubectl get ingressclass
kubectl get ipaddresspools -n metallb-system

# Pod-to-pod and pod-to-service (from a debug pod)
kubectl run probe --rm -it --restart=Never --image=busybox:1.36 -n NS \
  -- sh -c 'wget -q -O- http://TARGET/'
```

When `curl` fails from outside, walk the playbook inside-out: is the pod Ready, does the Service have endpoints, does DNS resolve, can a probe pod reach the ClusterIP, can a probe pod reach a pod IP, does NetworkPolicy permit the flow, does external ingress actually route here. Six commands, six layers, each with a specific expected output. That is the entire toolbox for network debugging.
