# Homelab

GitOps homelab running K3s on a Mac Mini M2 (Asahi Linux, ARM64). ArgoCD manages all apps declaratively from this repository.

## Tailscale ACL — Funnel setup

To allow ArgoCD to receive GitHub webhooks via Tailscale Funnel, the `funnel` attribute must be granted to the tag used by the Tailscale Kubernetes Operator proxies (`tag:k8s` by default).

Add the following to your tailnet ACL at https://login.tailscale.com/admin/acls:

```json
"nodeAttrs": [
  {
    "target": ["tag:k8s"],
    "attr":   ["funnel"]
  }
]
```

Without this, the `tailscale.com/funnel: "true"` annotation on the ingress will have no effect.

## Secrets (ksops + age)

Secrets are encrypted with [sops](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age) and decrypted at deploy time by [ksops](https://github.com/viaduct-ai/kustomize-sops) running in the ArgoCD repo-server.

The age private key is never committed to Git. Apply it once to bootstrap:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ksops-age-key
  namespace: argocd
stringData:
  keys.txt: |
    AGE-SECRET-KEY-<your-private-key>
EOF
```

To edit an encrypted secret:

```bash
sops apps/<app>/secret.sops.yaml
```

## GitHub webhook

Once the `argocd-webhook` ingress is live, add a webhook in the GitHub repo settings:

- **URL**: `https://argocd-webhook.bumblebee-themis.ts.net/api/webhook`
- **Content type**: `application/json`
- **Events**: `Push`

This triggers ArgoCD to sync immediately on every push instead of waiting for the 3-minute polling interval.

## Matter Server

Matter device support runs via `apps/matter-server/` (`ghcr.io/home-assistant-libs/python-matter-server`, official HA libs image). WebSocket on `:5580`.

After ArgoCD syncs, add the integration in HA:

- Settings → Devices & Services → Matter (discovered automatically) → URL `ws://127.0.0.1:5580/ws`

Requires OTBR running for Matter-over-Thread devices (see below).

## Thread / OpenThread Border Router (OTBR)

Thread support for Matter-over-Thread devices is provided by a standalone OTBR container (`apps/otbr/`). The Home Assistant Connect ZBT-2 is flashed with Thread RCP firmware and dedicated to Thread (no Zigbee on this radio).

**Before deploying**, update two values in `apps/otbr/deployment.yaml` with the actual values from the K3s node:

| Env var | How to find it |
|---|---|
| `OT_RCP_DEVICE` | `ls -l /dev/serial/by-id/` — use the `usb-Nabu_Casa_ZBT-2_*-if00` symlink |
| `OT_INFRA_IF` | `ip -o link show` — host LAN interface (typically `end0` on Asahi) |

**After ArgoCD syncs**, add the integration in Home Assistant:

1. Settings → Devices & Services → Add Integration → **OpenThread Border Router** → URL `http://127.0.0.1:8081`
2. Settings → Thread → set as preferred border router

Verify the OTBR REST API is live: `curl http://<node-ip>:8081/node`

## Backup schedules

All backup schedules (Velero `Schedule`, CNPG `ScheduledBackup`) use **UTC**. CNPG's admission webhook rejects `CRON_TZ=` prefixes, so we standardise on UTC across both stacks. Convert from local when editing: Vienna is UTC+2 (CEST) or UTC+1 (CET).
