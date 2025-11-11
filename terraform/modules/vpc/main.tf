resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Enable network address usage metrics for better monitoring
  enable_network_address_usage_metrics = true

  # Assign generated IPv6 CIDR block (optional, disabled by default)
  # assign_generated_ipv6_cidr_block = false

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-vpc"
    }
  )
}

# VPC Flow Logs - DISABLED for cost savings in dev
# Uncomment for production environments
# Cost: ~$10-30/month depending on traffic volume
#
# resource "aws_flow_log" "main" {
#   vpc_id               = aws_vpc.main.id
#   traffic_type         = "ALL"
#   iam_role_arn         = aws_iam_role.flow_logs.arn
#   log_destination_type = "cloud-watch-logs"
#   log_destination      = aws_cloudwatch_log_group.flow_logs.arn
#
#   tags = merge(
#     var.tags,
#     {
#       Name = "${var.project_name}-vpc-flow-logs"
#     }
#   )
# }
#
# resource "aws_cloudwatch_log_group" "flow_logs" {
#   name              = "/aws/vpc/${var.project_name}"
#   retention_in_days = 7
#
#   tags = merge(
#     var.tags,
#     {
#       Name = "${var.project_name}-vpc-flow-logs"
#     }
#   )
# }
#
# resource "aws_iam_role" "flow_logs" {
#   name = "${var.project_name}-vpc-flow-logs-role"
#
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "vpc-flow-logs.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })
#
#   tags = var.tags
# }
#
# resource "aws_iam_role_policy" "flow_logs" {
#   name = "${var.project_name}-vpc-flow-logs-policy"
#   role = aws_iam_role.flow_logs.id
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents",
#           "logs:DescribeLogGroups",
#           "logs:DescribeLogStreams"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-igw"
    }
  )
}

resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)  # /20 -> /24 subnets (256 IPs each)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-public-subnet-${count.index + 1}"
      Type = "Public"
    }
  )
}

# Network ACL for public subnets (defense in depth)
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  # Allow inbound HTTP
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Allow inbound HTTPS
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow inbound ephemeral ports (for return traffic)
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow all outbound traffic
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-public-nacl"
    }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-public-rt"
    }
  )
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
