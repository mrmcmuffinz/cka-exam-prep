# Cluster Lifecycle Homework: etcd Operations and High Availability

This homework contains 15 exercises covering etcd operations and HA concepts.

---

## Level 1: etcd Exploration

### Exercise 1.1

**Objective:** Locate the etcd static pod manifest and identify certificate paths.

**Setup:**
```bash
kubectl create namespace ex-1-1
```

**Task:** Find the etcd manifest, identify the certificate file paths used for authentication.

**Verification:**
```bash
nerdctl exec kind-control-plane cat /etc/kubernetes/manifests/etcd.yaml | grep -E "cert|key|ca" && echo "SUCCESS"
```

---

### Exercise 1.2

**Objective:** Connect to etcd and verify cluster health.

**Setup:**
```bash
kubectl create namespace ex-1-2
```

**Task:** Use etcdctl to check the health of the etcd endpoint.

**Verification:**
```bash
nerdctl exec kind-control-plane /bin/bash -c '
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
' && echo "SUCCESS"
```

---

### Exercise 1.3

**Objective:** List etcd cluster members.

**Setup:**
```bash
kubectl create namespace ex-1-3
```

**Task:** Use etcdctl to list all members of the etcd cluster.

**Verification:**
```bash
nerdctl exec kind-control-plane /bin/bash -c '
ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
' && echo "SUCCESS"
```

---

## Level 2: Backup Operations

### Exercise 2.1

**Objective:** Create an etcd snapshot backup.

**Setup:**
```bash
kubectl create namespace ex-2-1
kubectl create configmap backup-test --from-literal=key=value -n ex-2-1
```

**Task:** Create an etcd snapshot and save it to /tmp/etcd-snapshot-ex21.db inside the kind container.

**Verification:**
```bash
nerdctl exec kind-control-plane /bin/bash -c '
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-snapshot-ex21.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
' && echo "Backup: SUCCESS"
```

---

### Exercise 2.2

**Objective:** Verify backup integrity with snapshot status.

**Setup:**
```bash
kubectl create namespace ex-2-2
```

**Task:** Check the status of the backup created in Exercise 2.1 to verify it is valid.

**Verification:**
```bash
nerdctl exec kind-control-plane /bin/bash -c '
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-snapshot-ex21.db --write-out=table
' && echo "Verify: SUCCESS"
```

---

### Exercise 2.3

**Objective:** Document a backup procedure as a runbook.

**Setup:**
```bash
kubectl create namespace ex-2-3
```

**Task:** Create a runbook for regular etcd backups including: commands, verification, and storage recommendations.

**Verification:**
```bash
echo "Runbook should include: backup command, verification command, storage location, schedule recommendation" && echo "SUCCESS"
```

---

## Level 3: Debugging etcd Issues

### Exercise 3.1

**Objective:** Diagnose the etcd connection issue.

**Setup:**
```bash
kubectl create namespace ex-3-1
```

**Task:** The following etcdctl command fails. Identify what is wrong:
```bash
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/ca.crt \
  --cert=/etc/kubernetes/pki/apiserver.crt \
  --key=/etc/kubernetes/pki/apiserver.key
```

**Verification:**
```bash
echo "Issue: Using wrong certificates (API server certs instead of etcd certs)" && echo "SUCCESS"
```

---

### Exercise 3.2

**Objective:** Fix the endpoint configuration issue.

**Setup:**
```bash
kubectl create namespace ex-3-2
```

**Task:** The following command fails. Identify the issue:
```bash
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=http://127.0.0.1:2379
```

**Verification:**
```bash
echo "Issue: Using http instead of https, etcd requires TLS" && echo "SUCCESS"
```

---

### Exercise 3.3

**Objective:** Diagnose missing ETCDCTL_API variable.

**Setup:**
```bash
kubectl create namespace ex-3-3
```

**Task:** A command is returning errors about unknown flags. What is likely missing?

**Verification:**
```bash
echo "Issue: ETCDCTL_API=3 must be set for v3 commands" && echo "SUCCESS"
```

---

## Level 4: Restore Operations

### Exercise 4.1

**Objective:** Document the etcd restore workflow.

**Setup:**
```bash
kubectl create namespace ex-4-1
```

**Task:** Document the complete workflow for restoring etcd from a backup, including pre-restore steps, the restore command, and post-restore configuration.

**Verification:**
```bash
echo "Workflow should include: stop components, restore command with --data-dir, update manifest, restart" && echo "SUCCESS"
```

---

### Exercise 4.2

**Objective:** Understand restore implications.

**Setup:**
```bash
kubectl create namespace ex-4-2
```

**Task:** Document what happens during etcd restore: new cluster ID, member IDs, and why the --data-dir must be different.

**Verification:**
```bash
echo "Document: New cluster created, cannot restore to same directory, manifest update required" && echo "SUCCESS"
```

---

### Exercise 4.3

**Objective:** Create a restore runbook.

**Setup:**
```bash
kubectl create namespace ex-4-3
```

**Task:** Create a comprehensive runbook for disaster recovery including backup verification, restore, and cluster validation.

**Verification:**
```bash
echo "Runbook should cover: verify backup, stop API server, restore, update manifest, verify cluster" && echo "SUCCESS"
```

---

## Level 5: HA Concepts and Complex Scenarios

### Exercise 5.1

**Objective:** Design an HA cluster topology.

**Setup:**
```bash
kubectl create namespace ex-5-1
```

**Task:** Design a 5-node HA cluster (3 control plane, 2 workers) using stacked etcd. Document: node roles, etcd quorum, load balancer requirements.

**Verification:**
```bash
echo "Design should include: 3 CP nodes, stacked etcd quorum=2, load balancer for API, failure tolerance" && echo "SUCCESS"
```

---

### Exercise 5.2

**Objective:** Create a complete backup and restore runbook for production.

**Setup:**
```bash
kubectl create namespace ex-5-2
```

**Task:** Create a production-grade runbook covering: scheduled backups, off-site storage, restore testing, and verification procedures.

**Verification:**
```bash
echo "Runbook should be comprehensive with schedules, storage, testing, and verification" && echo "SUCCESS"
```

---

### Exercise 5.3

**Objective:** Plan disaster recovery scenarios.

**Setup:**
```bash
kubectl create namespace ex-5-3
```

**Task:** Document recovery procedures for:
1. Single etcd member failure in 3-node cluster
2. Complete etcd data loss
3. Control plane node failure

**Verification:**
```bash
echo "DR plan should cover: member recovery, full restore, node replacement" && echo "SUCCESS"
```

---

## Cleanup

```bash
kubectl delete namespace ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3
```

---

## Key Takeaways

1. **ETCDCTL_API=3** must be set for etcdctl v3 commands
2. **Certificate authentication** is required for etcd access
3. **Regular backups** are essential for disaster recovery
4. **Restore creates new cluster** with new cluster ID
5. **Quorum** requires (n+1)/2 members for n-node cluster
6. **HA topologies** provide fault tolerance
