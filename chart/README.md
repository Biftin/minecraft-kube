# Minecraft Server Helm Chart

This Helm chart deploys a Minecraft Fabric server on Kubernetes using a custom Docker image.

## Features

- **Minecraft Fabric Server**: Based on Minecraft 1.21.6 with Fabric 0.16.14
- **RCON Support**: Built-in RCON server for remote administration
- **Persistent Storage**: Configurable persistent volume for world data
- **Security**: Runs as non-root user with security contexts
- **Monitoring**: Readiness and liveness probes
- **Production Ready**: Includes resource limits and proper labeling
- **Single Instance**: Designed for single replica deployment (Minecraft servers are stateful)

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PV provisioner support in the underlying infrastructure (for persistent storage)

## Installing the Chart

### Quick Start

```bash
# Install with default values
helm install my-minecraft-server ./chart

# Install with custom values
helm install my-minecraft-server ./chart -f custom-values.yaml

# Install with inline overrides
helm install my-minecraft-server ./chart \
  --set minecraft.serverProperties.motd="Welcome to my server!" \
  --set minecraft.serverProperties.difficulty="hard" \
  --set resources.requests.memory="4Gi"
```

### Production Installation

```bash
# Create a custom values file
cat > production-values.yaml << EOF
resources:
  limits:
    cpu: 4000m
    memory: 8Gi
  requests:
    cpu: 2000m
    memory: 4Gi

persistence:
  size: 50Gi
  storageClass: "fast-ssd"

minecraft:
  serverProperties:
    motd: "My Production Minecraft Server"
    difficulty: "normal"
    max-players: 50
    spawn-protection: 32
    white-list: true
    online-mode: true

service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
EOF

# Install with production values
helm install minecraft-prod ./chart -f production-values.yaml
```

## Building Custom Images

This chart works with the included Docker image build system. To build custom versions:

```bash
# Build with default versions (1.21.6-fabric-0.16.14)
make build

# Build with custom Minecraft/Fabric versions
make build MINECRAFT_VERSION=1.21.4 FABRIC_VERSION=0.16.10

# Build and push multi-architecture images
make build-multi-arch MINECRAFT_VERSION=1.21.6 FABRIC_VERSION=0.16.14

# Update Helm chart appVersion to match build versions
make helm-update-versions

# Package Helm chart with updated versions
make helm-package
```

## Configuration

The following table lists the configurable parameters and their default values:

### Image Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Docker image repository | `ghcr.io/biftin/minecraft-kube` |
| `image.tag` | Docker image tag | `""` (uses Chart.appVersion) |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Kubernetes service type | `LoadBalancer` |
| `service.port` | Minecraft server port | `25565` |
| `service.annotations` | Service annotations | `{}` |

### RCON Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `rcon.enabled` | Enable RCON server | `true` |
| `rcon.port` | RCON port | `25575` |
| `rcon.password` | RCON password | `minecraft` |
| `rcon.service.enabled` | Create separate RCON service | `false` |

### Minecraft Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `minecraft.env` | Environment variables | `{}` |
| `minecraft.serverProperties` | Server properties to set | `{}` |

### Persistence Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.size` | PVC size | `10Gi` |
| `persistence.storageClass` | Storage class name | `""` |
| `persistence.accessModes` | Access modes | `["ReadWriteOnce"]` |

### Resource Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources.limits.cpu` | CPU limit | `2000m` |
| `resources.limits.memory` | Memory limit | `4Gi` |
| `resources.requests.cpu` | CPU request | `1000m` |
| `resources.requests.memory` | Memory request | `2Gi` |

### Security Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `securityContext.runAsUser` | User ID to run container | `1000` |
| `podSecurityContext.fsGroup` | File system group ID | `1000` |

### Probe Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `probes.readiness.enabled` | Enable readiness probe | `true` |
| `probes.liveness.enabled` | Enable liveness probe | `true` |

## Examples

### Basic Server Setup

```yaml
minecraft:
  serverProperties:
    motd: "Welcome to my Minecraft server!"
    difficulty: "normal"
    gamemode: "survival"
    max-players: 20
    spawn-protection: 16
    white-list: false
    online-mode: true
    pvp: true
```

### High Performance Setup

```yaml
resources:
  limits:
    cpu: 6000m
    memory: 12Gi
  requests:
    cpu: 3000m
    memory: 6Gi

minecraft:
  env:
    JAVA_FLAGS: "-Xmx8G -Xms4G -XX:+UseG1GC -XX:+ParallelRefProcEnabled"

persistence:
  size: 100Gi
  storageClass: "premium-ssd"
```

### Development Setup

```yaml
resources:
  limits:
    cpu: 1000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi

persistence:
  size: 5Gi

service:
  type: NodePort

minecraft:
  serverProperties:
    difficulty: "peaceful"
    gamemode: "creative"
    online-mode: false
```

## Architecture Notes

### Single Instance Design
This chart is specifically designed for single-instance deployments because:
- **Minecraft servers are stateful** - World data and player state must be consistent
- **No horizontal scaling** - Multiple replicas would cause data corruption
- **Persistent connections** - Players maintain TCP connections to a specific server instance

## Managing the Server

### Accessing Server Console

```bash
# Connect via RCON
kubectl exec -it deployment/my-minecraft-server -- rcon-cli -H localhost -P 25575 -p minecraft

# Example commands
kubectl exec -it deployment/my-minecraft-server -- rcon-cli -H localhost -P 25575 -p minecraft list
kubectl exec -it deployment/my-minecraft-server -- rcon-cli -H localhost -P 25575 -p minecraft "say Hello from admin!"
```

### Viewing Logs

```bash
# View current logs
kubectl logs deployment/my-minecraft-server

# Follow logs
kubectl logs -f deployment/my-minecraft-server
```

### Backing Up World Data

```bash
# Create a backup job
kubectl create job minecraft-backup --from=cronjob/minecraft-backup

# Manual backup (requires kubectl and access to PVC)
kubectl exec deployment/my-minecraft-server -- tar czf /tmp/world-backup.tar.gz -C /data world
kubectl cp my-minecraft-server-pod:/tmp/world-backup.tar.gz ./world-backup.tar.gz
```

## Upgrading

```bash
# Upgrade to new chart version
helm upgrade my-minecraft-server ./chart

# Upgrade with new values
helm upgrade my-minecraft-server ./chart -f new-values.yaml

# Check upgrade status
helm status my-minecraft-server
```

## Uninstalling

```bash
# Uninstall the release
helm uninstall my-minecraft-server

# Note: PVC will not be deleted automatically for data safety
# To delete PVC manually:
kubectl delete pvc my-minecraft-server-data
```

## Troubleshooting

### Common Issues

1. **Server won't start**: Check resource limits and memory allocation
2. **Players can't connect**: Verify service type and firewall rules
3. **World data lost**: Ensure persistence is enabled and PVC is created
4. **Performance issues**: Increase CPU/memory resources or optimize Java flags

### Debugging Commands

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=minecraft-server

# Check service endpoints
kubectl get endpoints

# Check PVC status
kubectl get pvc

# Describe pod for events
kubectl describe pod -l app.kubernetes.io/name=minecraft-server

# Check resource usage
kubectl top pod -l app.kubernetes.io/name=minecraft-server
```

## Security Considerations

- **Change the default RCON password** in production environments
- Use **network policies** to restrict access if needed
- Enable **whitelist** for public servers (`white-list: true`)
- Regular **backups** of world data
- Monitor **resource usage** and set appropriate limits
- Consider using **secrets** for sensitive server properties

## Troubleshooting

### Common Issues

1. **Server won't start**
   - Check resource limits and memory allocation
   - Verify persistent volume is available
   - Check logs: `kubectl logs deployment/my-minecraft-server`

2. **Players can't connect**
   - Verify service type and external IP
   - Check firewall rules on cluster nodes
   - Ensure LoadBalancer is provisioned correctly

3. **World data lost**
   - Ensure `persistence.enabled: true`
   - Verify PVC is created and bound
   - Check storage class is available

4. **Performance issues**
   - Increase CPU/memory resources
   - Optimize Java flags in `minecraft.env.JAVA_FLAGS`
   - Consider faster storage class

### Debugging Commands

```bash
# Check pod status and events
kubectl get pods -l app.kubernetes.io/name=minecraft-server
kubectl describe pod -l app.kubernetes.io/name=minecraft-server

# Check service and endpoints
kubectl get svc,endpoints

# Check PVC status
kubectl get pvc

# View logs
kubectl logs -f deployment/minecraft-server

# Test RCON connection
kubectl exec deployment/minecraft-server -- rcon-cli -H localhost -P 25575 -p minecraft list

# Check resource usage
kubectl top pod -l app.kubernetes.io/name=minecraft-server
```

### Version Management

The chart version and Docker image versions are managed together:

```bash
# Build specific versions
make build MINECRAFT_VERSION=1.21.4 FABRIC_VERSION=0.16.10

# This creates image tags like: ghcr.io/biftin/minecraft-kube:1.21.4-fabric-0.16.10

# Update chart appVersion to match
make helm-update-versions MINECRAFT_VERSION=1.21.4 FABRIC_VERSION=0.16.10

# Package chart with updated versions
make helm-package
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the chart with `helm lint chart/`
5. Test deployment with `helm install test-release chart/ --dry-run`
6. Submit a pull request
