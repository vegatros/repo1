# Terraform Audit Crew

Multi-agent infrastructure audit powered by [CrewAI](https://www.crewai.com/). Three AI agents collaborate to analyze Terraform code for security vulnerabilities, cost inefficiencies, and produce a prioritized audit report.

## Architecture Diagram

```
                         ┌──────────────────────────────┐
                         │          main.py              │
                         │     CLI & Crew Orchestrator   │
                         │                               │
                         │  ┌─────────────────────────┐  │
                         │  │     Crew (Sequential)    │  │
                         │  └────────────┬────────────┘  │
                         └───────────────┼───────────────┘
                                         │
                    ┌────────────────────┬┴───────────────────┐
                    │                    │                     │
                    ▼                    ▼                     ▼
        ┌───────────────────┐ ┌──────────────────┐ ┌──────────────────┐
        │  Security Analyst │ │  Cost Optimizer   │ │  Report Writer   │
        │     (Agent 1)     │ │    (Agent 2)      │ │    (Agent 3)     │
        │                   │ │                   │ │                   │
        │ Role: Cloud       │ │ Role: FinOps      │ │ Role: Technical  │
        │ Security Engineer │ │ Expert            │ │ Writer           │
        └────────┬──────────┘ └────────┬──────────┘ └────────┬─────────┘
                 │                     │                      │
                 ▼                     ▼                      ▼
        ┌───────────────────┐ ┌──────────────────┐ ┌──────────────────┐
        │  Security Task    │ │  Cost Task        │ │  Report Task     │
        │                   │ │                   │ │                   │
        │ - Network exposure│ │ - Compute sizing  │ │ - Exec summary   │
        │ - IAM & access    │ │ - Storage tiers   │ │ - Findings tables│
        │ - Encryption      │ │ - Database SKUs   │ │ - Action items   │
        │ - Data protection │ │ - Networking cost │ │ - Scores         │
        │ - Secrets mgmt    │ │ - Quick wins      │ │                   │
        │ - Compliance      │ │                   │ │                   │
        └────────┬──────────┘ └────────┬──────────┘ └────────┬─────────┘
                 │                     │                      │
                 │    Tool Calls       │    Tool Calls        │  Tool Calls
                 ▼                     ▼                      ▼
        ┌─────────────────────────────────────────────────────────────────┐
        │                        tools.py                                 │
        │                                                                 │
        │  ┌─────────────────┐ ┌──────────────────┐ ┌─────────────────┐  │
        │  │ read_terraform  │ │ list_terraform   │ │ write_report    │  │
        │  │ _files()        │ │ _stacks()        │ │ ()              │  │
        │  │                 │ │                   │ │                 │  │
        │  │ Reads *.tf from │ │ Walks dirs to    │ │ Saves markdown  │  │
        │  │ a directory     │ │ find TF stacks   │ │ report to disk  │  │
        │  └────────┬────────┘ └────────┬─────────┘ └────────┬────────┘  │
        └───────────┼──────────────────┼──────────────────────┼──────────┘
                    │                   │                      │
                    ▼                   ▼                      ▼
        ┌─────────────────┐  ┌──────────────────┐  ┌──────────────────┐
        │  Terraform Code │  │  Directory Tree  │  │  reports/        │
        │  *.tf files     │  │  (discovery)     │  │  audit-<ts>.md   │
        └─────────────────┘  └──────────────────┘  └──────────────────┘


  Data Flow
  ─────────

  ┌──────────┐   findings   ┌──────────┐   findings   ┌──────────┐
  │ Security │─────────────►│          │◄──────────────│   Cost   │
  │  Agent   │              │  Report  │               │  Agent   │
  └──────────┘              │  Agent   │               └──────────┘
                            └─────┬────┘
                                  │
                                  ▼
                          ┌──────────────┐
                          │ Audit Report │
                          │  (markdown)  │
                          └──────────────┘

  Task Context Wiring (main.py):
    report_task.context = [security_task, cost_task]

  This passes the output of both analysis tasks
  as input context to the report writer agent.
```

## Project Structure

```
crew/
├── main.py           # CLI entry point — orchestrates the crew
├── agents.py         # 3 agents: security, cost, report writer
├── tasks.py          # Task definitions with detailed prompts
├── tools.py          # Custom tools: read TF files, list stacks, write report
├── requirements.txt  # crewai + dependencies
├── .env.example      # API key config
└── reports/          # Generated audit reports (created at runtime)
```

## Agents

| Agent | Tools | Purpose |
|-------|-------|---------|
| **Security Analyst** | `read_terraform_files`, `list_terraform_stacks` | Reads TF code and finds security issues (open ports, missing encryption, public access, etc.) |
| **Cost Optimizer** | `read_terraform_files` | Reads TF code and spots over-provisioned or expensive resources |
| **Report Writer** | `write_report` | Takes findings from the other two agents and writes the final report to disk |

Each agent has a `role`, `goal`, `backstory`, and assigned `tools`. The backstory primes the LLM with domain expertise — the security agent thinks like a SOC2/HIPAA auditor, the cost agent thinks like a FinOps engineer.

## Tools

Three custom tools decorated with `@tool` so CrewAI agents can call them:

- **`read_terraform_files(directory)`** — Globs all `*.tf` files in a directory, reads their contents, returns them concatenated with filenames as headers. This is how agents ingest Terraform code.
- **`list_terraform_stacks(base_dir)`** — Walks a directory tree and finds all folders containing `.tf` files. Useful for discovery when auditing multiple stacks.
- **`write_report(filepath, content)`** — Writes a string to a file, creating parent directories if needed. The report agent uses this to save the final markdown report.

## Tasks

Each task provides a detailed prompt telling the agent what to look for:

- **Security Task** — 6 audit categories: network exposure, IAM, encryption, data protection, secrets management, compliance. Each finding includes severity, affected resource, description, and remediation.
- **Cost Task** — 5 categories: compute sizing, storage tiers, database SKUs, networking costs, quick wins. Each finding includes impact rating, current vs recommended config, and estimated savings.
- **Report Task** — Compiles both sets of findings into a structured markdown report with executive summary, findings tables, prioritized action items, and scores.

## Execution Flow

```
  security_task runs first
       │  Security agent calls read_terraform_files()
       │  LLM analyzes code, returns findings
       ▼
  cost_task runs second
       │  Cost agent calls read_terraform_files()
       │  LLM analyzes code, returns savings opportunities
       ▼
  report_task runs last
       │  Receives security + cost outputs as context
       │  Report agent compiles everything
       │  Calls write_report() to save markdown file
       ▼
  Done — report on disk
```

Agents don't talk to each other directly. Instead, **task context** passes the output of earlier tasks as input to later ones. `Process.sequential` ensures ordering.

## Setup

```bash
cd terraform/stacks/ai/crew
pip install -r requirements.txt
cp .env.example .env
# Edit .env and add your OpenAI API key
```

## Usage

```bash
# Audit the region-failover stack (default target)
python main.py

# Audit a specific Terraform stack
python main.py --dir /path/to/any/terraform/stack

# Custom output path
python main.py --dir /path/to/stack --out my-report.md
```

## Report Output

The generated report includes:

1. **Executive Summary** — 3-5 sentence overview
2. **Stack Overview** — what the Terraform stack provisions
3. **Security Findings** — table with Severity | Resource | Issue | Fix
4. **Cost Optimization** — table with Impact | Current | Recommended | Savings
5. **Prioritized Action Items** — numbered list, highest priority first
6. **Scores** — Security score (0-100) and Cost efficiency score (0-100)
