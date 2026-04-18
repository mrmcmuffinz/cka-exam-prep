# Storage Tutorial: StorageClasses and Dynamic Provisioning

## Introduction

StorageClasses enable dynamic provisioning of PersistentVolumes. Instead of creating PVs manually, you define StorageClasses that describe different types of storage. When a PVC requests a StorageClass, the provisioner automatically creates a matching PV.

## Prerequisites

You need a running kind cluster:

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## Setup

```bash
kubectl create namespace tutorial-storage
kubectl config set-context --current --namespace=tutorial-storage
```

## Understanding StorageClasses

A StorageClass contains:

| Field | Description |
|-------|-------------|
| provisioner | Which provisioner creates PVs (e.g., kubernetes.io/aws-ebs) |
| parameters | Provisioner-specific settings |
| reclaimPolicy | Default reclaim policy for PVs (Delete or Retain) |
| allowVolumeExpansion | Whether PVCs can be resized |
| volumeBindingMode | Immediate or WaitForFirstConsumer |

## Listing StorageClasses

Kind includes a default StorageClass:

```bash
kubectl get storageclasses
kubectl get sc  # short name
```

Check which is default:

```bash
kubectl get sc -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}{"\n"}{end}'
```

## Dynamic Provisioning

Create a PVC without specifying storageClassName (uses default):

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-claim
  namespace: tutorial-storage
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
```

Check the result:

```bash
kubectl get pvc dynamic-claim
kubectl get pv
```

A PV was automatically created and bound.

## Creating a Custom StorageClass

```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: custom-local
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF
```

Use the custom class:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: custom-claim
  namespace: tutorial-storage
spec:
  storageClassName: custom-local
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
EOF
```

With WaitForFirstConsumer, the PVC stays Pending until a pod uses it:

```bash
kubectl get pvc custom-claim
# Status: Pending (waiting for consumer)
```

Create a pod:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: consumer-pod
  namespace: tutorial-storage
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: custom-claim
EOF
```

Now the PVC binds:

```bash
kubectl get pvc custom-claim
# Status: Bound
```

## Default StorageClass

The default is marked with annotation:

```yaml
metadata:
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
```

To change the default:

```bash
# Remove current default
kubectl patch sc <current-default> -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# Set new default
kubectl patch sc custom-local -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

## Volume Expansion

If allowVolumeExpansion is true, you can resize PVCs:

```bash
kubectl patch pvc dynamic-claim -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'
```

Note: The pod may need to be restarted for the filesystem to expand.

## Cleanup

```bash
kubectl delete namespace tutorial-storage
kubectl delete sc custom-local --ignore-not-found
```

## Key Takeaways

1. StorageClasses enable dynamic provisioning
2. The default StorageClass is used when none is specified
3. WaitForFirstConsumer delays binding until pod creation
4. allowVolumeExpansion enables PVC resizing
5. Different provisioners support different features
