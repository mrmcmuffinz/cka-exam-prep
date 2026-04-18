# Ingress API Fundamentals with Traefik Tutorial

Ingress is the Kubernetes API for HTTP/HTTPS routing from outside the cluster to Services inside. The API is a thin, declarative spec: rules pair hostnames and paths with backend Services; the actual work of matching requests and forwarding them is done by an Ingress controller you install separately. The Ingress API was frozen in 2019 (no new features since `networking.k8s.io/v1`'s GA in 1.19); Gateway API is the successor, covered starting in assignment 3. Ingress remains in widespread production use and is still testable on the CKA exam under the "frozen but testable" principle.

This tutorial teaches the Ingress API using Traefik v3.6.13 as the controller. Traefik is a cloud-native reverse proxy popular in Kubernetes environments, installed via a Helm chart, and a good stand-in for any Ingress controller. The same Ingress YAML (with `ingressClassName` changed) would work under HAProxy Ingress, ingress-nginx, or any other conformant controller. That is the key lesson: the API is universal; only the controller and its annotation syntax are implementation-specific.

## Prerequisites

Create the multi-node kind cluster with port mappings for 80 and 443 exposed from the node. See `docs/cluster-setup.md#multi-node-kind-cluster` for the base config; the exact cluster for this tutorial requires extraPortMappings, so the config block is shown here (this is identical to the tutorial in assignment-2; the same cluster suffices).

```bash
cat <<'EOF' | KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster \
  --image kindest/node:v1.35.0 --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
- role: worker
EOF
```

Verify the cluster.

```bash
kubectl get nodes
# Expected: 1 control-plane and 3 workers, all Ready
```

Install helm if not already present.

```bash
helm version
# Expected: helm v3.x.y
```

Create the tutorial namespace.

```bash
kubectl create namespace tutorial-ingress
```

## Part 1: Installing Traefik v3.6.13

Add the Traefik Helm repository and install the chart with the pinned controller version. The Helm chart name is `traefik/traefik`; the app version v3.6.13 corresponds to Traefik 3.6.13 core, verified against `github.com/traefik/traefik/releases`.

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update

helm install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  --set image.tag=v3.6.13 \
  --set service.type=NodePort \
  --set ports.web.nodePort=32080 \
  --set ports.websecure.nodePort=32443 \
  --set providers.kubernetesIngress.enabled=true

kubectl -n traefik rollout status deployment/traefik --timeout=180s
kubectl get pods -n traefik
```

Expected output: one Traefik pod, status `Running`. Because the kind cluster has `extraPortMappings` for `:80 -> 80` and `:443 -> 443` on the control-plane node, and Traefik is exposed as NodePort on :32080 / :32443, we need a small bit of glue to route node port 80 to NodePort 32080. Traefik's default chart supports an `ingressClass` resource that we can check.

```bash
kubectl get ingressclass
```

Expected output includes a row for `traefik` with the controller `traefik.io/ingress-controller`. That is the `IngressClass` a pod's Ingress resource references via `spec.ingressClassName`.

For the verification step in the exercises to work against `localhost:80`, we add a tiny NodePort-to-HostPort shim by replacing the Traefik Service with a NodePort whose nodePort matches the extraPortMapping, or by exposing Traefik via a HostPort daemonset. For simplicity, re-deploy Traefik with `hostPort.web: 80` and `hostPort.websecure: 443`:

```bash
helm upgrade traefik traefik/traefik \
  --namespace traefik \
  --set image.tag=v3.6.13 \
  --set ports.web.hostPort=80 \
  --set ports.websecure.hostPort=443 \
  --set service.type=ClusterIP \
  --set providers.kubernetesIngress.enabled=true \
  --set nodeSelector."ingress-ready"="true"

kubectl -n traefik rollout status deployment/traefik --timeout=180s
```

With `ingress-ready=true` node selector, Traefik pins to the control-plane node (which has the `extraPortMappings`). HostPort 80 on that node reaches the container's port 80, which through kind's mapping reaches `localhost:80` on the host.

Verify:

```bash
curl -sI http://localhost/
# Expected: HTTP/1.1 404 Not Found (Traefik is running; no Ingress matches yet)
```

That 404 confirms Traefik is reachable. Now create some backend Services.

## Part 2: Backend Services

Create two Deployments with different responses, each exposed by a ClusterIP Service.

```bash
kubectl apply -n tutorial-ingress -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 2
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api}}
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports: [{containerPort: 80}]
        volumeMounts:
        - {name: html, mountPath: /usr/share/nginx/html}
      volumes:
      - name: html
        configMap: {name: api-html}
---
apiVersion: v1
kind: ConfigMap
metadata: {name: api-html}
data:
  index.html: "api-service\n"
---
apiVersion: v1
kind: Service
metadata: {name: api}
spec:
  selector: {app: api}
  ports: [{port: 80, targetPort: 80}]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 2
  selector: {matchLabels: {app: web}}
  template:
    metadata: {labels: {app: web}}
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports: [{containerPort: 80}]
        volumeMounts:
        - {name: html, mountPath: /usr/share/nginx/html}
      volumes:
      - name: html
        configMap: {name: web-html}
---
apiVersion: v1
kind: ConfigMap
metadata: {name: web-html}
data:
  index.html: "web-service\n"
---
apiVersion: v1
kind: Service
metadata: {name: web}
spec:
  selector: {app: web}
  ports: [{port: 80, targetPort: 80}]
EOF

kubectl -n tutorial-ingress rollout status deployment/api deployment/web --timeout=60s
```

## Part 3: First Ingress (path-based routing)

**Spec field reference for `Ingress`:**

- **`spec.ingressClassName`**
  - **Type:** string.
  - **Valid values:** any IngressClass name defined in the cluster (`traefik`, for example).
  - **Default:** if omitted, Kubernetes uses the IngressClass annotated as `ingressclass.kubernetes.io/is-default-class: "true"`.
  - **Failure mode when misconfigured:** if the named class does not exist, the Ingress is not watched by any controller; the `ADDRESS` column stays empty and traffic returns 404. This is the most common "stuck" state.

- **`spec.rules[]`**
  - **Type:** array of rule objects.
  - **Valid values:** each rule has an optional `host` and a required `http` block.
  - **Default:** no rules means no routing (requests fall through to `spec.defaultBackend` if set, or 404).

- **`spec.rules[*].host`**
  - **Type:** string.
  - **Valid values:** a DNS hostname, or a wildcard like `*.example.com`.
  - **Default:** empty. An empty host matches any Host header.
  - **Failure mode when misconfigured:** a specific host does not match requests with different Host headers; the request either falls through to a less-specific rule or 404s.

- **`spec.rules[*].http.paths[*].path`**
  - **Type:** string.
  - **Valid values:** absolute paths beginning with `/`, optionally with regex depending on `pathType`.
  - **Default:** none; required.
  - **Failure mode when misconfigured:** a path that does not cover the application's actual URL space returns 404 for the real paths.

- **`spec.rules[*].http.paths[*].pathType`**
  - **Type:** string.
  - **Valid values:** `Prefix`, `Exact`, `ImplementationSpecific`.
  - **Default:** none; required since Kubernetes 1.19.
  - **Failure mode when misconfigured:** `Exact` on `/` will not match `/foo`, but will match the literal `/`. `Prefix` on `/app` matches `/app`, `/app/`, `/app/foo`, but not `/application`. `ImplementationSpecific` behavior varies by controller.

- **`spec.rules[*].http.paths[*].backend.service.name` and `.port.number`**
  - **Type:** string and integer.
  - **Valid values:** Service name and a port number or port name.
  - **Default:** none; required.
  - **Failure mode when misconfigured:** if the Service does not exist or has no endpoints, the Ingress describe shows the default backend, but requests fail with 503 (no endpoints).

- **`spec.defaultBackend`**
  - **Type:** backend object (`service.name`, `service.port.number`).
  - **Valid values:** any existing Service.
  - **Default:** none.
  - **Failure mode when misconfigured:** unmatched requests return 404 (Traefik's default for unmatched paths) instead of the intended catch-all.

Apply an Ingress with two paths.

```bash
kubectl apply -n tutorial-ingress -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tut-ingress
spec:
  ingressClassName: traefik
  rules:
  - http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api
            port:
              number: 80
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
EOF

sleep 3
kubectl get ingress -n tutorial-ingress tut-ingress
```

Expected output:

```
NAME          CLASS     HOSTS   ADDRESS        PORTS   AGE
tut-ingress   traefik   *       <controller>   80      ...
```

The `ADDRESS` column shows Traefik has accepted the Ingress. Test both paths.

```bash
curl -s http://localhost/api/
# Expected: api-service

curl -s http://localhost/web/
# Expected: web-service

curl -sI http://localhost/nonexistent
# Expected: HTTP/1.1 404 Not Found
```

The `/api` and `/web` prefixes route to their respective Services. Anything else returns 404 because there is no defaultBackend.

## Part 4: Host-based routing

Add a second Ingress that routes by hostname.

```bash
kubectl apply -n tutorial-ingress -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hosts-ingress
spec:
  ingressClassName: traefik
  rules:
  - host: api.example.test
    http:
      paths:
      - path: /
        pathType: Prefix
        backend: {service: {name: api, port: {number: 80}}}
  - host: web.example.test
    http:
      paths:
      - path: /
        pathType: Prefix
        backend: {service: {name: web, port: {number: 80}}}
EOF

sleep 3
curl -s -H "Host: api.example.test" http://localhost/
# Expected: api-service

curl -s -H "Host: web.example.test" http://localhost/
# Expected: web-service

curl -s -H "Host: other.example.test" http://localhost/
# Expected: 404 page content
```

Requests with the matching Host header get routed; other hosts 404. The `Host:` header is the mechanism browsers use; `curl -H` reproduces that without needing real DNS.

## Part 5: `pathType` subtleties

Path types are where the Ingress spec gets nuanced. Apply an Ingress with each type.

```bash
kubectl apply -n tutorial-ingress -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: pathtype-demo
spec:
  ingressClassName: traefik
  rules:
  - host: pt.example.test
    http:
      paths:
      - path: /exact-api
        pathType: Exact
        backend: {service: {name: api, port: {number: 80}}}
      - path: /prefix-web
        pathType: Prefix
        backend: {service: {name: web, port: {number: 80}}}
EOF

sleep 3
```

Test exact-match behavior:

```bash
curl -s -H "Host: pt.example.test" http://localhost/exact-api
# Expected: api-service (exact match succeeds)

curl -sI -H "Host: pt.example.test" http://localhost/exact-api/anything
# Expected: 404 (Exact does not match trailing path)
```

Test prefix-match behavior:

```bash
curl -s -H "Host: pt.example.test" http://localhost/prefix-web
# Expected: web-service

curl -s -H "Host: pt.example.test" http://localhost/prefix-web/subpath
# Expected: web-service (Prefix matches path and all sub-paths)

curl -sI -H "Host: pt.example.test" http://localhost/prefix-webextra
# Expected: 404 (Prefix /prefix-web does not match /prefix-webextra; path segment boundary matters)
```

`Prefix` matches path segment boundaries, not simple string prefixes. `/prefix-web` matches `/prefix-web` and `/prefix-web/anything`, but not `/prefix-webanything`. That path-segment semantics is in the spec; controllers are required to implement it this way.

## Part 6: IngressClass and defaultBackend

If multiple Ingress controllers exist, `ingressClassName` routes the Ingress to the correct one. If the field is omitted, Kubernetes uses the default IngressClass (if any). Check the default.

```bash
kubectl get ingressclass -o jsonpath='{range .items[?(@.metadata.annotations.ingressclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}'
```

Expected output: empty (Traefik's Helm chart by default does not mark itself as the cluster default). Best practice is to set `ingressClassName` explicitly on every Ingress.

Test `defaultBackend`:

```bash
kubectl apply -n tutorial-ingress -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: default-backend-demo
spec:
  ingressClassName: traefik
  defaultBackend:
    service: {name: web, port: {number: 80}}
EOF

sleep 3
curl -s http://localhost/anything/at/all
# Expected: web-service (the defaultBackend catches unmatched paths on the default IngressClass)
```

Note that `defaultBackend` applies to unmatched requests on this specific Ingress. A cluster with multiple Ingresses gets whichever matches most specifically; fallback order is implementation-specific. Remove the Ingress.

```bash
kubectl delete ingress -n tutorial-ingress default-backend-demo
```

## Part 7: Debugging workflow

The diagnostic path for "Ingress does not work":

1. Is the controller pod Running? `kubectl get pods -n traefik`
2. Is the Ingress accepted? `kubectl get ingress -n <ns>` (look for ADDRESS)
3. Does the backend Service exist? `kubectl get svc -n <ns>`
4. Does the backend Service have endpoints? `kubectl get endpoints -n <ns>` (non-empty)
5. Does the Host header match? Test with `curl -H "Host: ..."`.
6. Does the path type match the request path? Exact vs Prefix matters.
7. Check controller logs: `kubectl logs -n traefik -l app.kubernetes.io/name=traefik`

Apply a broken Ingress to see the typical failure mode.

```bash
kubectl apply -n tutorial-ingress -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: broken
spec:
  ingressClassName: does-not-exist
  rules:
  - http:
      paths:
      - path: /broken
        pathType: Prefix
        backend: {service: {name: api, port: {number: 80}}}
EOF

sleep 3
kubectl get ingress -n tutorial-ingress broken
```

Expected output:

```
NAME     CLASS             HOSTS   ADDRESS   PORTS   AGE
broken   does-not-exist    *                 80      ...
```

Empty `ADDRESS`. No controller owns the `does-not-exist` class; the Ingress is ignored. Fix with the correct class.

```bash
kubectl delete ingress -n tutorial-ingress broken
```

## Cleanup

Delete the tutorial namespace (Ingresses within get deleted) and leave Traefik installed for the homework exercises.

```bash
kubectl delete namespace tutorial-ingress
```

To remove Traefik entirely:

```bash
helm uninstall -n traefik traefik
kubectl delete namespace traefik
```

## Reference Commands

| Task | Command |
|---|---|
| List Ingresses in a namespace | `kubectl get ingress -n <ns>` |
| Describe an Ingress (status, rules, backend resolution) | `kubectl describe ingress -n <ns> <name>` |
| Ingress ADDRESS (the controller's reachable endpoint) | `kubectl get ingress -n <ns> <name> -o jsonpath='{.status.loadBalancer.ingress}'` |
| List IngressClasses | `kubectl get ingressclass` |
| Test a host-based route without DNS | `curl -H "Host: <hostname>" http://localhost/<path>` |
| View the backend endpoints the Ingress points to | `kubectl get endpoints -n <ns> <service>` |
| Traefik controller logs | `kubectl logs -n traefik -l app.kubernetes.io/name=traefik --tail=50` |

## Key Takeaways

The Ingress v1 API is universal across controllers; only `ingressClassName`, annotations, and controller-specific features differ. Traefik v3.6.13 is installed via its Helm chart and watches Ingresses tagged with `ingressClassName: traefik`. The three path types (`Exact`, `Prefix`, `ImplementationSpecific`) match differently, and `Prefix` specifically respects path-segment boundaries. Host-based routing works via the `host` field on each rule and the `Host:` request header. `defaultBackend` catches unmatched requests. An Ingress with no matching IngressClass stays with an empty `ADDRESS` column and is silently ignored. Debugging starts with `kubectl get ingress`, `kubectl get endpoints`, and the controller's own logs.
