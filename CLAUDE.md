# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture

GitOps homelab on a Mac Mini M2 (ARM64) running **NixOS** (via [nixos-apple-silicon](https://github.com/nix-community/nixos-apple-silicon)) with **K3s** and **Flux**.

- `nixos/` — NixOS flake for the host (`nixosConfigurations.macmini`): hardware, disks (disko), K3s, Flux bootstrap, sops-nix
- `clusters/macmini/` — Flux entry point; one Flux `Kustomization` per app
- `apps/{app-name}/` — the app manifests a Flux `Kustomization` points to
- `todoapps/` — apps that are **not deployed** (Flux only deploys what `clusters/macmini/kustomization.yaml` lists; some todoapps are still in the old ArgoCD `helmCharts` + ksops format and need converting before they come back)

**Do not make changes directly with `kubectl`. All changes must go through Git** — Flux reconciles `main` automatically. Read-only `kubectl` (get, logs, describe) is fine.

Changes may be committed directly to `main`; there is no branch protection or CI lint gate. Run `devenv test` locally to lint kustomize apps before pushing.

## Host (NixOS)

Deploy host changes after pushing to `main` (sudo is passwordless for `wheel`):

```bash
ssh lampe@macmini "sudo nixos-rebuild switch --flake 'github:Ch4s3r/homelab?dir=nixos#macmini' --refresh"
```

- `nixpkgs` follows the input pinned by the `nixos-apple-silicon` release; newer nixpkgs can break the Asahi U-Boot/kernel build, and there is no binary cache for the Asahi kernel.
- K3s comes from `services.k3s` (`nixos/hosts/macmini/k3s.nix`); K3s versions are bumped there, not from inside the cluster.
- The K3s module converts manifests at evaluation time (IFD), so `nix eval` of the full system only works on the Mac Mini, not on macOS.
- See `nixos/README.md` for installation and deployment.

## Deploying / Modifying Apps

Standard layout:
```
apps/{app-name}/
├── kustomization.yaml   # namespace + resources
├── namespace.yaml
├── helmrepository.yaml  # if the app is a Helm chart
├── helmrelease.yaml     # if the app is a Helm chart
├── ingress.yaml         # ingressClassName: tailscale (or chart values)
├── secret.sops.yaml     # if the app needs secrets
└── pvc.yaml             # if persistence is needed
```

To deploy an app, add `clusters/macmini/{app-name}.yaml` and list it in `clusters/macmini/kustomization.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: {app-name}
  namespace: flux-system
spec:
  interval: 10m
  path: ./apps/{app-name}
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

## Helm charts

Helm charts are deployed with Flux `HelmRepository` (or `OCIRepository`) + `HelmRelease` inside the app directory. **Never create a `charts/` directory and do not use the kustomize `helmCharts` field** (Flux does not inflate it).

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: release-name
spec:
  interval: 30m
  chart:
    spec:
      chart: chart-name
      version: 1.0.0
      sourceRef:
        kind: HelmRepository
        name: repo-name
  values: {}
```

**Never use kustomize `patches:`.** Fix issues via Helm values or chart configuration instead.

## Ingress

All apps use Tailscale ingress:
```yaml
spec:
  ingressClassName: tailscale
  rules:
    - host: {app-name}
```
This makes the app reachable at `https://{app-name}.bagrid-scylla.ts.net/`.

## Secrets

**All sensitive values MUST be sops/age-encrypted — no exceptions.** This includes passwords, API keys, tokens, and usernames of managed accounts. The sops recipient is defined in `.sops.yaml`. **Never print, log or commit decrypted secret values.**

- **Cluster:** `apps/{app-name}/secret.sops.yaml` is an ordinary `kind: Secret` with `stringData:` values encrypted in place, listed under `resources:`. Flux decrypts it with the `flux-system/sops-age` Secret.
- **Host:** `nixos/secrets/*.sops.yaml`, read by sops-nix with the same age key at `/var/lib/sops-nix/key.txt` (the only secret kept outside Git). sops-nix also renders `flux-system/sops-age` into the K3s manifests folder.

Pods consume values through `envFrom`/`secretKeyRef` — **never interpolate them into HelmRelease values or inline manifests**, since those end up in plaintext in Helm release data or the Nix store.

Encrypt / edit:
```bash
nix shell nixpkgs#sops --command sops -e -i apps/{app-name}/secret.sops.yaml   # encrypt in place
nix shell nixpkgs#sops --command sops apps/{app-name}/secret.sops.yaml          # edit decrypted
```

**Charts that force secrets into values (rendered into ConfigMaps) are unavoidable leaks.** Before adopting such a chart, check whether all credentials can be wired through `existingSecret`-style references.

## Image versioning

**Always pin container images with both a semver tag and a sha256 digest** — `image:1.2.3@sha256:...`. Never use `latest` or undigested tags alone.

For images with no semver, use `latest@sha256:...`; Renovate keeps the digest current.

```bash
nix shell nixpkgs#crane --command crane digest <image>:<tag>
```

## Renovate

`renovate.json5` auto-merges stable non-major updates via squash commits. The `flux` manager tracks `HelmRelease` chart versions; image tags inside Helm values are tracked with an inline comment:
```yaml
# renovate: datasource=docker depName=ghcr.io/example/app versioning=semver
tag: v1.2.3
```

**Always verify Renovate detects a dependency after any version-related change.** Downgrade it temporarily and run a dry-run:

```bash
nix shell nixpkgs#renovate --command renovate --platform=local --dry-run=full 2>&1 | grep "branch"
```

The `Cannot sync git` warnings are normal for local platform mode.

## Cluster Details

- Single-node K3s, ARM64, 16K page size kernel
- Storage: K3s local-path provisioner on a Btrfs RAID1 of two Samsung 870 EVO (`/mnt/data`, declared with disko); K3s only starts when `/mnt/data` is mounted
- StorageClasses: `local-path` (default) and `retain-local-path` (`apps/global`)
- Backups: not automated yet (see the GitHub issue on daily backups)
