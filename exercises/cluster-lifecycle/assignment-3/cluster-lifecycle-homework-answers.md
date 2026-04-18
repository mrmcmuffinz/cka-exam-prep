# Cluster Lifecycle Homework Answers: etcd Operations and High Availability

Complete solutions for all 15 exercises.

---

## Exercise 1.1 Solution

```bash
nerdctl exec kind-control-plane cat /etc/kubernetes/manifests/etcd.yaml | grep -E "cert|key|ca"
```

**Key certificate paths:**
- `--cert-file=/etc/kubernetes/pki/etcd/server.crt`
- `--key-file=/etc/kubernetes/pki/etcd/server.key`
- `--trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt`
- `--peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt`
- `--peer-key-file=/etc/kubernetes/pki/etcd/peer.key`
- `--peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt`

---

## Exercise 1.2 Solution

```bash
nerdctl exec kind-control-plane /bin/bash -c '
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
'
```

Expected output: `https://127.0.0.1:2379 is healthy: successfully committed proposal`

---

## Exercise 1.3 Solution

```bash
nerdctl exec kind-control-plane /bin/bash -c '
ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
'
```

Shows single member in kind cluster with ID, name, peer URLs, and client URLs.

---

## Exercise 2.1 Solution

```bash
nerdctl exec kind-control-plane /bin/bash -c '
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-snapshot-ex21.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
'
```

---

## Exercise 2.2 Solution

```bash
nerdctl exec kind-control-plane /bin/bash -c '
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-snapshot-ex21.db --write-out=table
'
```

Shows: hash, revision, total keys, total size.

---

## Exercise 2.3 Solution

**Backup Runbook:**

```markdown
# etcd Backup Runbook

## Daily Backup Command
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-$(date +%Y%m%d).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

## Verification
ETCDCTL_API=3 etcdctl snapshot status /backup/etcd-$(date +%Y%m%d).db

## Storage
- Copy to off-cluster storage (S3, GCS, NFS)
- Retain last 7 daily, 4 weekly, 12 monthly
- Encrypt at rest

## Schedule
- Daily at 02:00 UTC
- Before any cluster upgrade
- Before any major configuration change
```

---

## Exercise 3.1 Solution

**Issue:** Wrong certificate files.

The command uses `/etc/kubernetes/pki/ca.crt` and API server certificates. etcd requires its own certificates from `/etc/kubernetes/pki/etcd/`.

**Fix:** Use:
- `--cacert=/etc/kubernetes/pki/etcd/ca.crt`
- `--cert=/etc/kubernetes/pki/etcd/server.crt`
- `--key=/etc/kubernetes/pki/etcd/server.key`

---

## Exercise 3.2 Solution

**Issue:** Using http instead of https.

etcd in Kubernetes always uses TLS. The endpoint must be `https://127.0.0.1:2379`, not `http://`.

---

## Exercise 3.3 Solution

**Issue:** Missing ETCDCTL_API=3.

etcdctl defaults to v2 API. For snapshot commands and v3 features, set `ETCDCTL_API=3`.

---

## Exercise 4.1 Solution

**Restore Workflow:**

```markdown
# etcd Restore Workflow

## 1. Pre-restore
- Stop kube-apiserver (move manifest)
mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/

## 2. Restore
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-backup.db \
  --data-dir=/var/lib/etcd-new

## 3. Update etcd manifest
# Edit /etc/kubernetes/manifests/etcd.yaml
# Change hostPath for etcd-data volume:
#   path: /var/lib/etcd-new

## 4. Restart etcd
# Kubelet will restart etcd with new data directory

## 5. Restore API server
mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/

## 6. Verify
kubectl get nodes
kubectl get pods --all-namespaces
```

---

## Exercise 4.2 Solution

**Restore Implications:**

1. **New cluster created:** Restore creates a new etcd cluster with new cluster ID
2. **Member IDs change:** All member IDs are regenerated
3. **Different data directory required:** Cannot restore to same directory because:
   - Existing cluster would interfere
   - Prevents accidental data corruption
   - Allows rollback if restore fails
4. **Manifest update required:** etcd must be configured to use new data directory
5. **Single-member restoration:** Even in HA cluster, restore to single member first

---

## Exercise 4.3 Solution

**Disaster Recovery Runbook:**

```markdown
# Disaster Recovery Runbook

## 1. Verify Backup
ETCDCTL_API=3 etcdctl snapshot status /backup/latest.db

## 2. Stop Control Plane
mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/
mv /etc/kubernetes/manifests/kube-controller-manager.yaml /tmp/
mv /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/

## 3. Restore etcd
ETCDCTL_API=3 etcdctl snapshot restore /backup/latest.db \
  --data-dir=/var/lib/etcd-restored

## 4. Update etcd Manifest
# Change data directory to /var/lib/etcd-restored

## 5. Wait for etcd
crictl ps | grep etcd

## 6. Restore Control Plane
mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/
mv /tmp/kube-controller-manager.yaml /etc/kubernetes/manifests/
mv /tmp/kube-scheduler.yaml /etc/kubernetes/manifests/

## 7. Verify
kubectl get nodes
kubectl get pods --all-namespaces
kubectl get pv
```

---

## Exercise 5.1 Solution

**HA Cluster Design:**

```markdown
# 5-Node HA Cluster Design

## Topology
- 3 Control Plane nodes (stacked etcd)
- 2 Worker nodes

## etcd Configuration
- 3-member etcd cluster
- Quorum requirement: 2 members
- Can tolerate 1 member failure

## Load Balancer
- Required for API server HA
- Backends: all 3 control plane nodes port 6443
- Health checks on /healthz

## Failure Tolerance
- 1 control plane failure: Cluster continues
- 1 etcd failure: Cluster continues
- 2 etcd failures: Cluster read-only
- All etcd failures: Cluster down

## kubeadm Configuration
kubeadm init --control-plane-endpoint=<load-balancer-ip>:6443 \
  --upload-certs

## Adding Control Plane Nodes
kubeadm join <load-balancer>:6443 --control-plane \
  --certificate-key <key>
```

---

## Exercise 5.2 Solution

**Production Backup/Restore Runbook:**

```markdown
# Production etcd Operations

## Scheduled Backups
- Frequency: Every 4 hours
- Retention: 48 hourly, 30 daily
- Storage: Encrypted S3 bucket

## Backup Script
#!/bin/bash
BACKUP_DIR=/var/backup/etcd
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE=${BACKUP_DIR}/etcd-${DATE}.db

ETCDCTL_API=3 etcdctl snapshot save ${BACKUP_FILE} ...
ETCDCTL_API=3 etcdctl snapshot status ${BACKUP_FILE}
aws s3 cp ${BACKUP_FILE} s3://backup-bucket/etcd/

## Restore Testing
- Monthly restore test to staging
- Verify data integrity
- Document restoration time

## Verification Procedures
Post-restore checks:
1. All nodes Ready
2. All system pods Running
3. Application deployments healthy
4. PVCs bound
5. Secrets accessible
```

---

## Exercise 5.3 Solution

**Disaster Recovery Scenarios:**

```markdown
# DR Scenarios

## Scenario 1: Single etcd Member Failure (3-node cluster)

Impact: Cluster continues operating
Recovery:
1. Remove failed member: etcdctl member remove <id>
2. Fix/replace node
3. Add new member: etcdctl member add
4. Join node to cluster

## Scenario 2: Complete etcd Data Loss

Impact: Cluster non-functional
Recovery:
1. Stop all control plane components
2. Restore etcd from latest backup
3. Update etcd manifests on all nodes
4. Start control plane
5. Verify cluster state
6. Re-create any resources created after backup

## Scenario 3: Control Plane Node Failure

Impact: Reduced capacity, still functional
Recovery:
1. Provision new node
2. Install prerequisites
3. kubeadm join --control-plane
4. Verify new member joined etcd
5. Update load balancer if needed
```

---

## Common Mistakes

1. **Wrong certificate paths:** etcd uses its own CA, not the cluster CA
2. **Forgetting ETCDCTL_API=3:** Required for snapshot commands
3. **Using http instead of https:** etcd requires TLS
4. **Restoring to same data directory:** Creates conflicts
5. **Not updating static pod manifest after restore:** etcd uses old data
6. **Skipping verification:** Always verify backup integrity

---

## etcdctl Commands Cheat Sheet

```bash
# Environment
export ETCDCTL_API=3
export ETCD_CERTS="--cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key"
export ETCD_ENDPOINTS="--endpoints=https://127.0.0.1:2379"

# Commands
etcdctl endpoint health $ETCD_ENDPOINTS $ETCD_CERTS
etcdctl endpoint status $ETCD_ENDPOINTS $ETCD_CERTS
etcdctl member list $ETCD_ENDPOINTS $ETCD_CERTS
etcdctl snapshot save <file> $ETCD_ENDPOINTS $ETCD_CERTS
etcdctl snapshot status <file>
etcdctl snapshot restore <file> --data-dir=<new-dir>
```
