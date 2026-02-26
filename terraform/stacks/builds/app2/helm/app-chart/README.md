# Helm Chart for EKS Deployments

Minimal Helm chart for deploying applications to EKS cluster.

## Structure

```
helm/app-chart/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Default configuration values
└── templates/
    ├── deployment.yaml     # Kubernetes Deployment
    └── service.yaml        # Kubernetes Service (LoadBalancer)
```

## Usage

### Install the chart

```bash
# Connect to EKS cluster
aws eks update-kubeconfig --name myapp2-dev --region us-east-1

# Install chart
helm install my-app helm/app-chart

# Install with custom values
helm install my-app helm/app-chart --set replicaCount=3
```

### Upgrade deployment

```bash
helm upgrade my-app helm/app-chart
```

### Uninstall

```bash
helm uninstall my-app
```

### Customize values

Edit `values.yaml` or create environment-specific files:

```bash
# Create dev values
cp values.yaml values-dev.yaml

# Install with custom values file
helm install my-app helm/app-chart -f helm/app-chart/values-dev.yaml
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of pod replicas | `2` |
| `image.repository` | Container image repository | `nginx` |
| `image.tag` | Container image tag | `1.21` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `service.type` | Kubernetes service type | `LoadBalancer` |
| `service.port` | Service port | `80` |
| `resources.limits.cpu` | CPU limit | `200m` |
| `resources.limits.memory` | Memory limit | `256Mi` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |

## Next Steps

1. Replace `nginx` image with your application image
2. Add ConfigMaps/Secrets for application configuration
3. Add Ingress for advanced routing
4. Add HorizontalPodAutoscaler for auto-scaling
