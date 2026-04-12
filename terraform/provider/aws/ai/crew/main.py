#!/usr/bin/env python3
"""
Terraform Audit Crew — Multi-agent infrastructure audit using CrewAI.

Agents:
  1. Security Analyst  — scans for vulnerabilities and misconfigurations
  2. Cost Optimizer    — identifies savings opportunities
  3. Report Writer     — compiles findings into an actionable report

Usage:
  python main.py                                          # audit the default stack
  python main.py --dir /path/to/terraform/stack           # audit a specific stack
  python main.py --dir /path/to/stack --out report.md     # custom output path
"""

import argparse
import os
import sys
from datetime import datetime

from dotenv import load_dotenv
from crewai import Crew, Process

from agents import create_security_agent, create_cost_agent, create_report_agent
from tasks import create_security_task, create_cost_task, create_report_task


def main():
    load_dotenv()

    parser = argparse.ArgumentParser(description="Terraform Audit Crew")
    parser.add_argument(
        "--dir",
        default=os.path.join(
            os.path.dirname(__file__),
            "..",
            "..",
            "azure",
            "region-failover",
        ),
        help="Path to the Terraform stack to audit",
    )
    parser.add_argument(
        "--out",
        default=None,
        help="Output path for the audit report (default: ./reports/<timestamp>.md)",
    )
    args = parser.parse_args()

    terraform_dir = os.path.abspath(args.dir)
    if not os.path.isdir(terraform_dir):
        print(f"Error: {terraform_dir} is not a valid directory")
        sys.exit(1)

    if args.out:
        output_path = os.path.abspath(args.out)
    else:
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        output_path = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "reports", f"audit-{timestamp}.md")
        )

    print(f"Terraform Audit Crew")
    print(f"{'=' * 50}")
    print(f"Target:  {terraform_dir}")
    print(f"Output:  {output_path}")
    print(f"{'=' * 50}\n")

    # Create agents
    security_agent = create_security_agent()
    cost_agent = create_cost_agent()
    report_agent = create_report_agent()

    # Create tasks
    security_task = create_security_task(security_agent, terraform_dir)
    cost_task = create_cost_task(cost_agent, terraform_dir)
    report_task = create_report_task(report_agent, terraform_dir, output_path)

    # The report task depends on security and cost tasks completing first
    report_task.context = [security_task, cost_task]

    # Assemble the crew
    crew = Crew(
        agents=[security_agent, cost_agent, report_agent],
        tasks=[security_task, cost_task, report_task],
        process=Process.sequential,
        verbose=True,
    )

    # Run the audit
    result = crew.kickoff()

    print(f"\n{'=' * 50}")
    print(f"Audit complete! Report saved to: {output_path}")
    print(f"{'=' * 50}")

    return result


if __name__ == "__main__":
    main()
