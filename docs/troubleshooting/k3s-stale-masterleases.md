# Pods stuck crash-looping after a reboot, in-cluster API calls hang

**Symptom:** After a node reboot (or several), pods across the cluster — especially anything that talks to `kubernetes.default.svc` early in its startup, like the Tailscale operator's ingress-proxy sidecars — crash-loop with errors like:

```
error clearing previous state from Secret: ... Get "https://kubernetes.default.svc/...": context deadline exceeded
```

**Root cause:** The `kubernetes` Service's `Endpoints` object accumulates stale, dead IPs over time and never prunes them on this single-node setup:

```bash
kubectl get endpoints kubernetes -n default -o jsonpath='{.subsets[0].addresses}'
# e.g. [{"ip":"192.168.0.10"},{"ip":"192.168.0.26"},{"ip":"192.168.178.33"},{"ip":"2a04:..."}]
```

kube-proxy round-robins in-cluster API traffic across *all* listed addresses. Any dead one causes ~60s hangs for whichever pod's request lands on it — fatal for pods (like Tailscale's sidecars) that need that call to succeed within their startup window.

This is a known upstream Kubernetes bug ([kubernetes/kubernetes#114049](https://github.com/kubernetes/kubernetes/issues/114049)): the endpoint reconciler stores one "master lease" row per apiserver instance at the raw storage key `/registry/masterleases/<ip>` — a layer below anything `kubectl get lease` can see. On an ungraceful shutdown (any hard reboot without a clean drain), the apiserver can fail to remove its own row before exiting. On a multi-node/HA cluster a healthy peer prunes it later; on a **single-node cluster there is no peer to do that**, so it just sits there forever, surviving `kubectl` edits, `k3s` config changes, and full reboots — none of which touch this deeper storage layer.

**Fix** — stop k3s, delete the stale rows directly from its sqlite (kine) datastore, restart:

```bash
# 1. Inspect first — find the current correct IP vs stale ones
sudo sqlite3 /var/lib/rancher/k3s/server/db/state.db \
  "SELECT name, COUNT(*), MAX(id), MAX(deleted) FROM kine WHERE name LIKE '/registry/masterleases/%' GROUP BY name;"
# the live entry has many revisions (renewed every ~10s); stale ones have exactly 1 row, deleted=0

# 2. Stop k3s (full cluster outage until step 4 — keep it brief)
sudo systemctl stop k3s

# 3. Back up the datastore, then delete the stale rows (replace with the actual stale IPs found in step 1)
sudo cp /var/lib/rancher/k3s/server/db/state.db /var/lib/rancher/k3s/server/db/state.db.bak-$(date +%s)
sudo sqlite3 /var/lib/rancher/k3s/server/db/state.db \
  "DELETE FROM kine WHERE name IN ('/registry/masterleases/<stale-ip-1>', '/registry/masterleases/<stale-ip-2>');"

# 4. Restart
sudo systemctl start k3s
```

Verify: `kubectl get endpoints kubernetes -n default -o jsonpath='{.subsets[0].addresses}'` should show exactly one (or one per real node) address. Pods should stop crash-looping within a minute or two.

**Things that do *not* fix this** (all tried, all confirmed ineffective — they operate above the storage layer where the stale data actually lives): patching/replacing the `Endpoints` object via `kubectl` (reverts within seconds), pinning `--node-ip`/`--advertise-address` in `/etc/rancher/k3s/config.yaml`, forcing `--kube-apiserver-arg=endpoint-reconciler-type=lease`, deleting the `k3s-serving` secret + `dynamic-cert.json`, or a full node reboot.
