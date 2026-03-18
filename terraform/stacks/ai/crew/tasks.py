"""Task definitions for the Terraform Audit Crew."""

from crewai import Task, Agent


def create_security_task(agent: Agent, terraform_dir: str) -> Task:
    return Task(
        description=(
            f"Audit the Terraform code in '{terraform_dir}' for security issues.\n\n"
            "Use the 'Read Terraform Files' tool to load the .tf files, then analyze for:\n"
            "1. **Network exposure** — public IPs, open security groups, missing private endpoints\n"
            "2. **IAM & access control** — overly permissive roles, missing least-privilege\n"
            "3. **Encryption** — unencrypted disks, storage, database connections\n"
            "4. **Data protection** — missing backup policies, retention gaps\n"
            "5. **Secrets management** — hardcoded credentials, missing Key Vault usage\n"
            "6. **Compliance** — TLS version, public access flags, audit logging\n\n"
            "For each finding, provide:\n"
            "- Severity (CRITICAL / HIGH / MEDIUM / LOW)\n"
            "- Resource affected\n"
            "- Description of the issue\n"
            "- Recommended fix"
        ),
        expected_output=(
            "A structured list of security findings with severity, affected resource, "
            "description, and remediation for each issue found."
        ),
        agent=agent,
    )


def create_cost_task(agent: Agent, terraform_dir: str) -> Task:
    return Task(
        description=(
            f"Analyze the Terraform code in '{terraform_dir}' for cost optimization.\n\n"
            "Use the 'Read Terraform Files' tool to load the .tf files, then evaluate:\n"
            "1. **Compute** — VM sizing, burstable vs standard, reserved instances\n"
            "2. **Storage** — tier selection, lifecycle policies, redundancy level vs need\n"
            "3. **Database** — SKU sizing, read replicas cost, backup retention costs\n"
            "4. **Networking** — NAT gateway vs alternatives, load balancer SKU, public IPs\n"
            "5. **Quick wins** — resources that could be right-sized or eliminated\n\n"
            "For each finding, provide:\n"
            "- Impact (HIGH / MEDIUM / LOW savings potential)\n"
            "- Current configuration\n"
            "- Recommended change\n"
            "- Estimated monthly savings (if possible)"
        ),
        expected_output=(
            "A structured list of cost optimization opportunities with impact rating, "
            "current vs recommended configuration, and estimated savings."
        ),
        agent=agent,
    )


def create_report_task(
    agent: Agent, terraform_dir: str, output_path: str
) -> Task:
    return Task(
        description=(
            "Compile the security and cost findings from the other agents into a "
            "single audit report in markdown format.\n\n"
            "The report MUST include these sections:\n"
            "1. **Executive Summary** — 3-5 sentence overview of the audit\n"
            "2. **Stack Overview** — what the Terraform stack provisions\n"
            "3. **Security Findings** — table with Severity | Resource | Issue | Fix\n"
            "4. **Cost Optimization** — table with Impact | Current | Recommended | Savings\n"
            "5. **Prioritized Action Items** — numbered list, highest priority first\n"
            "6. **Score** — Security score (0-100) and Cost efficiency score (0-100)\n\n"
            f"Use the 'Write Report' tool to save the report to '{output_path}'.\n"
            "Make the report clear, concise, and actionable."
        ),
        expected_output=(
            "A complete markdown audit report saved to disk with all sections filled in."
        ),
        agent=agent,
    )
