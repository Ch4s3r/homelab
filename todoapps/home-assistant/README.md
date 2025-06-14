# Home Assistant Homelab Deployment

This directory contains the Kubernetes configuration for deploying Home Assistant in your homelab using the official Docker image.

## Overview

Home Assistant is an open-source home automation platform that puts local control and privacy first. This deployment uses the official `ghcr.io/home-assistant/home-assistant:stable` Docker image with all the necessary configurations for a homelab environment.

## Configuration

### Official Docker Setup

This deployment replicates the official Docker setup:
```bash
docker run -d \
  --name homeassistant \
  --privileged \
  --restart=unless-stopped \
  -e TZ=MY_TIME_ZONE \
  -v /PATH_TO_YOUR_CONFIG:/config \
  -v /run/dbus:/run/dbus:ro \
  --network=host \
  ghcr.io/home-assistant/home-assistant:stable
```

### Key Features

- **Official Image**: Uses `ghcr.io/home-assistant/home-assistant:stable`
- **Privileged Mode**: Enabled for full device access
- **Host Network**: Enabled for device discovery and communication
- **Persistent Storage**: 10GB using `retain-local-path` storage class
- **D-Bus Access**: Mounted for system integration
- **Timezone Support**: Configurable timezone (default: Europe/Berlin)

### Storage

The deployment creates a 10GB persistent volume mounted at `/config` containing:
- `configuration.yaml` - Main Home Assistant configuration
- `automations.yaml` - Automation rules
- `scripts.yaml` - Custom scripts
- `scenes.yaml` - Scene definitions
- `home-assistant_v2.db` - SQLite database
- Custom integrations and add-ons

### Network Access

- **Internal**: Available at `home-assistant.home-assistant.svc.cluster.local:8123`
- **External**: Available at `https://home-assistant` through Tailscale ingress
- **Host Network**: Enabled for device discovery and mDNS

## Device Access

This deployment is configured for full device access:

- **Privileged Mode**: Enabled for USB device access
- **Host Network**: Enabled for network discovery
- **D-Bus**: Mounted for system service communication

Common devices that work out of the box:
- Zigbee coordinators (ConBee, SkyConnect, etc.)
- Z-Wave controllers
- Bluetooth adapters
- Network devices via mDNS

## Initial Setup

1. **Access Home Assistant**: Navigate to `https://home-assistant`
2. **Create Account**: Set up your initial user account
3. **Configure Location**: Set your location and timezone
4. **Add Integrations**: Configure your smart home devices
5. **Create Automations**: Set up automated behaviors

## Configuration Customization

### Timezone

Edit the `TZ` environment variable in `deployment.yaml`:
```yaml
env:
- name: TZ
  value: "America/New_York"  # Change to your timezone
```

### Resource Limits

Adjust CPU and memory limits in `deployment.yaml`:
```yaml
resources:
  limits:
    cpu: "4"      # Increase for better performance
    memory: "4Gi" # Increase if using many integrations
```

### Additional USB Devices

If you need specific USB device access, add additional volume mounts:
```yaml
volumeMounts:
- name: zigbee-device
  mountPath: /dev/ttyACM0

volumes:
- name: zigbee-device
  hostPath:
    path: /dev/serial/by-id/your-device-id
    type: CharDevice
```

## Common Integrations

Popular integrations for homelab environments:

- **MQTT**: Connect IoT devices via MQTT broker
- **ESPHome**: Control ESP32/ESP8266 devices
- **Zigbee Home Automation**: Zigbee device control
- **Z-Wave**: Z-Wave device integration
- **Prometheus**: Export metrics for monitoring
- **Node-RED**: Visual automation flows
- **InfluxDB**: Time-series data storage

## Backup

Important to backup the entire `/config` directory containing:
- All configuration files
- SQLite database
- Custom integrations
- Automation history

The persistent volume uses `retain-local-path` storage class to prevent accidental data loss.

## Troubleshooting

### Common Issues

1. **Pod CrashLoopBackOff**
   - Check if PVC is properly mounted
   - Verify timezone is valid
   - Check pod logs: `kubectl logs -n home-assistant deployment/home-assistant`

2. **Device Discovery Not Working**
   - Verify `hostNetwork: true` is enabled
   - Check if devices are accessible on the host
   - Ensure privileged mode is enabled

3. **USB Device Access Issues**
   - Verify device path exists on host
   - Check device permissions
   - Add specific volume mounts for devices

4. **Network Integration Problems**
   - Confirm host network is enabled
   - Check firewall rules on nodes
   - Verify mDNS is working

### Useful Commands

```bash
# Check pod status
kubectl get pods -n home-assistant

# View logs
kubectl logs -n home-assistant deployment/home-assistant -f

# Exec into pod
kubectl exec -n home-assistant deployment/home-assistant -it -- /bin/bash

# Check persistent volume
kubectl get pvc -n home-assistant

# Restart deployment
kubectl rollout restart deployment/home-assistant -n home-assistant
```

## Updates

Home Assistant automatically updates to the latest stable version on pod restart due to `imagePullPolicy: Always`. To update:

1. Restart the deployment: `kubectl rollout restart deployment/home-assistant -n home-assistant`
2. Or let ArgoCD handle updates automatically

## Security Considerations

- **Privileged Mode**: Required for device access but increases security risk
- **Host Network**: Necessary for discovery but exposes more network surface
- **Root User**: Running as root for device access
- **Tailscale**: Provides secure external access without exposing to internet

## Resources

- [Home Assistant Documentation](https://www.home-assistant.io/docs/)
- [Home Assistant Installation Guide](https://www.home-assistant.io/installation/)
- [Container Installation](https://www.home-assistant.io/installation/generic-x86-64#docker-compose)
- [Home Assistant Community](https://community.home-assistant.io/)
