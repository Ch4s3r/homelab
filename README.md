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

## GitHub webhook

Once the `argocd-webhook` ingress is live, add a webhook in the GitHub repo settings:

- **URL**: `https://argocd-webhook.bumblebee-themis.ts.net/api/webhook`
- **Content type**: `application/json`
- **Events**: `Push`

This triggers ArgoCD to sync immediately on every push instead of waiting for the 3-minute polling interval.
