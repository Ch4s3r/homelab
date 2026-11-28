# Homelab

GitOps homelab on a Mac Mini M2 (ARM64): **NixOS** (nixos-apple-silicon) runs **K3s**, and **Flux** deploys all apps from this repository.

| Path | What |
| --- | --- |
| `nixos/` | NixOS flake for the host (disks, K3s, Flux bootstrap, sops-nix) — see [nixos/README.md](nixos/README.md) |
| `clusters/macmini/` | Flux entry point: one Flux `Kustomization` per deployed app |
| `apps/` | Deployed apps |
| `todoapps/` | Apps that are not deployed |

## How it works

1. NixOS installs K3s and, through K3s's Helm controller, the [Flux Operator](https://fluxcd.control-plane.io/operator/) with a `FluxInstance` that syncs `clusters/macmini` from `main`.
2. sops-nix decrypts `nixos/secrets/macmini.sops.yaml` with the age key at `/var/lib/sops-nix/key.txt` and writes the `flux-system/sops-age` Secret, so Flux can decrypt `apps/*/secret.sops.yaml`.
3. Every push to `main` is reconciled by Flux; host changes are applied with `nixos-rebuild` (see [nixos/README.md](nixos/README.md)).

## Adding an app

1. Create `apps/<app>/` (namespace, manifests or `HelmRepository` + `HelmRelease`, `secret.sops.yaml` if needed).
2. Add `clusters/macmini/<app>.yaml` (a Flux `Kustomization` pointing at `./apps/<app>` with SOPS decryption) and list it in `clusters/macmini/kustomization.yaml`.

## Secrets

Secrets are encrypted with [sops](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age); the recipient is in `.sops.yaml`. The age private key is never committed: it lives on the host at `/var/lib/sops-nix/key.txt` and in an offline backup.

```bash
nix shell nixpkgs#sops --command sops apps/<app>/secret.sops.yaml
```

## Tailscale ACL — Funnel setup

To allow Tailscale Funnel on an ingress (`tailscale.com/funnel: "true"`), the `funnel` attribute must be granted to the tag used by the Tailscale Kubernetes Operator proxies (`tag:k8s` by default) at https://login.tailscale.com/admin/acls:

```json
"nodeAttrs": [
  {
    "target": ["tag:k8s"],
    "attr":   ["funnel"]
  }
]
```
