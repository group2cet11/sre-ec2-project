# CI/CD Pipeline
- GitHub Actions uses OIDC to assume IAM roles in AWS.
- main → prod account role (`github-oidc-role-prod`).
- others → dev account role (`github-oidc-role-dev`).
