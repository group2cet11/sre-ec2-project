# SRE EC2 Project (Terraform + GitHub Actions + Monitoring)

This repo deploys a minimal SRE stack on **AWS EC2** using **Terraform**, with CI/CD via **GitHub Actions (OIDC)** and observability using **CloudWatch** plus optional **Prometheus + Grafana**.

## Accounts & Branch-to-Account Mapping
- **Main (production deploy)** → Account **<ACCOUNT_ID_M3L>** (your `m3l415072023` daily-cleanup account)
- **Other branches (sandbox/dev)** → Account **<ACCOUNT_ID_1084>** (course mate account `108471662249`) — optional

> Replace `<ACCOUNT_ID_M3L>` and `<ACCOUNT_ID_1084>` with the 12-digit AWS account IDs in `.github/workflows/terraform-deploy.yml` after creating the IAM roles below.

## GitHub OIDC IAM Role (create in each account)
Create an IAM role named:
- `github-oidc-role-dev` in the sandbox account (108471662249)
- `github-oidc-role-prod` in the main deploy account (<ACCOUNT_ID_M3L>)

**Trust relationship**
- Provider: `token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`
- Condition example (scoped to your repo):
```
"Condition": {
  "StringLike": {
    "token.actions.githubusercontent.com:sub": "repo:group2cet11/sre-ec2-project:*"
  },
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
  }
}
```
Attach policies (min for demo; scope down as needed):
- `AmazonEC2FullAccess`
- `AmazonS3FullAccess`
- `CloudWatchFullAccess`
- `IAMReadOnlyAccess`

Copy the resulting role ARNs:
- `arn:aws:iam::<ACCOUNT_ID_1084>:role/github-oidc-role-dev`
- `arn:aws:iam::<ACCOUNT_ID_M3L>:role/github-oidc-role-prod`

Paste them into `.github/workflows/terraform-deploy.yml`.

## Terraform Remote State
Provide/create these resources in each target account/region:
- S3 bucket (per account): e.g., `sre-tf-backend-dev` and `sre-tf-backend-prod`
- DynamoDB table: `terraform-locks` (with primary key `LockID` as string)

Update `terraform/backend.tfvars` (created per-env) or set via CLI.

## Environments
We use **Terraform workspaces** + tfvars files:
- `dev`, `uat`, `prod`

Example:
```bash
terraform workspace new dev
terraform workspace select dev
terraform init -backend-config=backend.dev.tfvars
terraform apply -var-file=terraform/envs/dev.tfvars
```

## What gets deployed
- VPC + public subnet + IGW + route table
- Security group allowing HTTP(80) and SSH(22)
- EC2 `t3.micro` (Amazon Linux 2023) with **Nginx** and a tiny **Flask API** on port 8080 (Nginx can be added later as reverse proxy)
- CloudWatch Log Group
- Outputs: EC2 public IP

## Monitoring
- **CloudWatch** metrics/logs by default
- Optional **Prometheus + Grafana** (Docker compose on EC2) — sample configs under `monitoring/`

## Branching
- Use GitFlow or trunk: `feature/*` → PR → `main`
- `main` triggers **plan + apply (after manual approval)** to the m3l account

## How to find your 12‑digit AWS Account ID
AWS Console → upper-right **Account name** → **Account ID**.

---

### Quickstart
```bash
# 1) Clone and enter
git clone https://github.com/group2cet11/sre-ec2-project.git
cd sre-ec2-project

# 2) Select environment
terraform workspace new dev || true
terraform workspace select dev

# 3) Init back end (adjust file to your S3 bucket/DDB table)
terraform init -backend-config=backend.dev.tfvars

# 4) Plan + Apply
terraform plan -var-file=terraform/envs/dev.tfvars -out=tfplan
terraform apply tfplan
```

> The GitHub Actions workflow will do most of this automatically on push to `main` once OIDC is configured. 
