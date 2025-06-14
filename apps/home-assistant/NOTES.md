# Home Assistant Configuration Notes

## Network Configuration

This deployment uses ClusterIP service by default to avoid port conflicts. Home Assistant is accessible through Tailscale ingress.

## Reverse Proxy Configuration

The deployment automatically configures Home Assistant to trust reverse proxies including:
- Kubernetes cluster CIDR (10.42.0.0/16)
- Common private networks
- Local IPs

If you see reverse proxy errors:
```bash
# Force restart the deployment to reload configuration
kubectl rollout restart deployment/home-assistant -n home-assistant

# Check the configuration was applied
kubectl exec -n home-assistant deployment/home-assistant -- cat /config/configuration.yaml | grep -A 10 "http:"
```

## Enabling Host Network (Optional)

If you need device discovery (mDNS) or have specific networking requirements, you can enable host networking by adding these lines to the deployment.yaml:

```yaml
spec:
  template:
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
```

⚠️ **Warning**: Host networking requires port 8123 to be available on the node. If another service is using this port, the pod will fail to schedule.

## Device Access

USB devices should work with privileged mode enabled. For specific devices, add volume mounts as needed.
