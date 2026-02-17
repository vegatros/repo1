# Infrastructure Visualization Guide

This document contains Mermaid diagrams that explain the repository's infrastructure and workflows. You can view these diagrams on GitHub or using any Mermaid-compatible viewer.

## Table of Contents
1. [Repository Structure](#repository-structure)
2. [Terraform Workflow](#terraform-workflow)
3. [Checkov Security Scan](#checkov-security-scan)
4. [SonarCloud Code Quality Scan](#sonarcloud-code-quality-scan)
5. [AWS Infrastructure Architecture](#aws-infrastructure-architecture)
6. [GitHub Actions OIDC Authentication](#github-actions-oidc-authentication)
7. [Complete CI/CD Pipeline](#complete-cicd-pipeline)

---

## Repository Structure

```mermaid
graph TD
    A[Repository Root] --> B[terraform/]
    A --> C[.github/workflows/]
    A --> D[cloudtrail/]
    A --> E[install.sh]
    
    B --> B1[stacks/]
    B --> B2[modules/]
    
    B1 --> B1A[app1/]
    B1 --> B1B[app2/]
    
    B1A --> B1A1[main.tf]
    B1A --> B1A2[variables.tf]
    B1A --> B1A3[outputs.tf]
    B1A --> B1A4[backend.tf]
    B1A --> B1A5[dev.tfvars]
    B1A --> B1A6[qa.tfvars]
    B1A --> B1A7[prod.tfvars]
    
    B1B --> B1B1[main.tf]
    B1B --> B1B2[variables.tf]
    B1B --> B1B3[outputs.tf]
    B1B --> B1B4[backend.tf]
    B1B --> B1B5[dev.tfvars]
    B1B --> B1B6[qa.tfvars]
    B1B --> B1B7[prod.tfvars]
    
    B2 --> B2A[vpc/]
    B2 --> B2B[ec2/]
    B2 --> B2C[eks/]
    B2 --> B2D[ecs/]
    B2 --> B2E[iam/]
    B2 --> B2F[bedrock/]
    
    C --> C1[terraform-app1.yml]
    C --> C2[terraform-app2.yml]
    C --> C3[code-scan.yml]
    
    style A fill:#e1f5ff
    style B fill:#fff4e1
    style C fill:#e8f5e9
    style B1 fill:#fce4ec
```

---

## Terraform Workflow

### High-Level Flow

```mermaid
flowchart TD
    Start([Manual Workflow Dispatch]) --> Select[Select Environment & Action]
    
    Select --> Checkout[Checkout Code]
    Checkout --> Auth[AWS OIDC Authentication]
    Auth --> Init[Terraform Init with Env State]
    Init --> Scan1[Run Checkov Security Scan]
    Scan1 --> Scan2[Run SonarCloud Scan]
    Scan2 --> Plan[Terraform Plan with Env tfvars]
    
    Plan --> Action{Action Type?}
    Action -->|plan| End1([Plan Complete])
    Action -->|apply| Apply[Terraform Apply]
    Action -->|destroy| Destroy[Terraform Destroy]
    
    Apply --> Deploy[Deploy to AWS]
    Deploy --> End2([Success])
    
    Destroy --> Remove[Remove Infrastructure]
    Remove --> End3([Destroyed])
    
    style Start fill:#4caf50
    style End1 fill:#2196f3
    style End2 fill:#4caf50
    style End3 fill:#f44336
    style Deploy fill:#9c27b0
    style Scan1 fill:#ff9800
    style Scan2 fill:#ff9800
```

### Detailed Terraform Workflow Steps

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant GHA as GitHub Actions
    participant AWS as AWS
    participant S3 as S3 Backend
    
    Dev->>GH: Trigger workflow (select env + action)
    GH->>GHA: Start workflow
    
    GHA->>GHA: Checkout code (full history)
    GHA->>AWS: Request OIDC token
    AWS-->>GHA: Return temporary credentials
    
    GHA->>S3: terraform init (env-specific state)
    S3-->>GHA: Return current state
    
    GHA->>GHA: Run Checkov security scan
    GHA->>GHA: Run SonarCloud quality scan
    GHA->>GHA: terraform plan (with env.tfvars)
    
    alt Action: plan
        GHA->>GH: Display plan output
    else Action: apply
        GHA->>AWS: terraform apply
        AWS-->>GHA: Resources created/updated
        GHA->>S3: Update state file
    else Action: destroy
        GHA->>AWS: terraform destroy
        AWS-->>GHA: Resources deleted
        GHA->>S3: Update state file
    end
```

---

## Checkov Security Scan

### Checkov Workflow

```mermaid
flowchart LR
    A([PR/Push to Master]) --> B[Checkout Code]
    B --> C[Run Checkov Scan]
    C --> D{Scan terraform/stacks/app1}
    
    D --> E[Check Security Issues]
    E --> F[Check Compliance]
    F --> G[Generate Reports]
    
    G --> H[CLI Output]
    G --> I[SARIF File]
    
    I --> J{File Exists?}
    J -->|Yes| K[Upload to GitHub Security]
    J -->|No| L[Skip Upload]
    
    K --> M[View in Security Tab]
    H --> N[View in Logs]
    
    M --> O([End])
    N --> O
    L --> O
    
    style A fill:#4caf50
    style C fill:#ff9800
    style K fill:#2196f3
    style M fill:#9c27b0
```

### Security Checks Performed

```mermaid
mindmap
  root((Checkov Security))
    Infrastructure
      VPC Configuration
      Subnet Settings
      Security Groups
      Network ACLs
    Compute
      EC2 Instance Settings
      IAM Roles
      Key Management
      Encryption
    Compliance
      CIS Benchmarks
      PCI DSS
      HIPAA
      SOC 2
    Best Practices
      Tagging
      Logging
      Monitoring
      Backup
```

---

## SonarCloud Code Quality Scan

### SonarCloud Workflow

```mermaid
flowchart LR
    A([PR/Push to Master]) --> B[Checkout Code]
    B --> C[Run SonarCloud Scan]
    C --> D{Analyze Terraform Code}
    
    D --> E[Code Quality Check]
    D --> F[Security Vulnerabilities]
    D --> G[Code Smells]
    D --> H[Technical Debt]
    
    E --> I[Generate Report]
    F --> I
    G --> I
    H --> I
    
    I --> J[Upload to SonarCloud]
    J --> K[View Dashboard]
    
    K --> L([End])
    
    style A fill:#4caf50
    style C fill:#ff9800
    style J fill:#2196f3
    style K fill:#9c27b0
```

### Code Quality Metrics

```mermaid
mindmap
  root((SonarCloud Analysis))
    Code Quality
      Maintainability
      Reliability
      Duplications
      Complexity
    Security
      Vulnerabilities
      Security Hotspots
      Sensitive Data
      Injection Flaws
    Coverage
      Code Coverage
      Test Results
      Branch Coverage
    Technical Debt
      Debt Ratio
      Effort to Fix
      Code Smells
```

---

## AWS Infrastructure Architecture

### App1 Module Architecture

```mermaid
graph TB
    subgraph AWS Cloud
        subgraph VPC[VPC - 10.0.0.0/16]
            IGW[Internet Gateway]
            
            subgraph PublicSubnet[Public Subnet - 10.0.1.0/24]
                EC2Public[EC2 Instance]
                SG1[Security Group]
            end
            
            subgraph PrivateSubnet[Private Subnet - 10.0.2.0/24]
                EC2Private[EC2 Instance]
                SG2[Security Group]
            end
            
            RT[Route Table]
        end
    end
    
    Internet((Internet)) --> IGW
    IGW --> RT
    RT --> PublicSubnet
    RT --> PrivateSubnet
    
    EC2Public -.->|Protected by| SG1
    EC2Private -.->|Protected by| SG2
    
    style VPC fill:#e3f2fd
    style PublicSubnet fill:#c8e6c9
    style PrivateSubnet fill:#ffccbc
    style IGW fill:#fff9c4
```

### Multi-Module Infrastructure

```mermaid
graph LR
    subgraph Terraform Modules
        A[App1 Module<br/>EC2] --> AWS1[EC2 Instances]
        B[App2 Module<br/>EKS] --> AWS2[Kubernetes Cluster]
        C[ECS Module] --> AWS3[Container Service]
        D[IAM Module] --> AWS4[Roles & Policies]
        E[Bedrock Module] --> AWS5[AI/ML Services]
        F[VPC Module] --> AWS6[Network Infrastructure]
    end
    
    subgraph AWS Account
        AWS1
        AWS2
        AWS3
        AWS4
        AWS5
        AWS6
    end
    
    AWS4 -.->|Provides Access| AWS1
    AWS4 -.->|Provides Access| AWS2
    AWS4 -.->|Provides Access| AWS3
    AWS4 -.->|Provides Access| AWS5
    
    AWS6 -.->|Network for| AWS1
    AWS6 -.->|Network for| AWS2
    AWS6 -.->|Network for| AWS3
    
    style A fill:#4caf50
    style B fill:#2196f3
    style C fill:#ff9800
    style D fill:#9c27b0
    style E fill:#e91e63
    style F fill:#00bcd4
```

### App2 EKS Architecture

```mermaid
graph TB
    subgraph AWS Cloud
        subgraph VPC[VPC Module - 10.0.0.0/16]
            IGW[Internet Gateway]
            NAT[NAT Gateway]
            
            subgraph PublicSubnets[Public Subnets]
                PubSub1[10.0.1.0/24]
                PubSub2[10.0.2.0/24]
            end
            
            subgraph PrivateSubnets[Private Subnets]
                PrivSub1[10.0.101.0/24]
                PrivSub2[10.0.102.0/24]
                
                subgraph EKS[EKS Cluster]
                    CP[Control Plane]
                    
                    subgraph NodeGroup[Managed Node Group]
                        Node1[Worker Node<br/>t3.medium/large]
                    end
                end
            end
        end
        
        IAM[IAM Roles]
        SG[Security Groups]
    end
    
    Internet((Internet)) --> IGW
    IGW --> PublicSubnets
    PublicSubnets --> NAT
    NAT --> PrivateSubnets
    
    IAM -.->|Cluster Role| CP
    IAM -.->|Node Role| NodeGroup
    SG -.->|Protects| EKS
    
    style VPC fill:#e3f2fd
    style PublicSubnets fill:#c8e6c9
    style PrivateSubnets fill:#ffccbc
    style EKS fill:#b39ddb
    style NodeGroup fill:#90caf9
```

---

## GitHub Actions OIDC Authentication

### OIDC Authentication Flow

```mermaid
sequenceDiagram
    participant GHA as GitHub Actions
    participant GH as GitHub OIDC Provider
    participant AWS as AWS STS
    participant IAM as IAM Role
    participant Resources as AWS Resources
    
    GHA->>GH: Request OIDC token
    GH-->>GHA: Return JWT token
    
    GHA->>AWS: AssumeRoleWithWebIdentity
    Note over GHA,AWS: JWT token + Role ARN
    
    AWS->>IAM: Validate trust policy
    IAM-->>AWS: Trust validated
    
    AWS->>AWS: Verify token signature
    AWS->>AWS: Check token claims
    
    AWS-->>GHA: Temporary credentials
    Note over AWS,GHA: Access Key, Secret Key, Session Token<br/>(Valid for 1 hour)
    
    GHA->>Resources: Access AWS resources
    Resources-->>GHA: Perform operations
    
    Note over GHA,Resources: No long-lived credentials stored!
```

### OIDC Trust Relationship

```mermaid
graph TD
    A[GitHub Actions Workflow] -->|1. Request Token| B[GitHub OIDC Provider]
    B -->|2. Issue JWT| A
    A -->|3. Present JWT + Role ARN| C[AWS STS]
    
    C -->|4. Validate| D{Trust Policy Check}
    D -->|Check Issuer| E[token.actions.githubusercontent.com]
    D -->|Check Audience| F[sts.amazonaws.com]
    D -->|Check Subject| G[repo:owner/repo:ref:refs/heads/master]
    
    E --> H{Valid?}
    F --> H
    G --> H
    
    H -->|Yes| I[Issue Temporary Credentials]
    H -->|No| J[Deny Access]
    
    I --> K[Access AWS Resources]
    
    style A fill:#4caf50
    style C fill:#ff9800
    style I fill:#2196f3
    style J fill:#f44336
    style K fill:#9c27b0
```

---

## Complete CI/CD Pipeline

### End-to-End Pipeline

```mermaid
graph TB
    Start([Developer Commits Code]) --> Branch{Branch?}
    
    Branch -->|Feature Branch| FB[Feature Branch]
    Branch -->|Master Branch| MB[Master Branch]
    
    FB --> PR[Create Pull Request]
    PR --> Trigger1[Trigger Workflows]
    
    Trigger1 --> TF1[Terraform Workflow]
    Trigger1 --> CV1[Checkov Scan]
    Trigger1 --> SQ1[SonarCloud Scan]
    
    TF1 --> Plan[Generate Plan]
    Plan --> Comment[Comment on PR]
    
    CV1 --> Scan1[Security Scan]
    Scan1 --> Report1[Post Results]
    
    SQ1 --> ScanSQ[Code Quality Scan]
    ScanSQ --> ReportSQ[Upload to SonarCloud]
    
    Comment --> Review[Code Review]
    Report1 --> Review
    ReportSQ --> Review
    
    Review --> Approve{Approved?}
    Approve -->|No| Fix[Fix Issues]
    Fix --> PR
    Approve -->|Yes| Merge[Merge to Master]
    
    MB --> Trigger2[Trigger Workflows]
    Merge --> Trigger2
    
    Trigger2 --> TF2[Terraform Workflow]
    Trigger2 --> CV2[Checkov Scan]
    Trigger2 --> SQ2[SonarCloud Scan]
    
    TF2 --> Plan2[Generate Plan]
    Plan2 --> Approval[Manual Approval Required]
    
    Approval --> Wait{Approved?}
    Wait -->|No| Cancel[Cancel Deployment]
    Wait -->|Yes| Apply[Terraform Apply]
    
    Apply --> Deploy[Deploy to AWS]
    
    CV2 --> Scan2[Security Scan]
    Scan2 --> Security[Update Security Tab]
    
    SQ2 --> ScanSQ2[Code Quality Scan]
    ScanSQ2 --> Quality[Update SonarCloud]
    
    Deploy --> Success([Deployment Complete])
    Security --> Success
    Quality --> Success
    Cancel --> End([Cancelled])
    
    style Start fill:#4caf50
    style Success fill:#4caf50
    style Deploy fill:#9c27b0
    style Approval fill:#ff9800
    style Cancel fill:#f44336
    style End fill:#757575
```

---

## Workflow Permissions Model

```mermaid
graph TD
    subgraph GitHub Actions Workflow
        W[Workflow Execution]
    end
    
    subgraph Permissions
        P1[id-token: write]
        P2[contents: read]
        P3[pull-requests: write]
        P4[security-events: write]
    end
    
    subgraph Actions
        A1[Request OIDC Token]
        A2[Read Repository Code]
        A3[Comment on PRs]
        A4[Upload Security Scans]
    end
    
    W --> P1
    W --> P2
    W --> P3
    W --> P4
    
    P1 -.->|Enables| A1
    P2 -.->|Enables| A2
    P3 -.->|Enables| A3
    P4 -.->|Enables| A4
    
    A1 --> AWS[AWS Authentication]
    A2 --> Code[Access Code]
    A3 --> PR[PR Comments]
    A4 --> Sec[Security Tab]
    
    style W fill:#4caf50
    style P1 fill:#2196f3
    style P2 fill:#2196f3
    style P3 fill:#2196f3
    style P4 fill:#2196f3
```

---

## State Management

```mermaid
graph LR
    subgraph Local Development
        Dev[Developer]
        Local[Local Terraform]
    end
    
    subgraph GitHub Actions
        GHA[GitHub Actions Runner]
        TF[Terraform]
    end
    
    subgraph AWS
        S3[(S3 State Bucket<br/>terraform-state-925185632967)]
        Lock[(DynamoDB Lock Table<br/>terraform-state-lock)]
        
        subgraph State Files
            S1[app1/terraform.tfstate]
            S2[app2/terraform.tfstate]
        end
    end
    
    Dev -->|terraform init| Local
    Local <-->|Read/Write State| S3
    Local <-->|Acquire Lock| Lock
    
    GHA -->|terraform init| TF
    TF <-->|Read/Write State| S3
    TF <-->|Acquire Lock| Lock
    
    S3 --> S1
    S3 --> S2
    
    S3 -.->|Versioning Enabled| S3V[State History]
    S3 -.->|Encryption| S3E[AES-256]
    
    style S3 fill:#ff9800
    style Lock fill:#f44336
    style S3V fill:#4caf50
    style S3E fill:#2196f3
    style S1 fill:#90caf9
    style S2 fill:#90caf9
```

---

## How to View These Diagrams

### On GitHub
Simply view this file on GitHub - Mermaid diagrams render automatically in markdown files.

### Using Mermaid Live Editor
1. Visit https://mermaid.live/
2. Copy any diagram code block
3. Paste into the editor
4. Export as PNG or SVG

### Using VS Code
1. Install "Markdown Preview Mermaid Support" extension
2. Open this file
3. Use Ctrl+Shift+V (Cmd+Shift+V on Mac) for preview

### Using CLI
```bash
# Install mermaid-cli
npm install -g @mermaid-js/mermaid-cli

# Generate PNG from markdown
mmdc -i DIAGRAMS.md -o diagrams.pdf
```

---

## Diagram Legend

- 🟢 **Green**: Start/Success states
- 🔵 **Blue**: Process steps
- 🟠 **Orange**: Warning/Approval required
- 🔴 **Red**: Error/Failure states
- 🟣 **Purple**: Deployment/Critical actions
- ⬜ **Gray**: End/Cancelled states

---

## Additional Resources

- [Mermaid Documentation](https://mermaid.js.org/)
- [Terraform Documentation](https://www.terraform.io/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS OIDC Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
