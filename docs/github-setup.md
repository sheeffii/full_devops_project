# GitHub Repository Setup Guide

## 1. Secrets Setup
Navigate to your repository's settings:
1. Go to `Settings` > `Secrets and variables` > `Actions`
2. Click `New repository secret`
3. Add the following secrets:
   - Name: `AWS_ACCESS_KEY_ID`
   - Name: `AWS_SECRET_ACCESS_KEY`

## 2. Environment Setup
Create a production environment with protection rules:
1. Go to `Settings` > `Environments`
2. Click `New environment`
3. Name it `production`
4. Configure protection rules:
   - Check `Required reviewers`
   - Add required reviewers (team members who can approve deployments)
   - Optional: Add deployment branch rules (e.g., restrict to main branch)

## 3. Branch Protection Rules
Set up branch protection for main:
1. Go to `Settings` > `Branches`
2. Click `Add branch protection rule`
3. Configure for `main`:
   - ✓ Require a pull request before merging
   - ✓ Require status checks to pass before merging
   - ✓ Require branches to be up to date before merging
   - ✓ Include administrators in these restrictions

## 4. Required Status Checks
After your first workflow run, come back to branch protection and enable these specific status checks:
- `Verify AWS Credentials`
- `Lint Code`
- `Build AMI with Packer`
- `Terraform Plan`

## 5. Team Access
Ensure team members have appropriate roles:
1. Go to `Settings` > `Collaborators and teams`
2. Add team members with appropriate roles:
   - Maintainers: Can approve production deployments
   - Write: Can create branches and PRs
   - Read: Can view code and workflows

## Security Note
- Never commit AWS credentials directly to the repository
- Rotate AWS access keys periodically
- Use least-privilege IAM policies for the CI/CD user
- Enable branch protection immediately after repository creation