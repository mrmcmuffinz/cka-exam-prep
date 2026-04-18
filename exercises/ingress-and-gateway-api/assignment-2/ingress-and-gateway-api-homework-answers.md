# Ingress and Gateway API Homework Answers: Advanced Ingress and TLS

---

## Exercise 1.1 Solution

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: ex-1-1
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-svc
            port:
              number: 80
```

---

## Exercise 1.2 Solution

```yaml
annotations:
  nginx.ingress.kubernetes.io/proxy-body-size: "50m"
```

---

## Exercise 1.3 Solution

```yaml
annotations:
  nginx.ingress.kubernetes.io/proxy-read-timeout: "120"
```

---

## Exercise 2.1 Solution

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rewrite-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /app(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: app-svc
            port:
              number: 80
```

---

## Exercise 2.2 Solution

```bash
# Generate certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=secure.example.com"

# Create secret
kubectl create secret tls secure-tls --cert=tls.crt --key=tls.key -n ex-2-2
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  namespace: ex-2-2
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - secure.example.com
    secretName: secure-tls
  rules:
  - host: secure.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-svc
            port:
              number: 80
```

---

## Exercise 2.3 Solution

```bash
curl -k -H "Host: secure.example.com" https://localhost/
```

---

## Exercise 3.1 Solution

**Root Cause:** pathType is `Exact`, so only `/api` matches exactly, not `/api/users`.

**Fix:** Change to `pathType: Prefix`.

---

## Exercise 3.2 Solution

**Root Cause:** TLS secrets must have type `kubernetes.io/tls` with keys `tls.crt` and `tls.key`, not `cert` and `key`.

**Fix:** Create proper TLS secret:
```bash
kubectl create secret tls proper-tls --cert=tls.crt --key=tls.key -n ex-3-2
```

---

## Exercise 3.3 Solution

Check for typos like:
- `nginx.ingress.kubernetes.io/rewirte-target` (misspelled)
- Missing `/` in annotation namespace

---

## Exercise 4.1 Solution

```yaml
spec:
  tls:
  - hosts:
    - a.example.com
    secretName: a-tls
  - hosts:
    - b.example.com
    secretName: b-tls
```

---

## Exercise 4.2 Solution

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls
```

---

## Exercise 4.3 Solution

Configure default certificate in nginx-ingress controller args or ConfigMap:

```yaml
# In controller deployment
args:
  - --default-ssl-certificate=<namespace>/<secret-name>
```

---

## Exercise 5.1 Solution

ssl-redirect is enabled by default. Just create an Ingress with TLS:

```yaml
spec:
  tls:
  - hosts:
    - example.com
    secretName: example-tls
```

All HTTP requests will redirect to HTTPS.

---

## Exercise 5.2 Solution

Common TLS issues:
1. Secret in wrong namespace
2. Secret has wrong type
3. Certificate does not match hostname
4. Secret keys are wrong (`tls.crt`/`tls.key` required)

---

## Exercise 5.3 Solution

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: production
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.company.com
    secretName: app-tls
  rules:
  - host: app.company.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-svc
            port:
              number: 80
```

---

## Common Mistakes

- **Wrong annotation prefix:** Must be `nginx.ingress.kubernetes.io/`
- **TLS secret wrong type:** Must be `kubernetes.io/tls`
- **Rewrite with Exact pathType:** Use Prefix for rewrites
- **Certificate hostname mismatch:** CN must match Ingress host
