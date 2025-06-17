# Copilot Instructions for Homelab

## Infrastructure

- Running k3s on Mac Mini M2 with Asahi Linux
- ARM64 architecture considerations for container images
- Single-node cluster setup

## General Guidelines

- Always use Kustomization for Kubernetes resource management
- **NEVER use charts/ directories** - always use the helmCharts field in kustomization.yaml instead
- If Helm charts are needed, integrate them inside kustomization.yaml files using the helmCharts field
- Never create README.md or NOTES.md files
- Follow existing patterns from apps like home-assistant, vaultwarden, and karakeep

## Kubernetes Manifests Structure

Each app should follow this structure:
```
apps/{app-name}/
├── kustomization.yaml    # Main kustomization file (use helmCharts field for Helm)
├── namespace.yaml        # Kubernetes namespace
├── deployment.yaml       # Application deployment
├── service.yaml         # Service definition
├── ingress.yaml         # Tailscale ingress
├── configmap.yaml       # Configuration (if needed)
├── secret.yaml          # Secrets with dummy values (always create)
└── pvc.yaml            # Persistent volume claims (if needed)
```

**IMPORTANT**: Never create charts/ directories. Use helmCharts field in kustomization.yaml instead.

## Kustomization Standards

- Use `kustomization.yaml` as the main orchestration file
- Include all resources in the resources section
- **MANDATORY**: For Helm charts, use the helmCharts field in kustomization.yaml - NEVER create charts/ directories
- Always specify namespace in kustomization.yaml
- Remove any existing charts/ directories and convert them to helmCharts field

## Ingress Configuration

- Use Tailscale ingress class: `ingressClassName: tailscale`
- Follow the pattern: `{app-name}.ts.net` for external access
- Use simple host names without subdomains in rules

## Resource Naming

- Use consistent naming: `{app-name}-{resource-type}`
- Namespace should match the app name
- Labels should include `app: {app-name}`

## Security

- Use ConfigMaps for non-sensitive configuration
- Use Secrets for sensitive data (passwords, tokens, etc.)
- **ALWAYS create a secret.yaml file** with dummy values for all required secrets
- Secrets should use stringData field with placeholder values like "change-me" or "update-this-value"
- Always specify resource requests and limits
- Include health checks (livenessProbe, readinessProbe) when applicable

## Storage

- Use PersistentVolumeClaims for data that needs persistence
- Follow naming pattern: `{app-name}-data`, `{service-name}-data`
- Specify appropriate storage sizes based on app requirements

## Helm Integration

When Helm charts are required:
```yaml
# In kustomization.yaml
helmCharts:
- name: chart-name
  repo: https://chart-repo-url
  version: "1.0.0"
  releaseName: release-name
  namespace: app-namespace
  valuesFile: values.yaml
```

## Multi-Container Deployments

- Group related services in single deployments when they share lifecycle
- Use localhost networking between containers in the same pod
- Each container should have appropriate resource limits
- Use descriptive container names

## Environment Variables

- Reference ConfigMaps and Secrets using valueFrom
- Group related configuration in ConfigMaps
- Keep sensitive data in Secrets
- Use consistent naming for environment variables
