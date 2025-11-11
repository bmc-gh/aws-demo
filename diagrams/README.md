# Architecture Diagrams

## Viewing Diagrams

The architecture diagram can be viewed and edited using [draw.io](https://app.diagrams.net/).

### Online Viewing

1. Visit [https://app.diagrams.net/](https://app.diagrams.net/)
2. File → Open → Select `architecture.xml`
3. View and edit as needed

### Offline Viewing

1. Download [draw.io Desktop](https://github.com/jgraph/drawio-desktop/releases)
2. Open `architecture.xml`

## Architecture Overview

### Main Components

**CI/CD Flow:**
```
GitHub Actions → Amazon ECR → ECS Cluster → Application Load Balancer → Users
```

**Infrastructure Components:**

1. **VPC** (10.0.0.0/16)
   - Spans 2 Availability Zones
   - Public subnets for ALB and ECS tasks
   - Internet Gateway for public access

2. **ECS Fargate**
   - Container orchestration platform
   - Auto-scaling based on CPU/Memory
   - Health checks and rolling deployments
   - Runs NGINX containers

3. **Application Load Balancer**
   - Distributes traffic across AZs
   - Health check monitoring
   - Future: HTTPS termination with ACM

4. **Amazon ECR**
   - Private Docker registry
   - Stores container images
   - Integrated with CI/CD pipeline

5. **S3 Bucket**
   - Encrypted at rest with KMS
   - Versioning enabled
   - Public access blocked
   - Optional: Application assets

6. **KMS**
   - Customer-managed encryption key
   - Encrypts: S3, CloudWatch Logs, SNS
   - Automatic key rotation

7. **CloudWatch**
   - Container logs
   - ECS metrics
   - Custom alarms
   - Log metric filters

8. **SNS**
   - Email notifications
   - Alarm alerts
   - Encrypted with KMS

### Data Flow

1. **Deployment Flow:**
   ```
   Developer → Git Push → GitHub Actions → Build → ECR → ECS Update
   ```

2. **Request Flow:**
   ```
   User → Internet → ALB → ECS Task (Container) → Response
   ```

3. **Monitoring Flow:**
   ```
   ECS Tasks → CloudWatch Logs
   CloudWatch Metrics → Alarms → SNS → Email
   ```

### Security Layers

- **Network**: VPC, Security Groups, Subnets
- **Encryption**: KMS for data at rest, TLS for data in transit
- **Access**: IAM roles with least privilege
- **Monitoring**: CloudWatch Logs, Alarms, Container Insights

### High Availability

- Multi-AZ deployment across 2 availability zones
- Auto-scaling for ECS tasks (1-4 tasks)
- ALB health checks with automatic failover
- Redundant networking (IGW, multiple subnets)

## CI/CD Pipeline Diagram

```
┌─────────────┐
│   GitHub    │
│  Repository │
└──────┬──────┘
       │
       │ Push/PR
       ▼
┌─────────────┐
│   GitHub    │
│   Actions   │
└──────┬──────┘
       │
       ├──────────────┬──────────────┬──────────────┐
       │              │              │              │
       ▼              ▼              ▼              ▼
  ┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐
  │ Format │    │ Test   │    │Security│    │ Build  │
  │ Check  │    │ TF     │    │ Scan   │    │Container│
  └────────┘    └────────┘    └────────┘    └───┬────┘
                                                  │
                                                  ▼
                                            ┌─────────┐
                                            │   ECR   │
                                            └────┬────┘
                                                 │
                                                 ▼
                                            ┌─────────┐
                                            │   ECS   │
                                            │ Service │
                                            └─────────┘
```

## Future Enhancements

Potential architecture improvements:

1. **HTTPS/SSL**: ACM certificate on ALB
2. **WAF**: Web Application Firewall on ALB
3. **Private Subnets**: Move ECS tasks to private subnets with NAT Gateway
4. **Database**: Add RDS (PostgreSQL/MySQL) with Multi-AZ
5. **Caching**: ElastiCache (Redis) for session/data caching
6. **CDN**: CloudFront for static assets
7. **Secrets**: AWS Secrets Manager for sensitive data
8. **Backup**: AWS Backup for automated backups
9. **Monitoring**: X-Ray for distributed tracing
10. **DNS**: Route 53 for custom domain

## Resource Tagging Strategy

All resources include these tags:
- `Project`: Project name
- `Environment`: dev/staging/prod
- `ManagedBy`: Terraform
- `Owner`: Team or individual owner

This enables:
- Cost allocation and tracking
- Resource organization
- Automated operations
- Compliance reporting
