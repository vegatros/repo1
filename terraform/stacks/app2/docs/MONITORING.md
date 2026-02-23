# Monitoring EC2 Configuration

This document describes the Prometheus and Grafana setup on the monitoring EC2 instance.

## Access Information

- **Grafana URL**: http://<ELASTIC_IP>:3000
- **Prometheus URL**: http://<ELASTIC_IP>:9090
- **Username**: admin
- **Password**: admin123

## Architecture

```
┌─────────────────────────────────────────┐
│         EKS Cluster                     │
│  ┌──────────────────────────────┐      │
│  │  Prometheus (in-cluster)     │      │
│  │  - Scrapes all pods/nodes    │      │
│  │  - Exposed via LoadBalancer  │      │
│  └──────────────────────────────┘      │
└─────────────────┬───────────────────────┘
                  │
                  │ Port 9090
                  │
┌─────────────────▼───────────────────────┐
│    Monitoring EC2 Instance              │
│  ┌──────────────────────────────┐      │
│  │  Grafana (Docker)            │      │
│  │  - Queries EKS Prometheus    │      │
│  │  - Displays dashboards       │      │
│  │  Port: 3000                  │      │
│  └──────────────────────────────┘      │
│  ┌──────────────────────────────┐      │
│  │  Prometheus (Docker)         │      │
│  │  - Local metrics             │      │
│  │  Port: 9090                  │      │
│  └──────────────────────────────┘      │
└─────────────────────────────────────────┘
```

## Grafana Data Sources

### EKS-Prometheus
- **Type**: Prometheus
- **URL**: http://<EKS_PROMETHEUS_LB>:9090
- **Access**: Proxy
- **Default**: Yes

## Available Dashboards

### EKS Cluster Overview
Custom dashboard showing:
- Cluster status (node count)
- Total pod count
- CPU usage by pod (time series)
- Memory usage by pod (time series)
- Network traffic (RX/TX)

**Dashboard UID**: 802e6ed1-27fd-4144-b218-5bc5d3a97411

## Configuration Files

### Docker Compose
Location: `/home/ec2-user/docker-compose.yml`

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_INSTALL_PLUGINS=grafana-clock-panel
    volumes:
      - grafana-data:/var/lib/grafana
    restart: unless-stopped

volumes:
  prometheus-data:
  grafana-data:
```

### Prometheus Configuration
Location: `/home/ec2-user/prometheus.yml`

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'eks-prometheus'
    static_configs:
      - targets: ['<EKS_PROMETHEUS_LB>:9090']
    honor_labels: true
    metrics_path: '/metrics'
```

## Management Commands

### SSH Access
```bash
# Via EC2 Instance Connect
aws ec2-instance-connect ssh --instance-id <INSTANCE_ID> --region us-east-1

# Via SSM Session Manager
aws ssm start-session --target <INSTANCE_ID> --region us-east-1
```

### Docker Commands
```bash
# View running containers
docker ps

# View logs
docker logs grafana
docker logs prometheus

# Restart services
cd /home/ec2-user
docker-compose restart

# Stop services
docker-compose down

# Start services
docker-compose up -d
```

### Update Prometheus Configuration
```bash
# Edit config
sudo vi /home/ec2-user/prometheus.yml

# Restart Prometheus
docker restart prometheus
```

## Grafana API Examples

### Add Data Source
```bash
curl -X POST http://<IP>:3000/api/datasources \
  -H "Content-Type: application/json" \
  -u admin:admin123 \
  -d '{
    "name": "My-Prometheus",
    "type": "prometheus",
    "url": "http://prometheus:9090",
    "access": "proxy",
    "isDefault": true
  }'
```

### Import Dashboard
```bash
curl -X POST http://<IP>:3000/api/dashboards/import \
  -H "Content-Type: application/json" \
  -u admin:admin123 \
  -d '{
    "dashboard": {...},
    "overwrite": true
  }'
```

## Security

- **Security Group**: Allows ports 22, 3000, 9090 from 0.0.0.0/0
- **IAM Role**: Attached with SSM and AMP permissions
- **IMDSv2**: Enforced
- **EBS Encryption**: Enabled

## Troubleshooting

### Grafana not accessible
```bash
# Check if container is running
docker ps | grep grafana

# Check logs
docker logs grafana

# Restart
docker restart grafana
```

### No data in dashboards
```bash
# Test Prometheus connectivity
curl http://<EKS_PROMETHEUS_LB>:9090/api/v1/query?query=up

# Check Grafana data source
# Go to Configuration → Data Sources → Test
```

### Update EKS Prometheus endpoint
```bash
# Get new LoadBalancer DNS
kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus

# Update Grafana data source via API or UI
```

## Backup

### Grafana Dashboards
```bash
# Export all dashboards
docker exec grafana grafana-cli admin export-dashboards /var/lib/grafana/dashboards

# Copy to local
docker cp grafana:/var/lib/grafana/dashboards ./grafana-backup/
```

### Prometheus Data
```bash
# Backup volume
docker run --rm -v prometheus-data:/data -v $(pwd):/backup alpine tar czf /backup/prometheus-backup.tar.gz /data
```
