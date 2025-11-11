#!/bin/bash
# One-click AWS + GitHub Actions setup
# Run once, deploys everything automatically

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     AWS Cloud Platform Demo - Bootstrap Setup             ║
║                                                           ║
║     This script will:                                     ║
║     1. Configure AWS (SSO or access keys)                 ║
║     2. Deploy Terraform state backend (S3 + DynamoDB)     ║
║     3. Set up GitHub repository secrets                   ║
║     4. Trigger GitHub Actions deployment                  ║
║                                                           ║
║     Sit back and relax - everything is automated!         ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check prerequisites
echo -e "\n${BLUE}[1/5] Checking prerequisites...${NC}"
for cmd in aws gh terraform git; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}✗ $cmd not found${NC}"
        echo "Please install: $cmd"
        exit 1
    fi
    echo -e "${GREEN}✓ $cmd${NC}"
done

# Check AWS auth
echo -e "\n${BLUE}[2/5] Checking AWS authentication...${NC}"
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${YELLOW}AWS not authenticated.${NC}"
    echo "Please configure AWS credentials with your deployment user:"
    echo "  aws configure"
    echo ""
    echo "You'll need:"
    echo "  - AWS Access Key ID"
    echo "  - AWS Secret Access Key"
    echo "  - Default region (us-east-1)"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CURRENT_USER=$(aws sts get-caller-identity --query Arn --output text)
echo -e "${GREEN}✓ AWS Account: $ACCOUNT_ID${NC}"
echo -e "${GREEN}✓ Current Identity: $CURRENT_USER${NC}"

# Get user input
echo -e "\n${BLUE}[3/5] Configuration...${NC}"
read -p "Your email for CloudWatch alerts: " ALARM_EMAIL
read -p "GitHub username: " GITHUB_USER
read -p "GitHub repo name (default: aws-project): " REPO_NAME
REPO_NAME=${REPO_NAME:-aws-project}

# Deploy Terraform state infrastructure
echo -e "\n${BLUE}[4/5] Deploying Terraform state infrastructure (S3 + DynamoDB)...${NC}"
cd terraform/state-infra

if [ ! -f terraform.tfvars ]; then
    BUCKET_NAME="terraform-state-${ACCOUNT_ID}-$(openssl rand -hex 3)"
    cat > terraform.tfvars << TFVARS
state_bucket_name = "${BUCKET_NAME}"
lock_table_name   = "terraform-state-lock"
aws_region        = "us-east-1"
TFVARS
fi

terraform init -input=false > /dev/null
terraform apply -auto-approve | grep -E "Apply complete|state_bucket_name|lock_table_name"

STATE_BUCKET=$(terraform output -raw state_bucket_name)
LOCK_TABLE=$(terraform output -raw lock_table_name)
echo -e "${GREEN}✓ Backend deployed${NC}"
echo "  S3: $STATE_BUCKET"
echo "  DynamoDB: $LOCK_TABLE"

# Configure main Terraform to use remote backend
cd ..
echo "Configuring main Terraform backend..."
cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket         = "${STATE_BUCKET}"
    key            = "aws-platform-demo/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "${LOCK_TABLE}"
  }
}
EOF
echo -e "${GREEN}✓ Backend configuration created${NC}"

cd ..

# Set up GitHub
echo -e "\n${BLUE}[5/5] Configuring GitHub repository...${NC}"

# Assuming repository already exists and is set up manually
echo "Using existing GitHub repository: ${GITHUB_USER}/${REPO_NAME}"

# Uncomment below if you want automatic repo creation:
# if ! gh repo view ${GITHUB_USER}/${REPO_NAME} &>/dev/null; then
#     echo "Creating GitHub repository..."
#     gh repo create ${REPO_NAME} --public --source=. --remote=origin --push || true
# else
#     echo "Repository exists, using it..."
#     git remote add origin https://github.com/${GITHUB_USER}/${REPO_NAME}.git 2>/dev/null || true
# fi

# Set GitHub secrets
echo "Setting GitHub secrets..."
gh secret set AWS_ACCESS_KEY_ID -b"$(aws configure get aws_access_key_id)"
gh secret set AWS_SECRET_ACCESS_KEY -b"$(aws configure get aws_secret_access_key)"
gh secret set ALARM_EMAIL -b"${ALARM_EMAIL}"
gh secret set TF_STATE_BUCKET -b"${STATE_BUCKET}"
gh secret set TF_STATE_REGION -b"us-east-1"
gh secret set TF_LOCK_TABLE -b"${LOCK_TABLE}"
echo -e "${GREEN}✓ Secrets configured${NC}"

# Push code
echo "Pushing code to GitHub..."
git add -A
git commit -m "Initial commit: Automated setup" 2>/dev/null || echo "Nothing to commit"
git branch -M main
git push -u origin main --force

# Trigger GitHub Actions
echo -e "\n${GREEN}✓ Setup complete!${NC}"
echo -e "\n${BLUE}Triggering infrastructure deployment...${NC}"
gh workflow run deploy-infra.yml

echo "Waiting for infrastructure deployment to start..."
sleep 5

echo -e "${BLUE}Triggering application deployment...${NC}"
gh workflow run deploy-app.yml

echo -e "\n${GREEN}"
cat << "SUCCESS"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║                   🎉 SUCCESS! 🎉                          ║
║                                                           ║
║   Your infrastructure is deploying via GitHub Actions!    ║
║                                                           ║
║   Next steps:                                             ║
║   1. Watch deployment: gh run watch                       ║
║   2. View in browser: gh repo view --web                  ║
║   3. Check logs: gh run list                              ║
║                                                           ║
║   Deployment takes ~15 minutes                            ║
║   You'll get your app URL in the workflow output          ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
SUCCESS
echo -e "${NC}"

# Watch the run
echo -e "${YELLOW}Opening workflow in browser...${NC}"
sleep 2
gh run watch --exit-status || echo "Run started! Check GitHub Actions tab"

