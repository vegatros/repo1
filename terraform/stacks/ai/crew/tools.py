"""Custom tools for the Terraform Audit Crew."""

import os
import glob
from crewai.tools import tool


@tool("Read Terraform Files")
def read_terraform_files(directory: str) -> str:
    """Read all .tf files from a directory and return their contents.
    Use this to load Terraform code for analysis."""
    contents = []
    tf_files = sorted(glob.glob(os.path.join(directory, "*.tf")))

    if not tf_files:
        return f"No .tf files found in {directory}"

    for filepath in tf_files:
        filename = os.path.basename(filepath)
        with open(filepath, "r") as f:
            content = f.read()
        contents.append(f"--- {filename} ---\n{content}")

    return "\n\n".join(contents)


@tool("List Terraform Stacks")
def list_terraform_stacks(base_dir: str) -> str:
    """List all directories under a base path that contain .tf files.
    Use this to discover available Terraform stacks to audit."""
    stacks = []
    for root, dirs, files in os.walk(base_dir):
        if any(f.endswith(".tf") for f in files):
            stacks.append(root)
    if not stacks:
        return f"No Terraform stacks found under {base_dir}"
    return "\n".join(sorted(stacks))


@tool("Write Report")
def write_report(filepath: str, content: str) -> str:
    """Write the final audit report to a file.
    Use this to save the completed audit report as markdown."""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, "w") as f:
        f.write(content)
    return f"Report written to {filepath}"
