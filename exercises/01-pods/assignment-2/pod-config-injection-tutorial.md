# Tutorial: Pod Configuration Injection

This tutorial walks through every major pattern for injecting configuration data into Kubernetes pods. You will build a single realistic pod that represents a web application reading its configuration from four sources: non-sensitive application settings in a ConfigMap, database credentials in a Secret, information about the pod itself via the downward API, and a few stable values hardcoded as environment variables. Those sources are delivered into the container through a mix of environment variables and a projected volume.

By the end of the tutorial you will have seen imperative and declarative creation for both ConfigMaps and Secrets, the four main injection patterns (single env var, bulk env vars, volume mount, projected volume), the update propagation behavior that makes env vars and volume mounts different, and the inspection commands that let you verify what actually ended up inside the container.

Work through the tutorial in order. Every snippet is copy-paste ready. The tutorial uses its own namespace (`tutorial-pod-config-injection`) so nothing collides with the homework exercises.

## Prerequisites

You need a running Kubernetes cluster and a working `kubectl` context. Verify both before starting:

```bash
kubectl cluster-info
kubectl get nodes
```

Both commands should succeed. If they do not, fix your cluster or kubeconfig before continuing.

## Step 1: Create the Tutorial Namespace

All tutorial resources live in a dedicated namespace so cleanup is a single command at the end.

```bash
kubectl create namespace tutorial-pod-config-injection
kubectl config set-context --current --namespace=tutorial-pod-config-injection
```

The second command sets the default namespace for the rest of the tutorial so you can skip `-n tutorial-pod-config-injection` on every command. Verify the switch:

```bash
kubectl config view --minify -o jsonpath='{..namespace}{"\n"}'
```

Expected output: `tutorial-pod-config-injection`.

## Step 2: Create the Application ConfigMap

ConfigMaps hold non-sensitive key-value data. They support two types of values: short literal strings in the `data` field, and binary data in the `binaryData` field. This tutorial uses only `data`, which is the common case.

The imperative form using `--from-literal` is fastest for a few keys and is worth memorizing for the exam. Here we build one imperatively, then regenerate its YAML to inspect the shape, and finally apply a declarative version that replaces it.

Start with the imperative creation:

```bash
kubectl create configmap webapp-config \
  --from-literal=APP_NAME=webapp \
  --from-literal=APP_MODE=production \
  --from-literal=LOG_LEVEL=info \
  --from-literal=FEATURE_FLAGS=metrics,tracing
```

Inspect what was created:

```bash
kubectl get configmap webapp-config -o yaml
```

The output shows the `data` field with four keys and their string values, plus standard metadata. The `--from-literal` flag accepts `KEY=VALUE` pairs and each becomes one entry in `data`.

To see the imperative-to-declarative workflow, regenerate that same ConfigMap as YAML without actually creating anything:

```bash
kubectl create configmap webapp-config-preview \
  --from-literal=APP_NAME=webapp \
  --from-literal=APP_MODE=production \
  --dry-run=client -o yaml
```

The `--dry-run=client` flag tells `kubectl` to build the object locally and print it instead of sending it to the cluster. Combined with `-o yaml`, it is the standard shortcut for generating a YAML starting point you can then edit. This is one of the highest-value imperative-to-declarative shortcuts on the CKA exam.

For a realistic workflow, delete the imperative ConfigMap and replace it with a declarative version that also includes a multi-line configuration file as a key value:

```bash
kubectl delete configmap webapp-config
```

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  namespace: tutorial-pod-config-injection
data:
  APP_NAME: webapp
  APP_MODE: production
  LOG_LEVEL: info
  FEATURE_FLAGS: "metrics,tracing"
  app.properties: |
    server.port=8080
    server.host=0.0.0.0
    cache.ttl=300
    cache.size=1024
EOF
```

Every field here has a specific purpose. The `apiVersion: v1` and `kind: ConfigMap` identify the resource type. The `metadata.name` is the identifier used by pods that reference this ConfigMap, and `metadata.namespace` anchors it to the tutorial namespace. Under `data`, each entry is a key-value pair. Values must be strings; numbers and booleans have to be quoted. The `|` block scalar on `app.properties` preserves newlines so the value is a multi-line string that looks like a real properties file. That property value will later be mounted as a file named `app.properties` inside the container, which is the pattern nearly every application uses for its on-disk config.

Verify the full state:

```bash
kubectl describe configmap webapp-config
```

The `describe` output lists each key with its value size and shows the first portion of multi-line values. For a complete view including the raw bytes, `kubectl get configmap webapp-config -o yaml` is still the right tool.

## Step 3: Create the Database Credentials Secret

Secrets look almost identical to ConfigMaps but differ in two important ways. First, values in the `data` field must be base64 encoded, where ConfigMap `data` values are plain strings. Second, Kubernetes classifies Secrets by `type`, which changes how some consumers interpret them. The default type is `Opaque`, used for arbitrary key-value data. Other types like `kubernetes.io/tls` and `kubernetes.io/dockerconfigjson` enforce a specific shape and are consumed by specific components of the cluster.

Kubernetes Secrets are base64 encoded, not encrypted. Anyone who can read a Secret object can trivially decode it. The security of Secrets depends on RBAC controlling who can read them and on etcd encryption at rest, both of which are covered later in the CKA course under Security. Treat Secrets in this tutorial as an interface for sensitive data, not as a security guarantee by themselves.

The imperative form is the easiest way to create Secrets because `kubectl` handles the base64 encoding for you:

```bash
kubectl create secret generic webapp-db-creds \
  --from-literal=DB_USER=appuser \
  --from-literal=DB_PASSWORD='s3cretP@ssw0rd!' \
  --from-literal=DB_HOST=db.internal \
  --from-literal=DB_NAME=webapp
```

The `generic` subcommand creates an `Opaque` Secret. Other subcommands (`tls`, `docker-registry`) create the typed variants. Inspect what was created:

```bash
kubectl get secret webapp-db-creds -o yaml
```

You will see the four keys under `data`, each with a base64-encoded value. To decode one of them back to its original plaintext:

```bash
kubectl get secret webapp-db-creds -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
echo
```

That prints `s3cretP@ssw0rd!`. The `jsonpath` expression extracts a single base64-encoded field, which is then piped to `base64 -d` to decode. The trailing `echo` just adds a newline because `base64 -d` does not emit one.

### base64 Encoding Without kubectl

When you write a Secret YAML by hand, you encode values yourself. Always use `base64 -w0` rather than `base64 | tr -d '\n'`.

```bash
echo -n 's3cretP@ssw0rd!' | base64 -w0
```

The `-n` on `echo` suppresses the trailing newline that would otherwise end up inside the encoded value. The `-w0` on `base64` disables line wrapping, which by default kicks in at 76 characters and inserts literal newlines into the output. If you forget `-w0` on a long value, the resulting YAML has embedded newlines that break parsing in confusing ways. The older workaround of piping to `tr -d '\n'` does the same thing in two steps, but `-w0` is a single flag that is harder to forget and does not require a second process. Make `-w0` your default.

To decode a value you already have on hand:

```bash
echo 'czNjcmV0UEBzc3cwcmQh' | base64 -d
echo
```

### Declarative Secret With stringData

When you write a declarative Secret YAML, you can use either the `data` field (base64-encoded values) or the `stringData` field (plain string values that Kubernetes encodes for you at apply time). The `stringData` field is almost always the better choice in hand-written YAML because it avoids the encode-decode step and is much easier to read. If both fields set the same key, `stringData` wins.

Delete the imperative Secret and replace it with an equivalent declarative one using `stringData`:

```bash
kubectl delete secret webapp-db-creds
```

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: webapp-db-creds
  namespace: tutorial-pod-config-injection
type: Opaque
stringData:
  DB_USER: appuser
  DB_PASSWORD: 's3cretP@ssw0rd!'
  DB_HOST: db.internal
  DB_NAME: webapp
EOF
```

After apply, the Secret still shows base64-encoded values in `data` when you retrieve it, because Kubernetes stored it that way. The `stringData` field is write-only convenience. Verify:

```bash
kubectl get secret webapp-db-creds -o yaml
```

You will see a `data` field with four base64-encoded values and no `stringData` field in the output. That is normal.

## Step 4: Inject a Single Env Var From a ConfigMap

With the ConfigMap and Secret in place, you can start injecting them. The simplest pattern is a single environment variable whose value comes from one specific key of a ConfigMap.

Here is a throwaway pod that demonstrates the shape of `env.valueFrom.configMapKeyRef`. You will delete this pod at the end of the step.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: demo-env-single
  namespace: tutorial-pod-config-injection
spec:
  restartPolicy: Never
  containers:
    - name: shell
      image: busybox:1.36
      command: ["sh", "-c", "echo APP_NAME=$APP_NAME; sleep 3600"]
      env:
        - name: APP_NAME
          valueFrom:
            configMapKeyRef:
              name: webapp-config
              key: APP_NAME
EOF
```

The `env` field on a container is a list where each entry defines one environment variable. The `name` is the name the variable will have inside the container, and it does not have to match the key in the ConfigMap. The `valueFrom` block says the value comes from somewhere other than a literal string, and `configMapKeyRef` points at a specific key in a specific ConfigMap. The `name` inside `configMapKeyRef` is the ConfigMap name, and `key` is the key within that ConfigMap's `data`. If the ConfigMap is missing or the key does not exist, the pod stays in `CreateContainerConfigError` unless you add `optional: true` (covered in a later step).

Wait for the pod to start and then inspect:

```bash
kubectl wait --for=condition=Ready pod/demo-env-single --timeout=60s
kubectl logs demo-env-single
kubectl exec demo-env-single -- env | grep APP_NAME
```

Expected log output contains `APP_NAME=webapp`. The `kubectl exec` verifies the environment variable is actually visible inside the running container, not just printed at startup.

Clean up:

```bash
kubectl delete pod demo-env-single
```

## Step 5: Inject All Keys as Env Vars With envFrom

For the common case where you want every key in a ConfigMap to become an environment variable with the same name, `envFrom` is dramatically shorter than listing each key individually.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: demo-envfrom-cm
  namespace: tutorial-pod-config-injection
spec:
  restartPolicy: Never
  containers:
    - name: shell
      image: busybox:1.36
      command: ["sh", "-c", "env | sort; sleep 3600"]
      envFrom:
        - configMapRef:
            name: webapp-config
EOF
```

The `envFrom` field is a list of sources, each of which imports every key of a ConfigMap or Secret as an environment variable whose name matches the key. Note the two subtle spelling differences from the previous example. It is `configMapRef` (bulk), not `configMapKeyRef` (single key). And there is no `name`/`key` pair because you are importing everything. You can combine `envFrom` and `env` in the same container and you can list multiple `envFrom` sources. If multiple sources define the same key, the later one wins.

One wrinkle: the key `app.properties` in the ConfigMap contains a dot, which is not a valid character in a POSIX environment variable name. Kubernetes will silently skip any key that is not a valid identifier and emit an event warning you. You can see this behavior:

```bash
kubectl wait --for=condition=Ready pod/demo-envfrom-cm --timeout=60s
kubectl describe pod demo-envfrom-cm | grep -A2 Events
```

There should be an event noting that `app.properties` was skipped. The other four keys (`APP_NAME`, `APP_MODE`, `LOG_LEVEL`, `FEATURE_FLAGS`) all made it through. Verify by listing env vars inside the container:

```bash
kubectl exec demo-envfrom-cm -- env | grep -E '^(APP_NAME|APP_MODE|LOG_LEVEL|FEATURE_FLAGS)='
```

All four should print.

Clean up:

```bash
kubectl delete pod demo-envfrom-cm
```

## Step 6: Inject Secret Values as Env Vars

Secrets follow the exact same two patterns, with `secretKeyRef` for a single key and `secretRef` for bulk import. This is why many manifests use a mix: bulk-import the ConfigMap for non-sensitive settings and individually pick specific Secret keys. Here is both in one pod:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: demo-secret-env
  namespace: tutorial-pod-config-injection
spec:
  restartPolicy: Never
  containers:
    - name: shell
      image: busybox:1.36
      command: ["sh", "-c", "env | sort; sleep 3600"]
      envFrom:
        - configMapRef:
            name: webapp-config
        - secretRef:
            name: webapp-db-creds
      env:
        - name: DATABASE_URL
          value: "postgres://user:pass@host/db"
EOF
```

Here the pod gets all ConfigMap keys and all Secret keys as env vars (two `envFrom` entries), plus one literal env var `DATABASE_URL` that is hardcoded in the spec. A real application would usually build `DATABASE_URL` from the individual pieces rather than duplicating them, but this shape (bulk import plus a couple of explicit additions) is extremely common.

Inspect:

```bash
kubectl wait --for=condition=Ready pod/demo-secret-env --timeout=60s
kubectl exec demo-secret-env -- env | grep -E '^(DB_|APP_|LOG_LEVEL|FEATURE_FLAGS|DATABASE_URL)=' | sort
```

You should see all four `DB_*` values from the Secret, the four ConfigMap keys, and `DATABASE_URL`. The Secret values are decoded automatically on injection; they appear as plaintext inside the container.

Clean up:

```bash
kubectl delete pod demo-secret-env
```

## Step 7: Mount a ConfigMap as a Volume

Environment variables are good for simple settings, but applications often expect configuration as files. Volume-mounted ConfigMaps give you that. The full-volume form projects every key as a file at the mount path, with the key name as the filename and the value as the file contents.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: demo-cm-volume
  namespace: tutorial-pod-config-injection
spec:
  restartPolicy: Never
  containers:
    - name: shell
      image: busybox:1.36
      command: ["sh", "-c", "ls -la /etc/webapp; echo '---'; cat /etc/webapp/app.properties; sleep 3600"]
      volumeMounts:
        - name: webapp-config-vol
          mountPath: /etc/webapp
          readOnly: true
  volumes:
    - name: webapp-config-vol
      configMap:
        name: webapp-config
EOF
```

Two blocks are in play here. The pod-level `volumes` list declares a volume named `webapp-config-vol` whose contents come from the ConfigMap `webapp-config`. The container-level `volumeMounts` list mounts that volume at `/etc/webapp` inside the container and marks it read-only (all ConfigMap and Secret volumes are effectively read-only anyway, but being explicit is good practice). When the container starts, `/etc/webapp/` contains one file per ConfigMap key: `APP_NAME`, `APP_MODE`, `LOG_LEVEL`, `FEATURE_FLAGS`, and `app.properties`. Unlike `envFrom`, the `app.properties` key is not skipped here because volume filenames can contain dots.

Verify:

```bash
kubectl wait --for=condition=Ready pod/demo-cm-volume --timeout=60s
kubectl logs demo-cm-volume
kubectl exec demo-cm-volume -- ls /etc/webapp
kubectl exec demo-cm-volume -- cat /etc/webapp/app.properties
```

The `app.properties` file should print the full multi-line property file. Clean up:

```bash
kubectl delete pod demo-cm-volume
```

### Mounting Only Specific Keys With items

If you want only a subset of keys, or you want to rename them on disk, use the `items` field on the volume source. Each entry lists a `key` (the ConfigMap key) and a `path` (the relative path inside the mount, without a leading slash).

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: demo-cm-items
  namespace: tutorial-pod-config-injection
spec:
  restartPolicy: Never
  containers:
    - name: shell
      image: busybox:1.36
      command: ["sh", "-c", "ls -la /etc/webapp; sleep 3600"]
      volumeMounts:
        - name: cfg
          mountPath: /etc/webapp
          readOnly: true
  volumes:
    - name: cfg
      configMap:
        name: webapp-config
        items:
          - key: app.properties
            path: app.conf
          - key: LOG_LEVEL
            path: logging/level
EOF
```

Once `items` is specified, only the listed keys appear in the volume. Every other key is silently omitted. The `path` field is a relative path from the mount point, and subdirectories are created as needed. So `/etc/webapp/app.conf` is the renamed `app.properties`, and `/etc/webapp/logging/level` is a file containing `info` (the value of `LOG_LEVEL`). Note that `path` must not start with `/`; doing so is a common mistake that fails validation.

Verify and clean up:

```bash
kubectl wait --for=condition=Ready pod/demo-cm-items --timeout=60s
kubectl exec demo-cm-items -- find /etc/webapp -type f
kubectl exec demo-cm-items -- cat /etc/webapp/logging/level
kubectl delete pod demo-cm-items
```

### Mounting a Single File With subPath

`items` controls what appears in the volume, but the volume still replaces the entire mount directory. If you want to inject one file into an existing directory in the container image (for instance `/etc/nginx/nginx.conf` without blowing away the rest of `/etc/nginx/`), you need `subPath`. With `subPath` on the volume mount, only the selected file or subdirectory of the volume is projected to the mount path, and the rest of the target directory is left intact.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: demo-cm-subpath
  namespace: tutorial-pod-config-injection
spec:
  restartPolicy: Never
  containers:
    - name: shell
      image: busybox:1.36
      command: ["sh", "-c", "echo '--- /etc dir still intact ---'; ls /etc | head -20; echo '--- our mounted file ---'; cat /etc/webapp.properties; sleep 3600"]
      volumeMounts:
        - name: cfg
          mountPath: /etc/webapp.properties
          subPath: app.properties
          readOnly: true
  volumes:
    - name: cfg
      configMap:
        name: webapp-config
EOF
```

The key difference is `subPath: app.properties` on the `volumeMounts` entry. This tells the kubelet to take just the `app.properties` entry from the volume (the full ConfigMap is still projected internally) and present that single file at the `mountPath`. The mount path here is `/etc/webapp.properties` (a file, not a directory). Other files in `/etc` are unaffected.

The trade-off with `subPath` is that subPath mounts do not receive updates when the underlying ConfigMap or Secret changes. That is covered in the next step.

Verify and clean up:

```bash
kubectl wait --for=condition=Ready pod/demo-cm-subpath --timeout=60s
kubectl logs demo-cm-subpath
kubectl delete pod demo-cm-subpath
```

## Step 8: Mount a Secret as a Volume

Secret volumes follow the same three patterns (full volume, `items`, `subPath`) with two additional controls: `defaultMode` sets the permission bits for every file in the volume, and per-item `mode` sets permissions on an individual file. Modes are integers in decimal or octal. The usual choice for Secret files is `0400` (owner read only).

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: demo-secret-volume
  namespace: tutorial-pod-config-injection
spec:
  restartPolicy: Never
  containers:
    - name: shell
      image: busybox:1.36
      command: ["sh", "-c", "ls -la /etc/creds; cat /etc/creds/DB_PASSWORD; sleep 3600"]
      volumeMounts:
        - name: creds
          mountPath: /etc/creds
          readOnly: true
  volumes:
    - name: creds
      secret:
        secretName: webapp-db-creds
        defaultMode: 0400
EOF
```

Two field-name differences from ConfigMap volumes are worth noting. The volume source key is `secret:` rather than `configMap:`, and the resource name field is `secretName` rather than `name`. Both are easy to mistype. Permissions of `0400` on every file mean only the file owner (the user the container runs as, root by default) can read them.

Verify and clean up:

```bash
kubectl wait --for=condition=Ready pod/demo-secret-volume --timeout=60s
kubectl logs demo-secret-volume
kubectl exec demo-secret-volume -- ls -la /etc/creds
kubectl delete pod demo-secret-volume
```

The `ls -la` output should show the four credential files with mode `-r--------`.

## Step 9: Update Propagation Behavior

Environment variables and volume-mounted files behave differently when the underlying ConfigMap or Secret changes. Environment variables are injected once at container start and do not update when the source changes. Volume-mounted files, by contrast, are refreshed by the kubelet after a sync interval. This is one of the most common points of confusion.

Start a pod that reads from both an env var and a file, both sourced from the same ConfigMap key:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: demo-propagation
  namespace: tutorial-pod-config-injection
spec:
  restartPolicy: Never
  containers:
    - name: shell
      image: busybox:1.36
      command:
        - sh
        - -c
        - |
          while true; do
            echo "ENV APP_MODE=$APP_MODE | FILE APP_MODE=$(cat /etc/webapp/APP_MODE)"
            sleep 10
          done
      env:
        - name: APP_MODE
          valueFrom:
            configMapKeyRef:
              name: webapp-config
              key: APP_MODE
      volumeMounts:
        - name: cfg
          mountPath: /etc/webapp
          readOnly: true
  volumes:
    - name: cfg
      configMap:
        name: webapp-config
EOF
```

Wait for it to run and start reading logs:

```bash
kubectl wait --for=condition=Ready pod/demo-propagation --timeout=60s
kubectl logs -f demo-propagation &
LOGS_PID=$!
sleep 15
```

You should see lines with `ENV APP_MODE=production | FILE APP_MODE=production`. Now update the ConfigMap to change `APP_MODE` to `staging`:

```bash
kubectl patch configmap webapp-config --type merge -p '{"data":{"APP_MODE":"staging"}}'
```

Within roughly 30 to 90 seconds (the exact timing depends on kubelet's sync period), the logs will flip to `ENV APP_MODE=production | FILE APP_MODE=staging`. The file value caught up, the env var did not. If you restart the pod, the env var would then pick up the new value because env injection happens fresh at container start.

Wait about two minutes, then kill the tail and examine the pod:

```bash
sleep 60
kill $LOGS_PID 2>/dev/null || true
kubectl logs --tail=5 demo-propagation
```

The last few lines should clearly show `ENV APP_MODE=production | FILE APP_MODE=staging`. Restore the original value and clean up:

```bash
kubectl patch configmap webapp-config --type merge -p '{"data":{"APP_MODE":"production"}}'
kubectl delete pod demo-propagation
```

A special case: volumes mounted with `subPath` do not receive updates even though they are technically volume mounts. This is because subPath mounts resolve the path once at container start and do not re-link when the ConfigMap changes. If you need live-updating file mounts, do not use `subPath`; use `items` with full directory mounts instead.

## Step 10: Downward API Volume

The downward API lets a container read information about its own pod (name, namespace, labels, annotations, resource requests, and so on) without having to query the API server. Downward API data can be exposed as environment variables or as files via a volume.

First, add a label and annotation to a demo pod so the downward API has something interesting to project. This step builds a standalone pod to illustrate the pattern; the full application pod in Step 11 integrates it into the real workflow.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: demo-downward
  namespace: tutorial-pod-config-injection
  labels:
    app: webapp
    tier: backend
    environment: production
  annotations:
    owner: platform-team
    deploy-id: "20260417-001"
spec:
  restartPolicy: Never
  containers:
    - name: shell
      image: busybox:1.36
      command: ["sh", "-c", "ls -la /etc/pod-metadata; echo '---'; cat /etc/pod-metadata/labels; echo '---'; cat /etc/pod-metadata/annotations; echo '---'; cat /etc/pod-metadata/name; sleep 3600"]
      volumeMounts:
        - name: metadata
          mountPath: /etc/pod-metadata
          readOnly: true
  volumes:
    - name: metadata
      downwardAPI:
        items:
          - path: name
            fieldRef:
              fieldPath: metadata.name
          - path: namespace
            fieldRef:
              fieldPath: metadata.namespace
          - path: labels
            fieldRef:
              fieldPath: metadata.labels
          - path: annotations
            fieldRef:
              fieldPath: metadata.annotations
EOF
```

The `downwardAPI` volume source takes a required `items` list. Each item has a `path` (the file name inside the volume, relative path, no leading slash) and a source field: `fieldRef` for simple pod metadata like name and namespace, or `resourceFieldRef` for container resource requests and limits. When you reference `metadata.labels` or `metadata.annotations`, the kubelet writes every label or annotation to the file in `key="value"` format, one per line.

Verify:

```bash
kubectl wait --for=condition=Ready pod/demo-downward --timeout=60s
kubectl logs demo-downward
```

Clean up:

```bash
kubectl delete pod demo-downward
```

## Step 11: Projected Volume Combining ConfigMap, Secret, and Downward API

A projected volume takes multiple sources (ConfigMaps, Secrets, downward API data, service account tokens) and combines them into a single volume mount. This is the pattern most production applications use: one mount point like `/etc/app` contains every piece of configuration the app needs to read, regardless of where the data came from in the cluster.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: webapp
  namespace: tutorial-pod-config-injection
  labels:
    app: webapp
    tier: backend
    environment: production
  annotations:
    owner: platform-team
    deploy-id: "20260417-001"
spec:
  restartPolicy: Never
  containers:
    - name: app
      image: busybox:1.36
      command:
        - sh
        - -c
        - |
          echo '=== Environment variables ==='
          env | grep -E '^(APP_|LOG_|FEATURE_|DATABASE_|DB_USER|DB_HOST|DB_NAME)=' | sort
          echo
          echo '=== /etc/app file listing ==='
          find /etc/app -type f | sort
          echo
          echo '=== app.properties ==='
          cat /etc/app/app.properties
          echo
          echo '=== DB_PASSWORD (from Secret) ==='
          cat /etc/app/secrets/DB_PASSWORD
          echo
          echo '=== Pod labels (from downward API) ==='
          cat /etc/app/pod/labels
          sleep 3600
      envFrom:
        - configMapRef:
            name: webapp-config
        - secretRef:
            name: webapp-db-creds
      env:
        - name: DATABASE_URL
          value: "postgres://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST)/$(DB_NAME)"
      volumeMounts:
        - name: app-config
          mountPath: /etc/app
          readOnly: true
  volumes:
    - name: app-config
      projected:
        defaultMode: 0440
        sources:
          - configMap:
              name: webapp-config
              items:
                - key: app.properties
                  path: app.properties
          - secret:
              name: webapp-db-creds
              items:
                - key: DB_USER
                  path: secrets/DB_USER
                - key: DB_PASSWORD
                  path: secrets/DB_PASSWORD
                  mode: 0400
                - key: DB_HOST
                  path: secrets/DB_HOST
                - key: DB_NAME
                  path: secrets/DB_NAME
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
                - path: pod/annotations
                  fieldRef:
                    fieldPath: metadata.annotations
EOF
```

This pod is the full workflow. Environment variables come from two sources: `envFrom` bulk-imports the entire ConfigMap and the entire Secret, and a single explicit `env` entry builds `DATABASE_URL` from the Secret values using the `$(VAR)` expansion syntax that Kubernetes supports in env values. The `$(VAR)` references resolve against other env vars already defined on the container (including ones imported via `envFrom`), so this works as long as the referenced variables are present.

The volume side uses a `projected` volume with three `sources`. The first source pulls just `app.properties` from the ConfigMap and places it at `/etc/app/app.properties`. The second source pulls all four keys from the Secret and puts them under `/etc/app/secrets/`, with `DB_PASSWORD` getting a tighter `0400` mode override. The third source uses downward API to write pod metadata under `/etc/app/pod/`. The `defaultMode: 0440` on the projected volume sets the baseline mode for every file; the per-item `mode: 0400` on `DB_PASSWORD` overrides it.

Wait for the pod to be ready and read the full output:

```bash
kubectl wait --for=condition=Ready pod/webapp --timeout=60s
kubectl logs webapp
```

You should see environment variables from both the ConfigMap and the Secret, plus `DATABASE_URL` with the substituted values. The file listing should show `app.properties`, four files under `secrets/`, and four files under `pod/`. Verify the tighter mode on `DB_PASSWORD`:

```bash
kubectl exec webapp -- ls -la /etc/app/secrets/
```

`DB_PASSWORD` should be mode `-r--------` (0400) while the other three files are mode `-r--r-----` (0440).

## Step 12: Optional References

By default, a pod that references a non-existent ConfigMap or Secret (or a missing key) fails to start with `CreateContainerConfigError`. Sometimes that is the right behavior, but for non-critical configuration you may want the pod to start anyway and simply skip the missing reference. The `optional: true` field enables that.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: demo-optional
  namespace: tutorial-pod-config-injection
spec:
  restartPolicy: Never
  containers:
    - name: shell
      image: busybox:1.36
      command: ["sh", "-c", "env | grep -E '^(MISSING_|PRESENT_)=' | sort; echo '---DONE---'; sleep 3600"]
      envFrom:
        - configMapRef:
            name: does-not-exist
            optional: true
      env:
        - name: PRESENT_APP_NAME
          valueFrom:
            configMapKeyRef:
              name: webapp-config
              key: APP_NAME
        - name: MISSING_THING
          valueFrom:
            configMapKeyRef:
              name: webapp-config
              key: NO_SUCH_KEY
              optional: true
EOF
```

Two `optional: true` fields are in play. The first on `envFrom.configMapRef` allows the pod to start even though `does-not-exist` is not in the cluster. The second on `configMapKeyRef` allows a missing key (`NO_SUCH_KEY`) to be silently skipped rather than failing the pod. Compare to the `PRESENT_APP_NAME` entry, which has no `optional` and must resolve.

Verify:

```bash
kubectl wait --for=condition=Ready pod/demo-optional --timeout=60s
kubectl logs demo-optional
```

You should see `PRESENT_APP_NAME=webapp` in the output. `MISSING_THING` is not there, because the optional reference was silently dropped. Clean up:

```bash
kubectl delete pod demo-optional
```

Now demonstrate what happens without `optional`. This pod will fail to start:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: demo-required-missing
  namespace: tutorial-pod-config-injection
spec:
  restartPolicy: Never
  containers:
    - name: shell
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      env:
        - name: MISSING_THING
          valueFrom:
            configMapKeyRef:
              name: does-not-exist
              key: anything
EOF
```

Check the status:

```bash
sleep 5
kubectl get pod demo-required-missing
kubectl describe pod demo-required-missing | grep -A5 Events
```

The pod status is `CreateContainerConfigError`, and the events include a message like `configmap "does-not-exist" not found`. This is the most common failure mode for configuration injection issues. Clean up:

```bash
kubectl delete pod demo-required-missing
```

## Step 13: Immutable ConfigMaps and Secrets

Setting `immutable: true` on a ConfigMap or Secret tells Kubernetes to reject any update after creation. This has two benefits: it prevents accidental changes from propagating to running pods (which can be critical for configuration that must stay consistent), and it reduces the load on the kubelet, which stops watching the object for changes.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-locked
  namespace: tutorial-pod-config-injection
immutable: true
data:
  RELEASE: "v1.2.3"
EOF
```

Try to update it:

```bash
kubectl patch configmap webapp-locked --type merge -p '{"data":{"RELEASE":"v1.2.4"}}'
```

The patch is rejected with an error about the immutable field. To change the value, you must delete and recreate the ConfigMap, which would require restarting any pods that reference it in a way that depends on the old value. Clean up:

```bash
kubectl delete configmap webapp-locked
```

## Step 14: Inspection Commands You Will Use Constantly

Most debugging of configuration injection issues comes down to three categories of inspection. First, look at the ConfigMap or Secret itself and verify the data is what you expect. Second, look at the pod and its events to see if Kubernetes is even trying to start the container. Third, look inside a running container to see what the injection actually produced.

For the ConfigMap and Secret:

```bash
kubectl get configmap webapp-config -o yaml
kubectl describe configmap webapp-config
kubectl get secret webapp-db-creds -o yaml
kubectl get secret webapp-db-creds -o jsonpath='{.data.DB_PASSWORD}' | base64 -d ; echo
```

For pod status and events:

```bash
kubectl get pod webapp -o wide
kubectl describe pod webapp
kubectl get events --field-selector involvedObject.name=webapp --sort-by=.lastTimestamp
```

For inside the running container:

```bash
kubectl exec webapp -- env | sort
kubectl exec webapp -- ls -la /etc/app
kubectl exec webapp -- cat /etc/app/app.properties
kubectl exec webapp -- cat /etc/app/secrets/DB_PASSWORD
```

Get comfortable with these. Under exam time pressure, knowing exactly which command to run to diagnose a specific failure is the difference between solving a problem in two minutes and solving it in ten.

## Step 15: Clean Up

Delete the entire tutorial namespace to remove everything at once:

```bash
kubectl delete namespace tutorial-pod-config-injection
kubectl config set-context --current --namespace=default
```

The second command resets your default namespace so you do not accidentally try to keep using the deleted one.

## Reference Commands

The following tables are quick references for the patterns this tutorial covered. Use them while working through the homework exercises.

### ConfigMap Creation

| Approach | Command |
|---|---|
| From literals (imperative) | `kubectl create configmap NAME --from-literal=KEY=VALUE --from-literal=KEY2=VALUE2` |
| From a file (imperative, key is filename) | `kubectl create configmap NAME --from-file=path/to/file` |
| From a file (imperative, custom key) | `kubectl create configmap NAME --from-file=KEY=path/to/file` |
| From a directory of files | `kubectl create configmap NAME --from-file=path/to/dir/` |
| From env-file format | `kubectl create configmap NAME --from-env-file=path/to/env.file` |
| Generate YAML without applying | Add `--dry-run=client -o yaml` to any of the above |
| Declarative | `data:` map in YAML with string values |

### Secret Creation

| Approach | Command |
|---|---|
| Generic from literals | `kubectl create secret generic NAME --from-literal=KEY=VALUE` |
| Generic from file | `kubectl create secret generic NAME --from-file=path/to/file` |
| TLS secret | `kubectl create secret tls NAME --cert=path/to/tls.crt --key=path/to/tls.key` |
| Docker registry | `kubectl create secret docker-registry NAME --docker-server=... --docker-username=... --docker-password=...` |
| Declarative with base64 | `data:` map in YAML with base64-encoded values |
| Declarative with plaintext | `stringData:` map in YAML (Kubernetes encodes for you) |

### Injection Patterns

| Pattern | YAML shape |
|---|---|
| Single env var from ConfigMap | `env: [{name: FOO, valueFrom: {configMapKeyRef: {name: cm, key: K}}}]` |
| Single env var from Secret | `env: [{name: FOO, valueFrom: {secretKeyRef: {name: s, key: K}}}]` |
| All keys as env vars from ConfigMap | `envFrom: [{configMapRef: {name: cm}}]` |
| All keys as env vars from Secret | `envFrom: [{secretRef: {name: s}}]` |
| Full ConfigMap as volume | `volumes: [{name: v, configMap: {name: cm}}]` |
| Full Secret as volume | `volumes: [{name: v, secret: {secretName: s}}]` |
| Selected keys as files (volume) | Add `items: [{key: K, path: p}]` under `configMap` or `secret` |
| Single file into existing dir | Add `subPath: K` to the `volumeMounts` entry |
| Multiple sources in one mount | Use `projected` volume source with `sources: [...]` |
| Pod metadata as files | Use `downwardAPI` volume source with `items: [{path, fieldRef}]` |

### base64 Encoding Reference

| Task | Command |
|---|---|
| Encode a string for Secret `data` | `echo -n 'value' \| base64 -w0` |
| Encode a file's contents | `base64 -w0 < path/to/file` |
| Decode a Secret value | `echo 'BASE64STR' \| base64 -d` |
| Extract and decode from a Secret | `kubectl get secret NAME -o jsonpath='{.data.KEY}' \| base64 -d` |

Always use `base64 -w0` for encoding rather than `base64 \| tr -d '\n'`. The `-w0` flag disables line wrapping in a single step, so there is no chance of embedded newlines slipping into your Secret values. If you ever see a long base64 value wrap to multiple lines in YAML you wrote by hand, you forgot `-w0`.

### Injection Pattern Decision Table

| Situation | Use |
|---|---|
| A few simple scalar settings, app reads env | `env` with `valueFrom.configMapKeyRef` or `secretKeyRef` |
| Many settings, app reads env, no naming conflicts | `envFrom` with `configMapRef` or `secretRef` |
| App expects a config file on disk | Volume mount (full or `items`) |
| Config file must land in an existing directory | `subPath` mount |
| Config must hot-reload when the source changes | Volume mount without `subPath` |
| Config must NEVER change while the pod runs | Env vars, or `immutable: true` on the source, or subPath |
| Multiple sources consolidated at one mount point | `projected` volume with multiple `sources` |
| Pod needs info about itself | Downward API (env or volume) |
| Secret file must have restricted permissions | Volume mount with `defaultMode: 0400` or per-item `mode` |
| Source might not exist and that is okay | Add `optional: true` |

This tutorial has walked through every pattern you will need for the homework. Move on to `pod-config-injection-homework.md` and work through the 15 exercises in order.
