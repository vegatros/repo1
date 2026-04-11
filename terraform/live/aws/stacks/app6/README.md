# App7 — EKS with Argo CD (GitOps)

This stack deploys an EKS cluster with [Argo CD](https://argo-cd.readthedocs.io/) for GitOps-based continuous delivery. Application deployments are defined as Argo CD `Application` CRDs that sync Helm charts from this repository to the cluster.

---

## Architecture Diagram

```mermaid
graph TB
    Internet((Internet)) --> ALB[AWS Load Balancer<br/>Optional Ingress]

    subgraph VPC ["VPC"]
        subgraph Public ["Public Subnets"]
            ALB
            NAT[NAT Gateway]
        end

        subgraph Private ["Private Subnets"]
            subgraph EKS ["EKS Cluster"]
                CP[Control Plane<br/>API + Audit Logging<br/>OIDC Provider]

                subgraph NodeGroup ["Managed Node Group"]
                    Node1[Worker Nodes<br/>t3.medium / t3.large]
                end

                subgraph ArgoCD ["Argo CD — argocd namespace"]
                    Server[Argo CD Server<br/>UI + API]
                    Repo[Repo Server<br/>Git Sync]
                    Controller[Application<br/>Controller]
                    Redis[Redis<br/>Cache]
                end

                subgraph Apps ["Application Namespaces"]
                    subgraph Dev ["app7-dev"]
                        DevApp[App Pods<br/>via Helm Chart]
                    end
                    subgraph QA ["app7-qa"]
                        QAApp[App Pods<br/>via Helm Chart]
                    end
                    subgraph Prod ["app7-prod"]
                        ProdApp[App Pods<br/>via Helm Chart]
                    end
                end
            end
        end
    end

    subgraph AWS ["AWS Services"]
        OIDC[OIDC Provider<br/>IRSA]
        IAM[IAM Roles<br/>Cluster + Node<br/>+ ArgoCD IRSA]
        S3State[(S3 State<br/>Bucket)]
        CW[CloudWatch<br/>Logs]
    end

    subgraph GitRepo ["Git Repository"]
        HelmChart[Helm Chart<br/>+ values-ENV.yaml]
        ArgoCDManifests[ArgoCD Application<br/>Manifests]
    end

    Server --> Repo
    Repo -->|Git Poll / Webhook| GitRepo
    Controller -->|Sync & Reconcile| Apps
    Controller -->|Reads| ArgoCDManifests

    ALB --> Server
    ALB --> DevApp & QAApp & ProdApp
    NAT -.-> Private

    CP -.->|IRSA| OIDC
    OIDC -.->|Assume Role| IAM
    CP -->|Audit + API Logs| CW

    style VPC fill:#e3f2fd
    style Public fill:#c8e6c9
    style Private fill:#ffccbc
    style EKS fill:#b39ddb
    style ArgoCD fill:#e1bee7
    style Apps fill:#90caf9
    style Dev fill:#a5d6a7
    style QA fill:#fff59d
    style Prod fill:#ef9a9a
    style AWS fill:#fff3e0
    style GitRepo fill:#e8eaf6
    style ALB fill:#2196f3,color:#fff
    style Server fill:#00897b,color:#fff
    style Controller fill:#00897b,color:#fff
```

---

## GitOps Workflow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant ArgoCD as Argo CD
    participant EKS as EKS Cluster

    Dev->>GH: Push code / Merge PR
    Note over GH: Helm chart or values updated

    ArgoCD->>GH: Poll for changes (3 min interval)
    GH-->>ArgoCD: Return latest commit

    ArgoCD->>ArgoCD: Detect drift (OutOfSync)
    ArgoCD->>ArgoCD: Render Helm template with values-ENV.yaml

    alt Auto-Sync Enabled (dev/qa)
        ArgoCD->>EKS: Apply manifests automatically
        EKS-->>ArgoCD: Resources reconciled
    else Manual Sync (prod option)
        ArgoCD->>ArgoCD: Wait for approval
        Dev->>ArgoCD: Click "Sync" in UI
        ArgoCD->>EKS: Apply manifests
        EKS-->>ArgoCD: Resources reconciled
    end

    ArgoCD->>ArgoCD: Health check (Synced + Healthy)
```

---

## Infrastructure Provisioning Flow

```mermaid
flowchart TD
    Start([Trigger terraform-app7 Workflow]) --> Select[Select Environment & Action]
    Select --> Auth[AWS OIDC Authentication]
    Auth --> Init[Terraform Init<br/>S3 Backend + S3 Native Lock]
    Init --> Scan[Trivy Security Scan]
    Scan --> Plan[Terraform Plan<br/>-var-file vars/ENV.tfvars]

    Plan --> Action{Action?}
    Action -->|plan| Done1([Plan Output])
    Action -->|apply| Apply[Terraform Apply]
    Action -->|destroy| Destroy[Terraform Destroy]

    Apply --> VPC[Create VPC<br/>Public + Private Subnets]
    VPC --> Cluster[Create EKS Cluster<br/>+ Node Group]
    Cluster --> Argo[Install Argo CD<br/>via Helm]
    Argo --> IRSA[Create IRSA Role<br/>for Argo CD]
    IRSA --> Done2([Stack Ready])

    Destroy --> Remove[Tear Down All Resources]
    Remove --> Done3([Destroyed])

    style Start fill:#4caf50
    style Done1 fill:#2196f3
    style Done2 fill:#4caf50
    style Done3 fill:#f44336
    style Argo fill:#9c27b0
    style Scan fill:#ff9800
```

---

## Directory Structure

```
terraform/stacks/app7/
├── main.tf                  # VPC + EKS module composition
├── argocd.tf                # Argo CD Helm release + IRSA role
├── variables.tf             # Input variables
├── outputs.tf               # Stack outputs
├── versions.tf              # Provider requirements
├── backend.tf               # S3 state backend
├── providers.tf             # Kubernetes + Helm provider config
├── vars/
│   ├── dev.tfvars           # Dev environment (10.7.0.0/16)
│   ├── qa.tfvars            # QA environment  (10.8.0.0/16)
│   └── prod.tfvars          # Prod environment (10.9.0.0/16)
├── argocd/
│   ├── application-dev.yaml   # ArgoCD Application CRD — dev
│   ├── application-qa.yaml    # ArgoCD Application CRD — qa
│   └── application-prod.yaml  # ArgoCD Application CRD — prod
└── helm/app-chart/
    ├── Chart.yaml
    ├── values.yaml            # Default values
    ├── values-dev.yaml        # Dev overrides
    ├── values-qa.yaml         # QA overrides
    ├── values-prod.yaml       # Prod overrides
    └── templates/
        ├── _helpers.tpl
        ├── deployment.yaml
        ├── service.yaml
        ├── ingress.yaml
        ├── serviceaccount.yaml
        ├── hpa.yaml
        ├── pdb.yaml
        ├── networkpolicy.yaml
        └── configmap.yaml
```

---

## Environment Configuration

| Parameter | Dev | QA | Prod |
|-----------|-----|-----|------|
| VPC CIDR | 10.7.0.0/16 | 10.8.0.0/16 | 10.9.0.0/16 |
| Instance Type | t3.medium | t3.medium | t3.large |
| Node Count | 1 | 1–3 | 2–5 |
| ArgoCD Replicas | 1 | 1 | 2 (HA) |
| Redis HA | No | No | Yes |
| Auto-Prune | Yes | Yes | No |
| Auto Self-Heal | Yes | Yes | Yes |
| HPA | Disabled | Disabled | Enabled (3–10) |
| PDB | Disabled | Enabled (min 1) | Enabled (min 2) |
| Network Policy | Disabled | Disabled | Enabled |

---

## Usage

### Deploy Infrastructure

```bash
# Initialize
cd terraform/stacks/app7
terraform init -reconfigure

# Plan
terraform plan -var-file="vars/dev.tfvars"

# Apply
terraform apply -var-file="vars/dev.tfvars"
```

### Configure kubectl

```bash
aws eks update-kubeconfig --name myapp7-dev --region us-east-1
```

### Access Argo CD UI

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward the server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open https://localhost:8080 (user: admin)
```

### Deploy Applications via Argo CD

```bash
# Apply the ArgoCD Application manifest
kubectl apply -f argocd/application-dev.yaml
```

### Destroy Infrastructure

```bash
terraform destroy -var-file="vars/dev.tfvars"
```

---

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- kubectl
- Helm (for local chart testing)
- S3 backend bucket (shared across stacks, using S3 native locking)
