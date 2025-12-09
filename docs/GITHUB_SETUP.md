# GitHub Repository Setup

## Push to GitHub

### Option 1: Create New Repository

1. Go to https://github.com/new
2. Create repository named `poc-kiro` (or your preferred name)
3. Don't initialize with README (we already have one)
4. Run these commands:

```bash
cd /Users/hengky/workspace/poc-kiro

# Add remote (replace with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/poc-kiro.git

# Push main branch
git push -u origin main

# Push v4 branch
git push -u origin v4

# Push tags
git push --tags
```

### Option 2: Using GitHub CLI

```bash
# Install GitHub CLI if not installed
brew install gh

# Authenticate
gh auth login

# Create repo and push
gh repo create poc-kiro --public --source=. --remote=origin --push
git push -u origin v4
git push --tags
```

## Repository Settings

After pushing, configure these settings:

### Branch Protection (Recommended for Production)

1. Go to Settings → Branches
2. Add rule for `main` branch:
   - Require pull request reviews
   - Require status checks
   - Require branches to be up to date

### Secrets (For CI/CD)

If adding GitHub Actions later, add these secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`

## Verify Push

```bash
# Check remote
git remote -v

# Check branches
git branch -a

# Check tags
git tag -l
```

## Clone Instructions (For Team Members)

Share this with your junior DevOps team:

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/poc-kiro.git
cd poc-kiro

# Checkout v4 branch
git checkout v4

# Start setup
./scripts/setup.sh
```
