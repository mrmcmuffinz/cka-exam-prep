# Answer Key: Pod Configuration Injection

Complete solutions for the 15 exercises in `pod-config-injection-homework.md`. Each solution shows the recommended approach and, where both are reasonable, the imperative and declarative forms side by side. For projected volumes and any pod that combines multiple sources, declarative YAML is the only realistic approach because imperative flags cannot express projected volumes, and that is called out explicitly where it applies. For debugging exercises, each solution walks through the diagnosis (what `kubectl` output reveals the problem), the root cause, and the fix.

## Exercise 1.1 Solution

Two ConfigMap creation options, both valid. The imperative form is faster and what you want on the exam.

**Imperative:**

```bash
kubectl -n ex-1-1 create configmap app-settings \
  --from-literal=GREETING=hello \
  --from-literal=AUDIENCE=world

kubectl -n ex-1-1 run greeter --image=busybox:1.36 \
  --restart=Never \
  -- sh -c 'echo "$GREETING, $AUDIENCE"; sleep 3600'
```

Note that `kubectl run` does not have a flag for `envFrom`. To add `envFrom`, generate YAML and edit it, or apply declarative YAML directly:

**Declarative (complete solution):**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-settings
  namespace: ex-1-1
data:
  GREETING: hello
  AUDIENCE: world
---
apiVersion: v1
kind: Pod
metadata:
  name: greeter
  namespace: ex-1-1
spec:
  restartPolicy: Never
  containers:
    - name: greeter
      image: busybox:1.36
      command: ["sh", "-c", "echo \"$GREETING, $AUDIENCE\"; sleep 3600"]
      envFrom:
        - configMapRef:
            name: app-settings
EOF
```

The key shape is `envFrom: [{configMapRef: {name: app-settings}}]`. The bulk-import form is one YAML entry regardless of how many keys are in the ConfigMap, which is why it scales well.

## Exercise 1.2 Solution

**Imperative for the Secret:**

```bash
kubectl -n ex-1-2 create secret generic api-creds \
  --from-literal=API_KEY=sk-test-9f8e7d6c5b4a3210
```

**Declarative pod (only realistic form for a single env var with valueFrom):**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: api-consumer
  namespace: ex-1-2
spec:
  restartPolicy: Never
  containers:
    - name: api-consumer
      image: busybox:1.36
      command: ["sh", "-c", "echo \"key length: ${#API_KEY}\"; sleep 3600"]
      env:
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: api-creds
              key: API_KEY
EOF
```

The field is `secretKeyRef`, not `secretRef`. The former is for selecting one key into one env var; the latter is for bulk-importing every key with `envFrom`. This distinction trips people up on the exam.

## Exercise 1.3 Solution

**ConfigMap from file:**

```bash
kubectl -n ex-1-3 create configmap server-config \
  --from-file=/tmp/ex-1-3/server.conf
```

When you use `--from-file` with just a path, the key in the ConfigMap becomes the base filename (`server.conf`) and the value is the file's contents. If you want to rename the key on the way in, use `--from-file=NEWKEY=/path/to/file`.

**Pod (declarative):**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: config-reader
  namespace: ex-1-3
spec:
  restartPolicy: Never
  containers:
    - name: reader
      image: busybox:1.36
      command: ["sh", "-c", "cat /etc/server/server.conf; sleep 3600"]
      volumeMounts:
        - name: cfg
          mountPath: /etc/server
          readOnly: true
  volumes:
    - name: cfg
      configMap:
        name: server-config
EOF
```

Because the full ConfigMap is mounted (no `items` list), every key appears as a file. There is only one key (`server.conf`), so only one file shows up: `/etc/server/server.conf`.

## Exercise 2.1 Solution

Create both resources imperatively, then apply the pod declaratively.

```bash
kubectl -n ex-2-1 create configmap web-config \
  --from-literal=SERVER_NAME=webapp.example.com \
  --from-literal=LOG_LEVEL=debug

kubectl -n ex-2-1 create secret generic web-creds \
  --from-literal=DB_USER=webuser \
  --from-literal=DB_PASSWORD='correct-horse-battery-staple'
```

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: ex-2-1
spec:
  restartPolicy: Never
  containers:
    - name: web
      image: busybox:1.36
      command: ["sh", "-c", "env | grep -E '^(SERVER_NAME|LOG_LEVEL|DB_USER|DB_PASSWORD)=' | sort; sleep 3600"]
      envFrom:
        - configMapRef:
            name: web-config
        - secretRef:
            name: web-creds
EOF
```

Two `envFrom` entries, one ConfigMap, one Secret. Every key from each becomes an env var. This is the bread-and-butter shape for configuration injection and shows up on nearly every production manifest.

## Exercise 2.2 Solution

ConfigMap first. A multi-key ConfigMap is easiest to write declaratively even though `--from-literal` also works:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: ex-2-2
data:
  server.conf: "server { listen 80; }"
  proxy.conf: "proxy_pass http://backend;"
  ssl.conf: "ssl_protocols TLSv1.2 TLSv1.3;"
  cache.conf: "proxy_cache_valid 200 1h;"
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx-sel
  namespace: ex-2-2
spec:
  restartPolicy: Never
  containers:
    - name: sel
      image: busybox:1.36
      command: ["sh", "-c", "ls /etc/nginx/selected; echo \"---\"; cat /etc/nginx/selected/default.conf; cat /etc/nginx/selected/tls.conf; sleep 3600"]
      volumeMounts:
        - name: cfg
          mountPath: /etc/nginx/selected
          readOnly: true
  volumes:
    - name: cfg
      configMap:
        name: nginx-config
        items:
          - key: server.conf
            path: default.conf
          - key: ssl.conf
            path: tls.conf
EOF
```

The `items` list both selects which keys to project and renames them on disk. Once you use `items`, any key not listed is silently omitted from the volume, which is how `proxy.conf` and `cache.conf` are excluded. Remember that `path` is always relative and must not start with `/`.

## Exercise 2.3 Solution

The multi-line YAML value for `app.yaml` is easiest to express with a literal block scalar (`|`):

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: ex-2-3
data:
  app.yaml: |
    mode: production
    workers: 8
    timeouts:
      read: 30s
      write: 30s
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: ex-2-3
type: Opaque
stringData:
  TOKEN: tok-abc-123-xyz-789
---
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
  namespace: ex-2-3
spec:
  containers:
    - name: nginx
      image: nginx:1.25-alpine
      env:
        - name: APP_TOKEN
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: TOKEN
      volumeMounts:
        - name: appcfg
          mountPath: /etc/nginx/app.yaml
          subPath: app.yaml
          readOnly: true
  volumes:
    - name: appcfg
      configMap:
        name: app-config
EOF
```

The critical line is `subPath: app.yaml` on the volume mount. Without it, mounting at `/etc/nginx/app.yaml` would still work (the mount path becomes the volume's root directory), but mounting at `/etc/nginx` would shadow everything in that directory including nginx's own `nginx.conf`, and nginx would fail to start. `subPath` says "take only this one entry from the volume and present it at the mount path as a single file," which leaves the rest of `/etc/nginx` intact.

Note that `restartPolicy` is omitted, which defaults to `Always`. That is fine here because nginx is a long-running service. Use `Never` only for one-shot workloads like the `busybox` pods in most of these exercises.

## Exercise 3.1 Solution

**Diagnosis:** The pod status is `CreateContainerConfigError`. Confirm with:

```bash
kubectl -n ex-3-1 get pod billing
kubectl -n ex-3-1 describe pod billing | grep -A5 Events
```

The events show a message like `couldn't find key APP_ENVIRONMENT in ConfigMap ex-3-1/env-config`. Inspect the ConfigMap:

```bash
kubectl -n ex-3-1 get configmap env-config -o yaml
```

The ConfigMap has keys `APP_NAME`, `APP_ENV`, and `MAX_CONNS`. The pod's second `env` entry references `APP_ENVIRONMENT`, which does not exist.

**Root cause:** Key name mismatch in `configMapKeyRef.key`. The pod references `APP_ENVIRONMENT` but the ConfigMap defines `APP_ENV`.

**Fix:** Edit the pod's env reference to use the key that actually exists:

```bash
kubectl -n ex-3-1 delete pod billing
```

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: billing
  namespace: ex-3-1
spec:
  restartPolicy: Never
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "env | grep -E '^(APP_|MAX_)' | sort; sleep 3600"]
      env:
        - name: APP_NAME
          valueFrom:
            configMapKeyRef:
              name: env-config
              key: APP_NAME
        - name: APP_ENV
          valueFrom:
            configMapKeyRef:
              name: env-config
              key: APP_ENV
        - name: MAX_CONNS
          valueFrom:
            configMapKeyRef:
              name: env-config
              key: MAX_CONNS
EOF
```

Either the key on the ConfigMap or the reference on the pod could have been renamed. Changing the pod is almost always the right call because ConfigMap key names are contracts with every consumer, while pod YAML is easy to regenerate.

## Exercise 3.2 Solution

**Diagnosis:** Applying the setup produces an error on the Secret:

```
The Secret "app-secret" is invalid: data[DATABASE_URL]: Invalid value: ...: illegal base64 data
```

The Secret is rejected, so it is never created. The Pod is accepted (separate document) but cannot start:

```bash
kubectl -n ex-3-2 get pod consumer
kubectl -n ex-3-2 describe pod consumer | grep -A5 Events
```

The events show `secret "app-secret" not found`.

**Root cause:** The Secret uses `data:` with a value that is not valid base64. The value `postgres://user:pass@db.internal:5432/billing` contains `:`, `@`, and `.`, none of which are in the base64 alphabet. The API server rejects the whole object. `API_TOKEN: dG9rLTQyMDY5` happens to be valid base64 (it decodes to `tok-42069`), so that key alone would have been fine, but the invalid one poisons the entire Secret.

**Fix:** The cleanest option is to switch to `stringData`, which accepts plain strings and has Kubernetes encode them at apply time:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: ex-3-2
type: Opaque
stringData:
  DATABASE_URL: postgres://user:pass@db.internal:5432/billing
  API_TOKEN: tok-42069
EOF
```

Alternative using `data:` with proper encoding:

```bash
DB_URL_B64=$(echo -n 'postgres://user:pass@db.internal:5432/billing' | base64 -w0)
TOKEN_B64=$(echo -n 'tok-42069' | base64 -w0)

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: ex-3-2
type: Opaque
data:
  DATABASE_URL: ${DB_URL_B64}
  API_TOKEN: ${TOKEN_B64}
EOF
```

Note the single-quote `'EOF'` versus unquoted `EOF` matters: unquoted allows `${VAR}` expansion, quoted does not. Both forms are useful; pick the one that matches whether you want shell expansion.

Once the Secret exists, the pod's `envFrom.secretRef` picks it up. You may need to delete and recreate the pod to get it out of the error state:

```bash
kubectl -n ex-3-2 delete pod consumer --ignore-not-found
kubectl -n ex-3-2 apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: consumer
  namespace: ex-3-2
spec:
  restartPolicy: Never
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo DB=$DATABASE_URL; echo TOKEN=$API_TOKEN; sleep 3600"]
      envFrom:
        - secretRef:
            name: app-secret
EOF
```

## Exercise 3.3 Solution

**Diagnosis:** Applying the setup produces an error on the Pod:

```
The Pod "filereader" is invalid: spec.volumes[0].configMap.items[0].path: Invalid value: "/main.conf": must not be an absolute path
```

The ConfigMap applies cleanly, but the Pod is rejected:

```bash
kubectl -n ex-3-3 get configmap files-config
kubectl -n ex-3-3 get pod filereader
```

The configmap exists; no pod.

**Root cause:** The `items` list inside a volume source requires `path` to be relative. The value `/main.conf` has a leading slash, which makes it absolute. This validation exists because `items.path` is joined with the mount path to compute the final file location, and an absolute path would escape that.

**Fix:** Remove the leading slash:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: filereader
  namespace: ex-3-3
spec:
  restartPolicy: Never
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "cat /etc/app/main.conf; echo '---'; cat /etc/app/logs.conf; sleep 3600"]
      volumeMounts:
        - name: cfg
          mountPath: /etc/app
          readOnly: true
  volumes:
    - name: cfg
      configMap:
        name: files-config
        items:
          - key: app.conf
            path: main.conf
          - key: logging.conf
            path: logs.conf
EOF
```

Only the change is `path: /main.conf` to `path: main.conf`. The pod then creates normally.

## Exercise 4.1 Solution

ConfigMap and pod, both declarative. The pod has to mount the ConfigMap at `/etc/nginx/conf.d`, which is a directory nginx already includes from. A full-volume mount (no `items`, no `subPath`) shadows that directory so that the only `.conf` files are the ones in the ConfigMap.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-sites
  namespace: ex-4-1
data:
  default.conf: |
    server { listen 80 default_server; server_name _; return 200 "default\n"; }
  api.conf: |
    server { listen 80; server_name api.example.com; location / { return 200 "api\n"; } }
  admin.conf: |
    server { listen 80; server_name admin.example.com; location / { return 200 "admin\n"; } }
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  namespace: ex-4-1
spec:
  containers:
    - name: nginx
      image: nginx:1.25-alpine
      volumeMounts:
        - name: sites
          mountPath: /etc/nginx/conf.d
          readOnly: true
  volumes:
    - name: sites
      configMap:
        name: nginx-sites
EOF
```

Nginx's default `/etc/nginx/nginx.conf` contains `include /etc/nginx/conf.d/*.conf;`, which picks up everything in the mounted directory. Because the mount shadows the original contents of `/etc/nginx/conf.d/` (which in the upstream image contains a single `default.conf`), the behavior is effectively a replacement. This is the idiomatic pattern for configuring nginx via Kubernetes.

## Exercise 4.2 Solution

Projected volumes are the only realistic way to combine a ConfigMap, a Secret, and downward API data into one mount point, so this is strictly declarative.

```bash
kubectl -n ex-4-2 create configmap app-cfg \
  --from-literal=LOG_LEVEL=info \
  --from-file=app.yaml=/dev/stdin <<'EOF'
server:
  port: 8080
  host: 0.0.0.0
EOF

kubectl -n ex-4-2 create secret generic app-secrets \
  --from-literal=db-password=super-secret-db-pw \
  --from-literal=api-key=sk-prod-abcdef
```

Or entirely declarative:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-cfg
  namespace: ex-4-2
data:
  LOG_LEVEL: info
  app.yaml: |
    server:
      port: 8080
      host: 0.0.0.0
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: ex-4-2
type: Opaque
stringData:
  db-password: super-secret-db-pw
  api-key: sk-prod-abcdef
EOF
```

Then the pod:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: app
  namespace: ex-4-2
  labels:
    app: billing
    tier: backend
  annotations:
    deploy-id: r-42
spec:
  restartPolicy: Never
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "ls -la /etc/app; echo \"---\"; find /etc/app -type f | sort; sleep 3600"]
      env:
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: app-cfg
              key: LOG_LEVEL
      volumeMounts:
        - name: app-config
          mountPath: /etc/app
          readOnly: true
  volumes:
    - name: app-config
      projected:
        defaultMode: 0444
        sources:
          - configMap:
              name: app-cfg
              items:
                - key: app.yaml
                  path: config/app.yaml
          - secret:
              name: app-secrets
              items:
                - key: db-password
                  path: secrets/db-password
                  mode: 0400
                - key: api-key
                  path: secrets/api-key
                  mode: 0400
          - downwardAPI:
              items:
                - path: pod/name
                  fieldRef:
                    fieldPath: metadata.name
                - path: pod/namespace
                  fieldRef:
                    fieldPath: metadata.namespace
                - path: pod/labels
                  fieldRef:
                    fieldPath: metadata.labels
EOF
```

Three things to notice. First, the `items` list on the ConfigMap source includes only `app.yaml`, which is how `LOG_LEVEL` is kept out of the volume even though it is in the same ConfigMap. The env var separately imports `LOG_LEVEL`. Second, the `mode: 0400` on each Secret item overrides the volume-wide `defaultMode: 0444` for just those two files. Third, downward API items are identified by `fieldRef.fieldPath` using the standard JSONPath-like syntax (`metadata.name`, `metadata.labels`, and so on).

## Exercise 4.3 Solution

A two-container pod where each container has its own volume mount but both mounts are backed by `items` lists from the same ConfigMap. This works because a volume can be mounted by multiple containers, and each container's `volumeMounts` is independent of the others.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: shared-cfg
  namespace: ex-4-3
data:
  writer.conf: |
    role=writer
    queue=work-in
  reader.conf: |
    role=reader
    queue=work-out
  shared.conf: |
    cluster=prod
    region=us-east
  unused.conf: |
    nothing=interesting
---
apiVersion: v1
kind: Pod
metadata:
  name: duo
  namespace: ex-4-3
spec:
  restartPolicy: Never
  containers:
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c", "echo \"writer view:\"; ls /etc/writer; cat /etc/writer/role.conf; cat /etc/writer/common.conf; sleep 3600"]
      volumeMounts:
        - name: writer-cfg
          mountPath: /etc/writer
          readOnly: true
    - name: reader
      image: busybox:1.36
      command: ["sh", "-c", "echo \"reader view:\"; ls /etc/reader; cat /etc/reader/role.conf; cat /etc/reader/common.conf; sleep 3600"]
      volumeMounts:
        - name: reader-cfg
          mountPath: /etc/reader
          readOnly: true
  volumes:
    - name: writer-cfg
      configMap:
        name: shared-cfg
        items:
          - key: writer.conf
            path: role.conf
          - key: shared.conf
            path: common.conf
    - name: reader-cfg
      configMap:
        name: shared-cfg
        items:
          - key: reader.conf
            path: role.conf
          - key: shared.conf
            path: common.conf
EOF
```

Two separate `volumes` entries both reference `configMap: {name: shared-cfg}` but project different `items`. This gives each container a tailored view of the shared ConfigMap. Using `items` is the key; without it, both containers would see every key in `shared-cfg` including `unused.conf`, which the exercise explicitly forbids.

## Exercise 5.1 Solution

**Diagnosis:** Three independent issues.

First, look at what actually applied:

```bash
kubectl -n ex-5-1 get configmap runtime-cfg -o yaml
kubectl -n ex-5-1 get secret runtime-creds -o yaml
kubectl -n ex-5-1 get pod runtime
```

The setup error messages (if you ran them) should have included two warnings. The Secret `runtime-creds` failed apply with something like `Invalid value: "s3cret-pw": illegal base64 data` because the value in `data.password` is not base64 encoded. The Secret therefore does not exist. The patch on the immutable ConfigMap also failed with `field is immutable when immutable field is set`.

Describe the pod to confirm:

```bash
kubectl -n ex-5-1 describe pod runtime | grep -A5 Events
```

The events complain about the missing Secret `runtime-creds`.

**Root causes:**

1. **ConfigMap is immutable** and still holds `mode: staging`. The patch to change to `mode: production` is silently blocked. Immutable resources must be deleted and recreated, not updated.
2. **Secret `data.password`** holds the plaintext `s3cret-pw`, which is not valid base64. The whole Secret object is rejected, so no Secret exists.
3. As a consequence of (2), the pod cannot start because it references the non-existent Secret.

**Fix:**

```bash
# Fix 1: recreate the ConfigMap with mode=production
kubectl -n ex-5-1 delete configmap runtime-cfg
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: runtime-cfg
  namespace: ex-5-1
data:
  mode: production
  workers: "4"
EOF
```

Whether to keep `immutable: true` in the recreated ConfigMap is a design choice. If you want future updates to be possible without deletion, leave it off. If you want to preserve the original intent of preventing accidental updates, add it back.

```bash
# Fix 2: replace the Secret with a working one
kubectl -n ex-5-1 delete secret runtime-creds --ignore-not-found
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: runtime-creds
  namespace: ex-5-1
type: Opaque
stringData:
  username: operator
  password: s3cret-pw
EOF
```

Using `stringData` sidesteps the encoding question entirely. You could also keep `data` and encode both values yourself with `base64 -w0`.

```bash
# Fix 3: recreate the pod so it picks up the resources cleanly
kubectl -n ex-5-1 delete pod runtime --ignore-not-found
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: runtime
  namespace: ex-5-1
spec:
  restartPolicy: Never
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo MODE=$MODE; echo WORKERS=$WORKERS; echo USER=$USERNAME; echo PASS=$PASSWORD; sleep 3600"]
      env:
        - name: MODE
          valueFrom:
            configMapKeyRef:
              name: runtime-cfg
              key: mode
        - name: WORKERS
          valueFrom:
            configMapKeyRef:
              name: runtime-cfg
              key: workers
        - name: USERNAME
          valueFrom:
            secretKeyRef:
              name: runtime-creds
              key: username
        - name: PASSWORD
          valueFrom:
            secretKeyRef:
              name: runtime-creds
              key: password
EOF
```

A subtle detail: even if the Secret had applied successfully with both `data.username: YWRtaW4=` (base64 of `admin`) and `stringData.username: operator`, `stringData` wins on conflict, so `USERNAME` would resolve to `operator`. The original setup tried to rely on that precedence, but because the whole Secret was rejected, the precedence never got a chance to matter.

## Exercise 5.2 Solution

**Diagnosis:** The setup fails at Pod creation:

```
The Pod "combined" is invalid: spec.volumes[0].projected.sources[0].configMap.items[1].path: Invalid value: "/region": must not be an absolute path
```

Or, if that is fixed, the next error:

```
The Pod "combined" is invalid: spec.volumes[0].projected: Invalid value: ...: duplicate path "app.properties"
```

Check what exists:

```bash
kubectl -n ex-5-2 get configmap base-cfg
kubectl -n ex-5-2 get secret combined-creds
kubectl -n ex-5-2 get pod combined
```

The ConfigMap and Secret apply cleanly. The pod does not exist.

**Root causes:** Two issues in the projected volume spec.

1. **Leading slash in path:** The ConfigMap source has `- key: region, path: /region`. Same rule as Exercise 3.3 applies to projected volume items: `path` must be relative.
2. **Duplicate path:** The spec has three sources, and two of them write to the same path `app.properties`. The first source writes the ConfigMap's multi-line properties to `app.properties`; the third source (a redundant second reference to the Secret) writes the password to `app.properties`. Projected volumes reject duplicate paths at creation.

**Fix:** Strip the leading slash, remove the duplicate Secret source entirely.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: combined
  namespace: ex-5-2
spec:
  restartPolicy: Never
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "ls /etc/combined; echo '---'; cat /etc/combined/api-token; echo '---'; cat /etc/combined/app.properties; sleep 3600"]
      volumeMounts:
        - name: combined
          mountPath: /etc/combined
          readOnly: true
  volumes:
    - name: combined
      projected:
        sources:
          - configMap:
              name: base-cfg
              items:
                - key: app.properties
                  path: app.properties
                - key: region
                  path: region
          - secret:
              name: combined-creds
              items:
                - key: db_password
                  path: db-password
                - key: api_token
                  path: api-token
EOF
```

The duplicate secret source is gone. The `region` path no longer has a leading slash. The resulting volume has exactly the four files the verification asks for.

## Exercise 5.3 Solution

This is the comprehensive build. Given the scale, declarative YAML is the only practical option. Build the five resources first, then the pod.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: base-config
  namespace: ex-5-3
data:
  APP_NAME: orders
  REGION: us-east-1
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: env-overrides-prod
  namespace: ex-5-3
data:
  LOG_LEVEL: warn
  WORKERS: "16"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: component-web
  namespace: ex-5-3
data:
  web.yaml: |
    listen: 0.0.0.0:8080
    timeout: 30s
    max_body: 10MB
---
apiVersion: v1
kind: Secret
metadata:
  name: creds-db
  namespace: ex-5-3
type: Opaque
stringData:
  username: orders-db-user
  password: db-tier-pw-2026
---
apiVersion: v1
kind: Secret
metadata:
  name: creds-external-api
  namespace: ex-5-3
type: Opaque
stringData:
  token: ext-api-tok-9x8y7z
EOF
```

Now the pod:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: orders-web
  namespace: ex-5-3
  labels:
    app: orders
    component: web
spec:
  restartPolicy: Never
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo ENV:; env | grep -E \"^(APP_NAME|REGION|LOG_LEVEL|WORKERS)=\" | sort; echo FILES:; find /etc/orders -type f | sort; echo WEB-CONFIG:; cat /etc/orders/web/web.yaml; sleep 3600"]
      envFrom:
        - configMapRef:
            name: base-config
        - configMapRef:
            name: env-overrides-prod
      volumeMounts:
        - name: orders-config
          mountPath: /etc/orders
          readOnly: true
  volumes:
    - name: orders-config
      projected:
        defaultMode: 0444
        sources:
          - configMap:
              name: component-web
              items:
                - key: web.yaml
                  path: web/web.yaml
          - secret:
              name: creds-db
              items:
                - key: username
                  path: secrets/db/username
                  mode: 0400
                - key: password
                  path: secrets/db/password
                  mode: 0400
          - secret:
              name: creds-external-api
              items:
                - key: token
                  path: secrets/external-api/token
                  mode: 0400
          - downwardAPI:
              items:
                - path: pod/labels
                  fieldRef:
                    fieldPath: metadata.labels
EOF
```

A few decisions worth explaining. The order of `envFrom` entries matters for conflict resolution: later entries win. Here the entries are ordered `base-config` then `env-overrides-prod`, which would correctly let the prod overrides override base values on any conflicting key. There are no conflicts in this setup (the two ConfigMaps use disjoint key sets), but the ordering reflects intent.

The projected volume uses four sources to produce the target file layout. The `items.path` values are subdirectory-qualified (for example `web/web.yaml`, `secrets/db/password`) so the kubelet automatically creates the subdirectories during volume assembly. Per-item `mode: 0400` on every Secret item overrides the projected volume's `defaultMode: 0444`, so credential files are owner-read-only while the non-secret files (ConfigMap and downward API) are world-readable under the default.

## Common Mistakes

**Confusing `data` and `stringData` in a Secret.** The `data` field holds base64-encoded values; Kubernetes decodes them on injection. The `stringData` field holds plain strings that Kubernetes encodes for you at apply time and stores internally under `data`. If you put a plaintext password under `data`, the API server rejects the whole object if the value happens to contain characters outside the base64 alphabet, and accepts but produces garbled output if it happens to be decodable as (junk) base64. When writing Secrets by hand, prefer `stringData`. When both are set for the same key, `stringData` wins.

**Forgetting `base64 -w0` when encoding manually.** The default behavior of `base64` is to wrap output at 76 characters, inserting literal newlines. A long password, once newline-wrapped, produces a multi-line YAML value that breaks in confusing ways on apply. Always pass `-w0` to disable wrapping. The older pattern of piping to `tr -d '\n'` works but adds a second process and is easier to omit by accident. `echo -n 'value' | base64 -w0` is the one-line form to memorize.

**Mixing up `configMapRef` and `configMapKeyRef` (and the Secret equivalents).** The `configMapRef` field is used under `envFrom` to bulk-import every key as an env var. The `configMapKeyRef` field is used under `env.valueFrom` to select one specific key into one specific env var. Same distinction for `secretRef` (bulk, under `envFrom`) versus `secretKeyRef` (single, under `env.valueFrom`). If you see `CreateContainerConfigError` with a message about a `key` not found, you are using `configMapKeyRef` or `secretKeyRef` with a wrong `key`. If the error is about the ConfigMap or Secret not being found, it applies regardless of which ref you used.

**Shadowing an existing directory with a full-volume mount when you meant subPath.** Mounting a ConfigMap volume at `/etc/nginx` replaces the entire contents of `/etc/nginx` with the ConfigMap's files, which deletes nginx's own `nginx.conf` from the container's perspective and causes nginx to fail startup. If you only want to project one file into an existing directory, use `subPath` on the `volumeMounts` entry to mount exactly that one file at exactly its target path. Reserve full-directory mounts for directories where you intend to replace everything (like `/etc/nginx/conf.d` in Exercise 4.1) or directories that do not exist in the base image.

**Expecting environment variables to update when the ConfigMap or Secret changes.** They do not. Env vars are materialized once at container start. If the source ConfigMap changes, env-var-consuming pods will keep the old value until they restart. This is not a bug; it is the intentional behavior. For live-updating config, use volume mounts without `subPath`. The kubelet refreshes volume-projected files periodically (roughly every 60 to 90 seconds on most clusters).

**Using an absolute path in `items.path`.** The `path` under an `items` entry must be relative, with no leading slash. Absolute paths are rejected at pod creation. The `path` value is implicitly joined with the volume's mount point to produce the final on-disk location, so a leading slash would escape the mount.

**Trying to update an immutable ConfigMap or Secret.** Setting `immutable: true` is a one-way door. Once applied, the `data` and `binaryData` fields (and the `immutable` field itself) can never be changed. To replace an immutable resource, you must delete it and apply a new one, which means pods that reference it by name may need to be restarted to see the new values.

**Case sensitivity in keys.** ConfigMap and Secret keys are case-sensitive. `APP_NAME` and `app_name` are different keys. The same is true for the field path under `configMapKeyRef.key` and `secretKeyRef.key`. A common debugging signal is `CreateContainerConfigError` with a message like `couldn't find key <name>`, which usually means a typo or case mismatch.

**Using keys with dots in `envFrom`.** The `envFrom` bulk import silently skips any key that is not a valid POSIX identifier, and dots, hyphens, and other special characters are not allowed in env var names. The kubelet emits a warning event but the pod still starts. If a key with dots needs to become an env var, rename the key in the ConfigMap, or select it explicitly through `env.valueFrom.configMapKeyRef` where you can give the env var a different (valid) name.

**Duplicate paths across projected volume sources.** A projected volume validates that no two sources target the same `path`. If two sources both write to `app.properties`, the pod is rejected. This is different from the `envFrom` case where later sources silently override earlier ones. On projected volumes, collisions are hard errors.

## Verification Commands Cheat Sheet

The same half-dozen commands cover the vast majority of configuration-injection debugging on the exam. Get them into muscle memory.

**Inspect a ConfigMap:**

```bash
kubectl get configmap NAME -o yaml                          # full content, including keys
kubectl describe configmap NAME                             # pretty-printed summary
kubectl get configmap NAME -o jsonpath='{.data.KEY}' ; echo # single key value
```

**Inspect a Secret (and decode):**

```bash
kubectl get secret NAME -o yaml
kubectl describe secret NAME
kubectl get secret NAME -o jsonpath='{.data.KEY}' | base64 -d ; echo
```

**Pod status and events:**

```bash
kubectl get pod NAME
kubectl get pod NAME -o wide
kubectl describe pod NAME
kubectl get events --field-selector involvedObject.name=NAME --sort-by=.lastTimestamp
```

**Inside a running container:**

```bash
kubectl exec NAME -- env | sort                 # all env vars
kubectl exec NAME -- printenv VAR1 VAR2 VAR3    # specific env vars
kubectl exec NAME -- ls -la /path/to/mount      # files and permissions
kubectl exec NAME -- cat /path/to/mount/FILE    # file contents
kubectl exec NAME -- stat -c '%a %n' /path/FILE # numeric permissions
kubectl exec NAME -- find /path -type f         # recursive file listing
```

**Generate YAML scaffolding fast (imperative-to-declarative):**

```bash
kubectl create configmap NAME --from-literal=K=V --dry-run=client -o yaml
kubectl create secret generic NAME --from-literal=K=V --dry-run=client -o yaml
kubectl run NAME --image=IMG --dry-run=client -o yaml -- CMD
```

**Multi-container pod exec:**

```bash
kubectl exec POD -c CONTAINER -- CMD            # target a specific container
```

For debugging configuration injection specifically, the diagnostic sequence is almost always: check the pod status, describe to see events, inspect the referenced ConfigMap or Secret, and then exec to see what actually made it inside the container. If the pod fails to apply at all (validation errors), the error message from `kubectl apply` itself usually tells you exactly which field is wrong.
