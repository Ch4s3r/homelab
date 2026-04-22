# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture

ArgoCD-based GitOps homelab running K3s on a Mac Mini M2 (ARM64, Asahi Linux). An `ApplicationSet` in `apps/argocd/applicationset.yaml` auto-discovers every directory under `apps/` and deploys it as an ArgoCD Application with auto-sync, prune, and self-heal enabled.

**Do not make changes directly with `kubectl`. All changes must go through Git** — ArgoCD will reconcile them automatically once merged to `main`.

## Deploying / Modifying Apps

All apps live in `apps/{app-name}/`. The app name becomes both the ArgoCD application name and the Kubernetes namespace.

Standard layout:
```
apps/{app-name}/
├── kustomization.yaml   # orchestration; use helmCharts field for Helm (NEVER charts/ dirs)
├── namespace.yaml
├── ingress.yaml         # ingressClassName: tailscale
├── secret.yaml          # always present; dummy values ("change-me")
└── pvc.yaml             # if persistence is needed
```

To add a new app, create its directory under `apps/` — ArgoCD picks it up automatically.

WIP apps that should not be deployed yet live in `todoapps/`.

## Kustomize + Helm

Helm charts are embedded directly in `kustomization.yaml` via the `helmCharts` field. **Never create a `charts/` directory.**

```yaml
helmCharts:
  - name: chart-name
    repo: https://chart-repo-url
    version: "1.0.0"
    releaseName: release-name
    namespace: app-namespace   # REQUIRED: sets .Release.Namespace in helm template
    valuesFile: values.yaml   # or use valuesInline:
```

**Always set `namespace:` in every `helmCharts` entry** — without it, `.Release.Namespace` defaults to the ArgoCD repo-server namespace (`argocd`), causing charts that embed the namespace in job args, service DNS names, or RBAC rules to point at the wrong namespace. The top-level kustomization `namespace:` only patches `metadata.namespace` after rendering; it does not affect `.Release.Namespace` during Helm rendering.

ArgoCD is configured with `--enable-helm` so Kustomize can render Helm charts at sync time.

**Never use kustomize `patches:`.** Fix issues via Helm values (`valuesInline` or `valuesFile`) or chart configuration instead.

## Ingress

All apps use Tailscale ingress:
```yaml
spec:
  ingressClassName: tailscale
  rules:
    - host: {app-name}
```
This makes the app reachable at `https://{app-name}.bumblebee-themis.ts.net/`.

## Secrets

**All sensitive values MUST be sops/age-encrypted — no exceptions.** This includes passwords, API keys, tokens, and usernames of managed accounts (e.g. a service-generated `admin` user). The sops recipient is defined in `.sops.yaml`.

Standard layout per app:
```
apps/{app-name}/
├── secret.sops.yaml         # sops-encrypted Secret manifest
└── secret-generator.yaml    # ksops generator (mirrors apps/immich/)
```

`secret.sops.yaml` is an ordinary `kind: Secret` manifest with `stringData:` values that sops encrypts in place:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {app-name}-secret
  namespace: {app-name}
type: Opaque
stringData:
  FIELD_NAME: ENC[AES256_GCM,data:...,iv:...,tag:...,type:str]
```

Referenced by `secret-generator.yaml` and wired into the parent kustomization via `generators:`. Pods consume values through `envFrom`/`secretKeyRef` — **never interpolate them into `helmCharts` values files or inline manifests**, since those render to ConfigMaps/manifests in plaintext on disk.

Encrypt / edit:
```bash
nix shell nixpkgs#sops --command sops -e -i apps/{app-name}/secret.sops.yaml   # encrypt in place
nix shell nixpkgs#sops --command sops apps/{app-name}/secret.sops.yaml          # edit decrypted
```

ArgoCD's repo-server runs the ksops plugin to decrypt at sync time using the cluster-mounted age key.

**Charts that force secrets into values files (e.g. PrepArr's `.Values.*.config.apiKey` rendered into ConfigMaps) are unavoidable leaks.** Before adopting such a chart, check whether all credentials can be wired through `existingSecret`-style references.

## Renovate

`renovate.json5` auto-merges stable non-major updates via squash commits. To pin a version so Renovate tracks it, use an inline comment:
```yaml
# renovate: datasource=docker depName=ghcr.io/example/app versioning=semver
tag: v1.2.3
```

## CloudNative-PG CRD Upgrades

Helm does not upgrade CRDs automatically. `apps/cloudnative-pg/kustomization.yaml` references the full CRD set as a single Kustomize remote overlay:

```yaml
resources:
  - github.com/cloudnative-pg/cloudnative-pg/config/crd?ref=v1.28.0
```

`ServerSideApply=true` is set globally in `bootstrap/applicationset.yaml` for all apps, which avoids `kubectl apply` annotation size limit issues (especially relevant for large CRDs like CNPG's).

Renovate's built-in kustomize manager natively tracks `github.com/…?ref=version` URLs and auto-updates the `?ref=` when a new CNPG release is published. The Helm chart `version:` is tracked separately via a `# renovate:` comment using the existing comment-based manager. The two versions must stay in sync (chart `0.x.0` deploys operator `1.x.0`).

**Always verify Renovate detects a dependency after any version-related change** (adding a `# renovate:` comment, changing a tag, adding a new image/chart). Run a dry-run and grep for the expected branch name:

To verify Renovate detects a dependency before committing, downgrade it temporarily and run a dry-run:

```bash
nix shell nixpkgs#renovate --command renovate --platform=local --dry-run=full 2>&1 | grep "branch"
```

Expected output includes a branch name like `renovate/cloudnative-pg-0.x` (Helm chart) and `renovate/cloudnative-pg-cloudnative-pg-1.x` (CRD `?ref=`). The `Cannot sync git` warnings are normal for local platform mode.

## Cluster Details

- Single-node K3s, ARM64
- Storage: local-path provisioner; PVCs on Btrfs RAID1 at `/mnt/data`
- `KUBECONFIG` is set automatically via `.envrc` (direnv)
- Backups: Velero with MinIO
