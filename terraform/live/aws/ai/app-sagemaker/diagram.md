# App SageMaker — MLOps Pipeline Architecture

Full MLOps pipeline on SageMaker: preprocess → train → evaluate → conditional model registration and endpoint deployment.

---

## Pipeline Architecture

```mermaid
flowchart LR
    S3In[(S3<br/>Input Data)] --> Pre[Preprocess<br/>scikit-learn]
    Pre --> Train[Train<br/>XGBoost]
    Train --> Eval[Evaluate<br/>Metrics]
    Eval --> Cond{Accuracy<br/>>= 0.75?}
    Cond -->|Pass| Reg[Register<br/>Model]
    Cond -->|Pass| Deploy[Deploy<br/>Endpoint]
    Cond -->|Fail| Fail[Pipeline<br/>Fail]
    Reg --> MR[(Model<br/>Registry)]
    Deploy --> EP[SageMaker<br/>Endpoint]

    style S3In fill:#ff9800,color:#fff
    style Pre fill:#42a5f5,color:#fff
    style Train fill:#66bb6a,color:#fff
    style Eval fill:#ab47bc,color:#fff
    style Cond fill:#ffa726,color:#fff
    style Reg fill:#26a69a,color:#fff
    style Deploy fill:#26a69a,color:#fff
    style Fail fill:#ef5350,color:#fff
    style MR fill:#ff9800,color:#fff
    style EP fill:#4caf50,color:#fff
```

---

## Infrastructure Architecture

```mermaid
graph TB
    subgraph VPC ["VPC — 10.6.0.0/16"]
        subgraph Public ["Public Subnets (2 AZs)"]
            IGW[Internet Gateway]
        end
        subgraph Private ["Private Subnets (2 AZs)"]
            SM_PRE[Processing Job<br/>Preprocess]
            SM_TRAIN[Training Job<br/>XGBoost]
            SM_EVAL[Processing Job<br/>Evaluate]
            SM_EP[SageMaker<br/>Endpoint]
        end
        subgraph Endpoints ["VPC Endpoints"]
            VPCE_S3[S3 Gateway]
            VPCE_SM[SageMaker API]
            VPCE_RT[SageMaker Runtime]
            VPCE_STS[STS]
            VPCE_LOG[CloudWatch Logs]
        end
    end

    S3[(S3 Bucket<br/>Pipeline Data)] <--> VPCE_S3
    VPCE_SM --> SM_PRE & SM_TRAIN & SM_EVAL
    SM_EP --> VPCE_RT
    ECR[(ECR<br/>Container Images)] -.-> Private
    CW[CloudWatch<br/>Logs] <--> VPCE_LOG
    IAM[IAM Execution<br/>Role] -.-> VPCE_STS

    style VPC fill:#e3f2fd
    style Public fill:#c8e6c9
    style Private fill:#ffccbc
    style Endpoints fill:#e1bee7
    style S3 fill:#ff9800,color:#fff
    style SM_EP fill:#4caf50,color:#fff
```

---

## Pipeline Steps Detail

```mermaid
graph TD
    subgraph Step1 ["1 — Preprocess"]
        P_IN[S3 Raw CSV] --> P_JOB[scikit-learn<br/>StandardScaler<br/>Train/Test Split]
        P_JOB --> P_TRAIN[S3 train.csv]
        P_JOB --> P_TEST[S3 test.csv]
    end

    subgraph Step2 ["2 — Train"]
        T_TRAIN[S3 train.csv] --> T_JOB[XGBoost<br/>binary:logistic<br/>100 rounds]
        T_VAL[S3 test.csv] --> T_JOB
        T_JOB --> T_MODEL[S3 model.tar.gz]
    end

    subgraph Step3 ["3 — Evaluate"]
        E_MODEL[S3 model.tar.gz] --> E_JOB[Load Model<br/>Predict on Test]
        E_TEST[S3 test.csv] --> E_JOB
        E_JOB --> E_REPORT[evaluation.json<br/>accuracy, precision<br/>recall, F1, AUC]
    end

    subgraph Step4 ["4 — Gate"]
        G_IN[evaluation.json] --> G_CHECK{accuracy >= threshold}
        G_CHECK -->|Yes| G_PASS[Register + Deploy]
        G_CHECK -->|No| G_FAIL[Fail Pipeline]
    end

    Step1 --> Step2 --> Step3 --> Step4

    style Step1 fill:#e3f2fd
    style Step2 fill:#e8f5e9
    style Step3 fill:#f3e5f5
    style Step4 fill:#fff3e0
```

---

## Data Flow

```mermaid
flowchart TD
    RAW[Raw CSV in S3] -->|preprocess.py| TRAIN_DATA[train.csv<br/>target first col, no header]
    RAW -->|preprocess.py| TEST_DATA[test.csv]
    TRAIN_DATA -->|XGBoost train| MODEL[model.tar.gz]
    TEST_DATA -->|XGBoost validation| MODEL
    MODEL -->|evaluate.py| METRICS[evaluation.json]
    TEST_DATA -->|evaluate.py| METRICS
    METRICS -->|accuracy check| DECISION{Pass?}
    DECISION -->|Yes| REGISTRY[Model Registry<br/>Versioned Package]
    DECISION -->|Yes| ENDPOINT[SageMaker Endpoint<br/>Real-time Inference]
    DECISION -->|No| STOPPED[Pipeline Stopped]

    style RAW fill:#fff3e0
    style MODEL fill:#e8f5e9
    style METRICS fill:#f3e5f5
    style REGISTRY fill:#e3f2fd
    style ENDPOINT fill:#4caf50,color:#fff
    style STOPPED fill:#ef5350,color:#fff
```

---

## Resources

| Resource | Type | Purpose |
|----------|------|---------|
| VPC | 2 AZs, public + private subnets | Network isolation |
| VPC Endpoints | S3, SageMaker API/Runtime, STS, Logs | Private connectivity, no NAT needed |
| S3 Bucket | KMS encrypted, versioned | Pipeline data, models, scripts |
| SageMaker Pipeline | 6-step MLOps workflow | Orchestrates full ML lifecycle |
| Model Package Group | Model Registry | Versioned model artifacts |
| SageMaker Endpoint | Real-time inference | Serves predictions |
| IAM Role | Least-privilege execution role | SageMaker, S3, ECR, CloudWatch access |

---

## Usage

```bash
cd terraform/stacks/aws/builds/app-sagemaker

# Deploy infrastructure
terraform plan -var-file="vars/dev.tfvars"
terraform apply -var-file="vars/dev.tfvars"

# Upload scripts and data
aws s3 cp scripts/preprocess.py s3://$(terraform output -raw s3_bucket)/scripts/
aws s3 cp scripts/evaluate.py s3://$(terraform output -raw s3_bucket)/scripts/
aws s3 cp scripts/deploy.py s3://$(terraform output -raw s3_bucket)/scripts/
aws s3 cp your-data.csv s3://$(terraform output -raw s3_bucket)/input/

# Execute pipeline
aws sagemaker start-pipeline-execution \
  --pipeline-name sagemaker-pipeline-pipeline \
  --region us-east-1
```

---

## Environment Sizing & Cost Estimate

```mermaid
graph LR
    subgraph Dev ["Dev — Low Cost"]
        D1[Processing: ml.t3.medium]
        D2[Training: ml.m5.large]
        D3[Endpoint: ml.t2.medium]
        D4[VPC: 2 AZs, no NAT]
        D5[Runs: On-demand]
    end

    subgraph QA ["QA — Moderate Cost"]
        Q1[Processing: ml.m5.large]
        Q2[Training: ml.m5.xlarge]
        Q3[Endpoint: ml.m5.large]
        Q4[VPC: 2 AZs, no NAT]
        Q5[Runs: Scheduled daily]
    end

    subgraph Prod ["Prod — Higher Cost"]
        P1[Processing: ml.m5.xlarge]
        P2[Training: ml.m5.2xlarge]
        P3[Endpoint: ml.m5.xlarge x2]
        P4[VPC: 2 AZs, no NAT]
        P5[Runs: Scheduled + triggered]
    end

    style Dev fill:#e8f5e9
    style QA fill:#fff3e0
    style Prod fill:#ffebee
```

### Resource Comparison by Environment

| Resource | Dev | QA | Prod |
|----------|-----|-----|------|
| **Processing Instance** | ml.t3.medium (2 vCPU, 4 GB) | ml.m5.large (2 vCPU, 8 GB) | ml.m5.xlarge (4 vCPU, 16 GB) |
| **Training Instance** | ml.m5.large (2 vCPU, 8 GB) | ml.m5.xlarge (4 vCPU, 16 GB) | ml.m5.2xlarge (8 vCPU, 32 GB) |
| **Endpoint Instance** | ml.t2.medium × 1 | ml.m5.large × 1 | ml.m5.xlarge × 2 |
| **Endpoint Availability** | Single instance | Single instance | Multi-AZ (2 instances) |
| **VPC Endpoints** | 5 (S3, SM API, SM Runtime, STS, Logs) | 5 | 5 |
| **S3 Storage** | ~1 GB | ~10 GB | ~100 GB+ |
| **Pipeline Frequency** | On-demand / manual | Daily scheduled | Scheduled + event-triggered |
| **Flow Logs Retention** | 7 days | 14 days | 30 days |

### Cost Drivers

```mermaid
pie title Estimated Cost Distribution
    "SageMaker Endpoint (always-on)" : 45
    "VPC Endpoints (5 × hourly)" : 25
    "Training Jobs (per run)" : 15
    "Processing Jobs (per run)" : 10
    "S3 Storage" : 5
```

**Key cost notes:**
- **Biggest cost:** The SageMaker endpoint runs 24/7 — this dominates the bill in all environments
- **VPC Endpoints:** 5 interface endpoints each billed hourly (~$0.01/hr each) — fixed cost regardless of usage
- **Training/Processing:** Only billed while jobs run — cost scales with frequency and instance size
- **Dev savings tip:** Tear down the endpoint when not testing; use serverless inference for intermittent workloads
- **S3 Gateway endpoint:** Free (no hourly charge, unlike interface endpoints)

> **For accurate pricing:** Use the [AWS Pricing Calculator](https://calculator.aws.amazon.com/) with the instance types above for your region. Prices vary by region and change over time.
