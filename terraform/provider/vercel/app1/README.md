# Vercel App1 — Next.js + AWS Backend

## Architecture

```
Vercel Edge Network
└── Next.js 14 (App Router)
    ├── / (React frontend — fetches from API route)
    └── /api/data (serverless fn → proxies to AWS Lambda)
                          │
                          ▼
                  AWS Lambda (app8)
                  AWS DynamoDB (app3)
```

## Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Next.js 14, React 18, Tailwind CSS |
| API | Next.js Route Handlers (serverless) |
| Backend | AWS Lambda (app8 — Node.js container) |
| Database | AWS DynamoDB (app3 global table) |
| Hosting | Vercel (git-push deploy) |
| IaC | Terraform (vercel provider ~> 1.0) |

## Setup

### 1. Terraform — provision Vercel project
```bash
cd terraform/provider/vercel/app1
terraform init
terraform apply -var-file="vars/dev.tfvars"
```

### 2. Next.js app — local dev
```bash
cd app
npm install
cp .env.example .env.local   # fill in AWS_LAMBDA_URL
npm run dev
```

### 3. Deploy
Push to GitHub — Vercel auto-deploys on every push.  
Preview URLs generated for every PR.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `AWS_LAMBDA_URL` | Lambda function URL from app8 |
| `AWS_REGION` | AWS region (default: us-east-1) |
| `DYNAMODB_TABLE` | DynamoDB table name from app3 |

## Required GitHub Secrets (Terraform CI)

| Secret | Purpose |
|--------|---------|
| `VERCEL_API_TOKEN` | Vercel authentication |
