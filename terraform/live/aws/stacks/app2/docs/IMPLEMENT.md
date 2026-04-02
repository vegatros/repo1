# App2 EKS Full Overhaul: Private Subnets, IRSA, Linkerd, Helm

## Context

The app2 EKS stack is a working skeleton with critical gaps: nodes deploy into **empty** private subnets (the VPC module never receives `private_subnet_cidrs`), there's no IRSA for pod-level AWS access, the Helm chart only has a basic Deployment + LoadBalancer Service, and there's no service mesh or ingress controller. This plan fixes the infrastructure foundation and layers in Linkerd (free, CNCF graduated) and NGINX Ingress Controller, all managed via Terraform Helm provider.

---

## Phase 1: Fix Infrastructure Foundation

**Files modified:**
- `terraform/modules/eks/main.tf` — Add OIDC provider for IRSA, cluster logging, CloudWatch node policy
- `terraform/modules/eks/variables.tf` — Add `enable_irsa`, `enable_cluster_logging`, `cluster_log_types`
- `terraform/modules/eks/outputs.tf` — Add `oidc_provider_arn`, `oidc_provider_url`
- `terraform/stacks/app2/main.tf` — Pass `private_subnet_cidrs`, `enable_irsa=true`, `enable_cluster_logging=true`
- `terraform/stacks/app2/variables.tf` — Add `private_subnet_cidrs` variable
- `terraform/stacks/app2/outputs.tf` — Add `oidc_provider_arn` output
- `terraform/stacks/app2/dev.tfvars` — Add `private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]`
- `terraform/stacks/app2/qa.tfvars` — Add `private_subnet_cidrs = ["10.2.10.0/24", "10.2.11.0/24"]`
- `terraform/stacks/app2/prod.tfvars` — Add `private_subnet_cidrs = ["10.3.10.0/24", "10.3.11.0/24"]`

### Details

**EKS Module — OIDC Provider (IRSA):**
```hcl
data "tls_certificate" "eks" {
  count = var.enable_irsa ? 1 : 0
  url   = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  count           = var.enable_irsa ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  tags            = var.tags
}
```

**EKS Module — Cluster Logging:**
```hcl
# Add to aws_eks_cluster.main:
enabled_cluster_log_types = var.enable_cluster_logging ? var.cluster_log_types : []
```

**EKS Module — CloudWatch Node Policy:**
```hcl
resource "aws_iam_role_policy_attachment" "node_cloudwatch_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.node.name
}
```

**App2 VPC Call — Add Private Subnets:**
```hcl
module "vpc" {
  source               = "../../modules/vpc"
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = true
  enable_flow_logs     = false
  tags = {
    Environment                                 = var.environment
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  }
}
```

**App2 EKS Call — Enable IRSA + Logging:**
```hcl
module "eks" {
  source                 = "../../modules/eks"
  cluster_name           = var.project_name
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = module.vpc.private_subnet_ids
  instance_type          = var.instance_type
  desired_size           = var.desired_size
  min_size               = var.min_size
  max_size               = var.max_size
  admin_arns             = ["arn:aws:iam::925185632967:user/admin-user"]
  enable_irsa            = true
  enable_cluster_logging = true
  cluster_log_types      = ["api", "audit", "authenticator"]
  tags = {
    Environment = var.environment
  }
}
```

---

## Phase 2: Add Kubernetes/Helm/TLS Providers

**Files modified:**
- `terraform/stacks/app2/versions.tf` — Add `kubernetes ~2.25`, `helm ~2.12`, `tls ~4.0` providers

**Files created:**
- `terraform/stacks/app2/providers.tf` — Configure kubernetes/helm providers using EKS cluster endpoint + auth token

### Details

**versions.tf additions:**
```hcl
kubernetes = {
  source  = "hashicorp/kubernetes"
  version = "~> 2.25"
}
helm = {
  source  = "hashicorp/helm"
  version = "~> 2.12"
}
tls = {
  source  = "hashicorp/tls"
  version = "~> 4.0"
}
```

**providers.tf:**
```hcl
data "aws_eks_cluster_auth" "main" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}
```

---

## Phase 3: Deploy Linkerd via Terraform

**Files created:**
- `terraform/stacks/app2/linkerd.tf` — TLS certs (trust anchor + issuer via `tls` provider), `helm_release` for linkerd-crds, `helm_release` for linkerd-control-plane

### Details

**mTLS Certificate Chain:**
- Trust anchor CA: 10-year validity, ECDSA P256, self-signed
- Issuer cert: 1-year validity, signed by trust anchor

**Helm Releases:**
```hcl
resource "helm_release" "linkerd_crds" {
  name             = "linkerd-crds"
  repository       = "https://helm.linkerd.io/edge"
  chart            = "linkerd-crds"
  namespace        = "linkerd"
  create_namespace = true
  depends_on       = [module.eks]
}

resource "helm_release" "linkerd_control_plane" {
  name       = "linkerd-control-plane"
  repository = "https://helm.linkerd.io/edge"
  chart      = "linkerd-control-plane"
  namespace  = "linkerd"

  set { name = "identityTrustAnchorsPEM"; value = tls_self_signed_cert.linkerd_trust_anchor.cert_pem }
  set { name = "identity.issuer.tls.crtPEM"; value = tls_locally_signed_cert.linkerd_issuer.cert_pem }
  set { name = "identity.issuer.tls.keyPEM"; value = tls_private_key.linkerd_issuer.private_key_pem }

  depends_on = [helm_release.linkerd_crds]
}
```

---

## Phase 4: Deploy NGINX Ingress Controller via Terraform

**Files created:**
- `terraform/stacks/app2/ingress.tf` — `helm_release` for ingress-nginx

### Details

```hcl
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  # AWS NLB instead of Classic LB
  set { name = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"; value = "nlb" }
  # Default IngressClass
  set { name = "controller.ingressClassResource.default"; value = "true" }
  # Linkerd sidecar injection
  set { name = "controller.podAnnotations.linkerd\\.io/inject"; value = "enabled" }

  depends_on = [module.eks, helm_release.linkerd_control_plane]
}
```

---

## Phase 5: Overhaul Application Helm Chart

**Files modified:**
- `helm/app-chart/Chart.yaml` — Bump to v1.0.0
- `helm/app-chart/values.yaml` — Complete rewrite with all config knobs
- `helm/app-chart/templates/deployment.yaml` — Probes, security context, SA, Linkerd, envFrom
- `helm/app-chart/templates/service.yaml` — Helpers, ClusterIP, named ports

**Files created:**
- `helm/app-chart/templates/_helpers.tpl` — name, fullname, labels, selectorLabels, serviceAccountName
- `helm/app-chart/templates/serviceaccount.yaml` — With IRSA annotation support
- `helm/app-chart/templates/ingress.yaml` — nginx IngressClass, multi-host, TLS
- `helm/app-chart/templates/configmap.yaml` — Key-value env vars
- `helm/app-chart/templates/hpa.yaml` — CPU/memory autoscaling (autoscaling/v2)
- `helm/app-chart/templates/pdb.yaml` — minAvailable/maxUnavailable
- `helm/app-chart/templates/networkpolicy.yaml` — Allow ingress only from ingress-nginx namespace
- `helm/app-chart/values-dev.yaml` — 1 replica, debug logging, no HPA/PDB/NetworkPolicy
- `helm/app-chart/values-qa.yaml` — 2 replicas, HPA 2-5, PDB enabled, NetworkPolicy enabled
- `helm/app-chart/values-prod.yaml` — 3 replicas, HPA 3-10, higher resources, PDB minAvailable=2

### Key values.yaml Changes

| Setting | Old | New |
|---------|-----|-----|
| service.type | LoadBalancer | ClusterIP |
| image.tag | 1.21 | 1.25 |
| serviceAccount | none | create: true, IRSA-ready |
| linkerd.inject | none | enabled |
| probes | none | liveness + readiness |
| securityContext | none | runAsNonRoot, drop ALL capabilities |
| ingress | none | configurable, nginx class |
| autoscaling | none | HPA with CPU/memory targets |
| podDisruptionBudget | none | configurable minAvailable |
| networkPolicy | none | restrict to ingress-nginx namespace |
| configMap | none | optional env var injection |

---

## Phase 6: Deploy App Chart via Terraform

**Files created:**
- `terraform/stacks/app2/app.tf` — `helm_release` using local chart path

### Details

```hcl
resource "helm_release" "app" {
  name             = "${var.project_name}-app"
  chart            = "${path.module}/helm/app-chart"
  namespace        = "app-${var.environment}"
  create_namespace = true

  values = [
    file("${path.module}/helm/app-chart/values.yaml"),
    file("${path.module}/helm/app-chart/values-${var.environment}.yaml"),
  ]

  depends_on = [helm_release.linkerd_control_plane, helm_release.nginx_ingress]
}
```

---

## Summary

| Action | Count |
|--------|-------|
| Files modified | 12 |
| Files created | 14 |
| **Total** | **26 files** |

## Dependency Order

```
Phase 1 (VPC + EKS fixes)
  └─> Phase 2 (Providers)
        └─> Phase 3 (Linkerd)
              └─> Phase 4 (NGINX Ingress)
                    └─> Phase 5 (Helm chart overhaul)
                          └─> Phase 6 (App deployment)
```

## Verification

1. `terraform fmt -check -recursive terraform/` — Validate formatting
2. `terraform init` from `terraform/stacks/app2/` — Verify providers resolve
3. `terraform validate` — Check config syntax
4. `terraform plan -var-file="dev.tfvars"` — Verify plan shows:
   - 2 private subnets created
   - OIDC provider created
   - EKS cluster logging enabled
   - Linkerd CRDs + control plane helm releases
   - NGINX Ingress helm release
   - App helm release
5. `helm template test helm/app-chart -f helm/app-chart/values-dev.yaml` — Validate Helm template rendering
