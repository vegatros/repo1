# Repository Review Summary

Date: 2026-03-05
Reviewer: Codex (automated code review)

## Scope Reviewed
- Terraform modules and stacks under `terraform/`
- GitHub Actions workflows under `.github/workflows/`
- Utility scripts under `scripts/`
- Swift app under `audio/` (lightweight pass)

## Executive Summary
The repository has strong infrastructure breadth and reusable module structure, but there are critical secret-management and security-hardening gaps. The most urgent issues are committed plaintext credentials and committed VPN pre-shared keys. There are also multiple internet-exposed services with insecure defaults and documentation/code drift in App1 networking.

## Findings (by severity)

### Critical
1. Plaintext credentials committed in Terraform variables file
- File: `terraform/stacks/builds/app8/vars/dev.tfvars:12-14`
- Issue: `linux_password` and `jenkins_password` are hardcoded in a tracked file.
- Risk: Immediate credential disclosure in git history and local clones.
- Recommendation: Rotate credentials immediately, remove from git history, and supply via secure runtime input (`TF_VAR_*`, encrypted CI secrets, or SSM/Secrets Manager lookups).

2. VPN pre-shared keys committed to repository
- File: `terraform/stacks/builds/app8/vpn-config.xml:34,79`
- Issue: VPN tunnel pre-shared keys are stored in a tracked XML artifact.
- Risk: VPN compromise if keys are active.
- Recommendation: Rotate both tunnel PSKs now, remove this file from version control/history, and add ignore rules for generated VPN configs.

### High
3. Monitoring host publicly exposed with weak/default credential pattern
- File: `terraform/stacks/builds/app2/monitoring-ec2.tf:27-49,151-154`
- Issue: Ports `22`, `3000`, and `9090` are open to `0.0.0.0/0`; output includes default Grafana credentials string (`admin/admin123`).
- Risk: Brute force and unauthorized dashboard/host access.
- Recommendation: Restrict ingress CIDRs, require SSO or strong rotated credentials, disable direct public SSH, and place monitoring behind private networking/VPN.

4. App8 enables password-based SSH and passwordless sudo
- File: `terraform/stacks/builds/app8/user_data.sh:20,63`
- Issue: `NOPASSWD:ALL` sudo for user and `PasswordAuthentication yes` in SSH.
- Risk: Privilege escalation and credential stuffing attack surface.
- Recommendation: Disable password SSH, use key/SSM-only access, and tighten sudo permissions.

### Medium
5. App1 documentation contradicts deployed network behavior
- Docs: `terraform/stacks/builds/app1/README.md:27,48,208`
- Code: `terraform/stacks/builds/app1/main.tf:57` and `terraform/modules/compute/ec2/main.tf:146`
- Issue: Docs claim EC2 in private subnets with no direct internet access, but stack deploys to public subnets and assigns public IPs.
- Risk: Misleading operational/security assumptions.
- Recommendation: Either move instances to private subnets or update docs to match reality.

6. Workflow actions pinned to mutable `@master`
- Files: `.github/workflows/terraform-app1.yml:59`, `.github/workflows/code-scan.yml:28` (and similar app workflows)
- Issue: Uses unpinned moving targets for critical CI actions.
- Risk: Supply-chain unpredictability and non-reproducible builds.
- Recommendation: Pin actions to full commit SHA (or at minimum stable version tags).

7. Terraform formatting not consistently enforced across stacks
- Check: `terraform fmt -check -recursive terraform` failed
- Example files: `terraform/modules/compute/ec2/main.tf`, `terraform/stacks/builds/app1/main.tf`, `terraform/stacks/builds/app2/monitoring-ec2.tf`, etc.
- Risk: Review noise and avoidable drift.
- Recommendation: Add repo-wide `fmt` gate in CI and run `terraform fmt -recursive`.

## Positive Observations
- Clean modular layout by domain (`network`, `compute`, `containers`, `database`, `iam`, `ai`).
- IMDSv2 is enforced in multiple EC2 resources.
- Encryption and IAM usage is present in several stacks.
- CI workflows include IaC scanning (Trivy) and OIDC-based AWS auth.

## Testing and Validation Notes
- No meaningful automated test suite found for infrastructure logic or Swift app behavior.
- Lightweight static review completed; no live cloud apply/validate executed.
- `terraform fmt -check -recursive terraform` was run and reported formatting drift.

## Recommended Next Actions (priority order)
1. Rotate and purge exposed secrets (App8 credentials + VPN PSKs) from git history.
2. Lock down externally exposed services (App2 monitoring + App8 SSH model).
3. Reconcile App1 docs vs implementation (private subnet design vs current deployment).
4. Pin GitHub Actions to immutable SHAs.
5. Add repo-wide Terraform quality gates (`fmt`, `validate`, `tflint`/policy checks) in CI.
