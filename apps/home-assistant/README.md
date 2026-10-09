# Home Assistant

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

## Matter Server

Matter device support runs via `apps/matter-server/` (`ghcr.io/home-assistant-libs/python-matter-server`, official HA libs image). WebSocket on `:5580`.

After ArgoCD syncs, add the integration in HA:

- Settings → Devices & Services → Matter (discovered automatically) → URL `ws://127.0.0.1:5580/ws`

Requires OTBR running for Matter-over-Thread devices (see below).

## Shelly 1PM Gen4 auto button mode

A factory-reset Shelly 1PM Gen4 comes up with its input in Switch mode, and Matter can't change that. A Home Assistant package (`shelly-button-mode.yaml` in `apps/home-assistant/configmap.yaml`, copied to `/config/packages/` on pod start) fixes it automatically: when a new Shelly device is registered, it checks `Shelly.GetDeviceInfo` for model `S4SW-001P16EU`, then sets `Input.SetConfig type=button` and `Switch.SetConfig in_mode=momentary` over local RPC.

The device's IP comes from the **Shelly** integration (Settings → Devices & Services → Shelly, discovered automatically after the reset), so add it there in addition to Matter. A Matter-only device has no IP in HA and is ignored.

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

