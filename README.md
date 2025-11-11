# AWS Cloud Platform Demo

> Production-ready AWS infrastructure with ECS Fargate, Terraform, and automated CI/CD. One command to deploy everything.

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-purple?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-ECS%20Fargate-orange?logo=amazon-aws)](https://aws.amazon.com/fargate/)
[![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-blue?logo=github-actions)](https://github.com/features/actions)

## What This Does

Deploys a containerized web application to AWS with:
- **ECS Fargate** - Serverless containers with auto-scaling
- **Application Load Balancer** - High availability across multiple AZs
- **CloudWatch** - Metrics, logs, and intelligent alerts
- **S3 + KMS** - Encrypted storage
- **VPC** - Secure network isolation

All infrastructure is managed with Terraform and deploys via GitHub Actions.

## Quick Start (One Command!)

```bash
./first_time_deploy.sh
```

That's it! The script will:
1. Check prerequisites (AWS CLI, GitHub CLI, Terraform, Docker)
2. Verify AWS authentication with your deployment user
3. Deploy Terraform backend (S3 + DynamoDB for state)
4. Set up all GitHub secrets automatically
5. Push code and trigger deployment via GitHub Actions
6. Give you your application URL (~15 minutes)

### Prerequisites

Install these first:
```bash
# macOS
brew install awscli gh terraform docker

# Linux
# Install AWS CLI: https://aws.amazon.com/cli/
# Install GitHub CLI: https://cli.github.com/
# Install Terraform: https://www.terraform.io/downloads
# Install Docker: https://docs.docker.com/get-docker/
```

You'll also need:
- AWS Account (Free tier works!)
- GitHub Account

## What Gets Deployed

### Infrastructure
- **Multi-AZ VPC** with public subnets, Internet Gateway, and routing
- **ECS Fargate Cluster** running 2 containerized web servers
- **Application Load Balancer** distributing traffic with health checks
- **Auto-scaling** (1-4 tasks based on CPU/memory)
- **S3 Bucket** with versioning and KMS encryption
- **CloudWatch Logs** with 7-day retention
- **CloudWatch Alarms** for CPU, memory, errors, and unhealthy targets
- **SNS Topic** for email alerts

### CI/CD Pipelines

**Two separate GitHub Actions workflows for clean separation of concerns:**

#### 1. Infrastructure Pipeline ([deploy-infra.yml](.github/workflows/deploy-infra.yml))
Runs on push to `main` (uses `eus-dev` by default) or manual dispatch with environment selection:
- **Environment Selection**: Choose from eus-dev, eus-staging, eus-prod, wus-dev, wus-staging, wus-prod
- Format check and validation
- Run Terraform tests
- Security scan with tfsec
- Deploy infrastructure with remote state in S3
- Uses environment-specific tfvars from `tfvars/` directory

#### 2. Application Pipeline ([deploy-app.yml](.github/workflows/deploy-app.yml))
Runs on push to `main` when app files change:
- Build Docker image
- Security scan with Trivy
- Push to ECR
- Update ECS service with new image
- Zero-downtime rolling deployment

## Architecture

```
                                 ┌─────────────┐
                                 │   Users     │
                                 └──────┬──────┘
                                        │
                                        ▼
                              ┌────────────────┐
                              │      ALB       │
                              │  (Multi-AZ)    │
                              └────────┬───────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    ▼                  ▼                  ▼
              ┌──────────┐       ┌──────────┐      ┌──────────┐
              │   ECS    │       │   ECS    │      │   ECS    │
              │ Fargate  │       │ Fargate  │      │ Fargate  │
              │  Task    │       │  Task    │      │  Task    │
              └──────────┘       └──────────┘      └──────────┘
                    │                  │                  │
                    └──────────────────┼──────────────────┘
                                       │
                              ┌────────▼────────┐
                              │   CloudWatch    │
                              │  Logs & Alarms  │
                              └─────────────────┘
                                       │
                              ┌────────▼────────┐
                              │   SNS Topic     │
                              │  (Email Alerts) │
                              └─────────────────┘
```

Full diagram: [diagrams/architecture.xml](diagrams/architecture.xml)

## Project Structure

```
.
├── first_time_deploy.sh           # ONE-COMMAND SETUP - runs everything!
├── README.md                      # This file
├── .gitignore                     # Ignore sensitive files
├── app/
│   ├── Dockerfile                # Multi-stage NGINX container
│   └── index.html                # Web application
├── terraform/
│   ├── tfvars/                   # Environment-specific variables
│   │   └── eus-dev.tfvars       # Default dev environment
│   ├── main.tf                   # Root configuration
│   ├── variables.tf              # Input variables
│   ├── outputs.tf                # Infrastructure outputs
│   ├── state-infra/              # Creates S3 + DynamoDB for Terraform state
│   ├── backend-config/           # Environment-specific backend configs
│   │   ├── eus-dev.tfbackend
│   │   ├── eus-staging.tfbackend
│   │   └── eus-prod.tfbackend
│   └── modules/                  # Reusable modules
│       ├── vpc/                  # Multi-AZ networking
│       ├── kms/                  # Encryption keys
│       ├── s3/                   # Object storage
│       ├── ecs/                  # Container orchestration + ALB
│       └── cloudwatch-alarm/     # Monitoring & alerting
└── .github/workflows/
    ├── deploy-infra.yml          # Infrastructure deployment
    └── deploy-app.yml            # Application deployment
```

## Cost Estimate

**~$45/month** (us-east-1 region):
- ECS Fargate (2 tasks): ~$15
- Application Load Balancer: ~$20
- Data Transfer: ~$5
- CloudWatch, S3, KMS: ~$5

**Cost Optimization Tips**:
- Edit [terraform/terraform.tfvars.example](terraform/terraform.tfvars.example):
  - Set `desired_count = 1` (single task)
  - Set `max_capacity = 2` (reduce scaling limit)
  - Set `log_retention_days = 3` (shorter retention)

## Monitoring

### CloudWatch Alarms (Auto-configured)
- **CPU > 80%** - Triggers when average CPU exceeds threshold
- **Memory > 80%** - High memory utilization alert
- **ERROR logs > 10/min** - Application error spike detection
- **Unhealthy Targets** - ALB health check failures

Alerts are sent to the email you configured during setup.

### View Logs
```bash
aws logs tail /ecs/aws-platform-demo-cluster/aws-platform-demo-service \
  --follow --region us-east-1
```

### Check Status
```bash
# ECS service status
aws ecs describe-services \
  --cluster aws-platform-demo-cluster \
  --services aws-platform-demo-service \
  --region us-east-1

# View CloudWatch alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix aws-platform-demo \
  --region us-east-1
```

## Making Changes

### Update Application
1. Edit `app/index.html` or `app/Dockerfile`
2. Commit and push to `main`
3. **deploy-app.yml** workflow automatically rebuilds and deploys container
4. ECS performs rolling update (zero downtime)

### Update Infrastructure
1. Edit Terraform files in `terraform/` or `terraform/modules/`
2. Commit and push to `main`
3. **deploy-infra.yml** workflow runs plan and applies changes
4. Separate from application deployments for safety

### Manual Deployment
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Testing Locally

### Test Container
```bash
cd app
docker build -t aws-platform-demo:test .
docker run -d -p 8080:80 --name test-app aws-platform-demo:test
curl http://localhost:8080
docker logs test-app
docker stop test-app && docker rm test-app
```

### Test Terraform
```bash
cd terraform
terraform fmt -recursive      # Format code
terraform validate            # Validate syntax
terraform test -verbose       # Run test suites
```


## Troubleshooting

### Setup Issues

**AWS Authentication Failed**
```bash
# Check credentials
aws sts get-caller-identity

# Reconfigure
aws configure sso  # For SSO
# OR
aws configure      # For access keys
```

**GitHub CLI Not Authenticated**
```bash
gh auth login
```

**Missing Prerequisites**
```bash
# Check installed tools
which aws terraform gh docker git
```

### Deployment Issues

**ECS Tasks Not Starting**
```bash
# Check service events
aws ecs describe-services \
  --cluster aws-platform-demo-cluster \
  --services aws-platform-demo-service \
  --query 'services[0].events[0:5]' \
  --region us-east-1
```

**Cannot Access Application**
- Wait 2-3 minutes for ALB provisioning
- Check target health:
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(cd terraform && terraform output -raw target_group_arn) \
  --region us-east-1
```

**GitHub Actions Failing**
- Verify secrets are set: Settings → Secrets and variables → Actions
- Check IAM permissions on AWS credentials
- Review workflow logs in Actions tab

## Cleanup

### Destroy All Resources

**Via GitHub Actions (Recommended):**
```bash
gh workflow run deploy-infra.yml -f action=destroy
# Or via web: Actions → Deploy Infrastructure → Run workflow → Select "destroy"
```

**Via Command Line:**
```bash
cd terraform
terraform destroy
# Type 'yes' when prompted
```

**Warning**: Cleanup removes all AWS resources and stops billing.

### Manual Cleanup (if needed)
```bash
# Empty and delete ECR repository
REPO_NAME="aws-platform-demo"
aws ecr batch-delete-image \
  --repository-name $REPO_NAME \
  --region us-east-1 \
  --image-ids "$(aws ecr list-images --repository-name $REPO_NAME --region us-east-1 --query 'imageIds[*]' --output json)"

aws ecr delete-repository \
  --repository-name $REPO_NAME \
  --region us-east-1 \
  --force
```

## Security

### Built-in Security Features
- ✅ **Encryption at Rest**: KMS-encrypted S3 buckets
- ✅ **Network Isolation**: VPC with security groups
- ✅ **IAM Least Privilege**: Minimal permissions for each role
- ✅ **No Public Access**: S3 buckets block public access
- ✅ **Secrets Management**: GitHub Secrets for credentials
- ✅ **Security Scanning**: tfsec (Terraform) + Trivy (containers)
- ✅ **Container Scanning**: ECR image scanning on push

### Security Best Practices
- Never commit AWS credentials to git
- Rotate credentials regularly
- Use IAM roles instead of access keys when possible
- Review security scan results in GitHub Actions
- Monitor CloudWatch alarms
- Keep dependencies updated

## Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| IaC | Terraform | 1.5+ |
| Cloud Provider | AWS | - |
| Container Registry | Amazon ECR | - |
| Container Orchestration | ECS Fargate | - |
| Load Balancer | Application Load Balancer | - |
| Storage | S3 | - |
| Encryption | KMS | - |
| Monitoring | CloudWatch | - |
| Notifications | SNS | - |
| CI/CD | GitHub Actions | - |
| Container Runtime | Docker | - |
| Web Server | NGINX | 1.25-alpine |

## Features & Best Practices

### Infrastructure as Code
- **Modular Architecture**: 5 reusable Terraform modules
- **State Management**: Remote state in S3 with DynamoDB locking
- **Testing**: Terraform test suites for each module
- **Validation**: Input variable validation and outputs

### Security
- **Encryption**: Customer-managed KMS keys for S3
- **Network Security**: VPC with security groups
- **IAM**: Least privilege roles for ECS tasks and execution
- **Scanning**: Automated security scans in CI/CD

### Observability
- **Metrics**: CloudWatch Container Insights
- **Logs**: Centralized logging with retention policies
- **Alarms**: Intelligent thresholds for CPU, memory, errors
- **Notifications**: SNS email alerts for critical issues

### High Availability
- **Multi-AZ**: Resources spread across availability zones
- **Auto-scaling**: CPU and memory-based scaling (1-4 tasks)
- **Health Checks**: ALB and ECS health monitoring
- **Load Balancing**: Traffic distribution across tasks

### CI/CD
- **GitOps**: Push-to-deploy workflow
- **Automated Testing**: Format, validate, test, security scan
- **Container Pipeline**: Build, scan, push, deploy
- **Manual Controls**: Workflow dispatch for destroy operations

## Advanced Configuration

### Customize Terraform Variables

Edit [terraform/terraform.tfvars.example](terraform/terraform.tfvars.example) (copy to `terraform.tfvars`):

```hcl
# Required
aws_region            = "us-east-1"
project_name          = "aws-platform-demo"
alarm_email_addresses = ["your-email@example.com"]

# Optional - Container Configuration
desired_count     = 2              # Number of running tasks
min_capacity      = 1              # Minimum tasks for auto-scaling
max_capacity      = 4              # Maximum tasks for auto-scaling
container_cpu     = 256            # CPU units (256 = 0.25 vCPU)
container_memory  = 512            # Memory in MB

# Optional - Monitoring
cpu_alarm_threshold    = 80        # CPU % threshold for alarm
memory_alarm_threshold = 80        # Memory % threshold for alarm
log_retention_days     = 7         # CloudWatch log retention

# Optional - Network
vpc_cidr = "10.0.0.0/16"          # VPC CIDR block
availability_zones = [
  "us-east-1a",
  "us-east-1b"
]
```

### Change AWS Region

1. Edit `terraform/terraform.tfvars`: `aws_region = "us-west-2"`
2. Edit `.github/workflows/deploy-infrastructure.yml`: `AWS_REGION: 'us-west-2'`
3. Update availability zones in tfvars to match region
4. Commit and push

### Add HTTPS (Custom Domain)

1. Request ACM certificate in AWS Console
2. Add certificate ARN to Terraform variables
3. Update ALB listener to use HTTPS
4. Configure Route 53 for DNS

### Add Database

Create new Terraform module for RDS:
```hcl
module "database" {
  source = "./modules/rds"

  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  engine          = "postgres"
  instance_class  = "db.t3.micro"
}
```

## GitHub Actions Details

### Infrastructure Workflow ([deploy-infra.yml](.github/workflows/deploy-infra.yml))

**Triggers:**
- Push to `main` when `terraform/**` files change
- Manual dispatch with `apply` or `destroy` action

**Jobs:**
1. **validate-and-plan**
   - Terraform format check, validate, test
   - Security scan with tfsec
   - Generate plan artifact

2. **deploy-infrastructure** (on push or apply)
   - Apply Terraform with remote state
   - Output cluster/service info
   - Upload outputs artifact

3. **destroy-infrastructure** (manual destroy only)
   - Clean ECR repository
   - Destroy all resources

### Application Workflow ([deploy-app.yml](.github/workflows/deploy-app.yml))

**Triggers:**
- Push to `main` when `app/**` files change
- Manual dispatch

**Jobs:**
1. **build-and-deploy**
   - Create/verify ECR repository
   - Build and push Docker image
   - Security scan with Trivy
   - Update ECS service (rolling deployment)
   - Wait for service stability
   - Output application URL

### Manual Workflow Dispatch

**Deploy Infrastructure:**
```bash
# Via web: Actions → Deploy Infrastructure → Run workflow → Select environment + action
# Via CLI (defaults to eus-dev):
gh workflow run deploy-infra.yml
gh workflow run deploy-infra.yml -f environment=eus-prod -f action=apply
gh workflow run deploy-infra.yml -f environment=eus-dev -f action=destroy
```

**Deploy Application:**
```bash
# Via web: Actions → Deploy Application → Run workflow
# Via CLI:
gh workflow run deploy-app.yml
```

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally (see "Testing Locally" section)
5. Submit a pull request

## Acknowledgments

Built with:
- [Terraform](https://www.terraform.io/) for infrastructure as code
- [AWS ECS Fargate](https://aws.amazon.com/fargate/) for serverless containers
- [GitHub Actions](https://github.com/features/actions) for CI/CD
- [NGINX](https://nginx.org/) for web serving

---

**Questions or issues?** Open an issue on GitHub.

**Like this project?** ⭐ Star it and share!
