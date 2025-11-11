#!/usr/bin/env bash

# Requirement: Use Python or Bash. Show GitHub Actions execution history via GitHub API.
# Audit the encryption details and logging configuration of all S3 buckets in your account.
# Audit all IAM roles in your account that have been used within a specific period of time, and report which services those roles have used.
# Generate a report of all CloudWatch Log Groups in your account and show how much data each has ingested in a period of time.
# List all resources of a specific service, grouped by resource type, and sorted alphabetically by resource type then resource name.

#==============================================================================
# Cloud Audit Toolkit
# A comprehensive script for auditing GitHub Actions, AWS S3, IAM, CloudWatch,
# and other cloud resources.
#==============================================================================

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly OUTPUT_DIR="${SCRIPT_DIR}/audit-reports"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

#==============================================================================
# Utility Functions
#==============================================================================

print_header() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "Required command '$1' not found. Please install it first."
        exit 1
    fi
}

setup_output_dir() {
    mkdir -p "${OUTPUT_DIR}"
    print_success "Output directory: ${OUTPUT_DIR}"
}

#==============================================================================
# GitHub Actions History
#==============================================================================

github_actions_history() {
    print_header "GitHub Actions - Execution History"

    check_command "jq"
    check_command "gh"

    # Check GitHub CLI authentication status
    print_info "Checking GitHub authentication..."

    if ! gh auth status > /dev/null 2>&1; then
        print_warning "Not authenticated with GitHub CLI"
        print_info "Starting GitHub authentication process..."

        if ! gh auth login; then
            print_error "GitHub authentication failed"
            return 1
        fi

        print_success "Successfully authenticated with GitHub"
    else
        print_success "Already authenticated with GitHub"
    fi

    # Fetch repositories and let user choose
    print_info "Fetching your repositories..."

    local repos
    repos=$(gh repo list --limit 100 --json nameWithOwner --jq '.[].nameWithOwner' 2>&1)

    if [[ -z "$repos" ]]; then
        print_error "No repositories found or failed to fetch"
        return 1
    fi

    # Display repos in a numbered list
    echo ""
    echo "Available repositories:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local repo_array=()
    local index=1

    while IFS= read -r repo_name; do
        echo "  ${index}) ${repo_name}"
        repo_array+=("$repo_name")
        ((index++))
    done <<< "$repos"

    echo "  0) Enter repository manually"
    echo ""

    # Get user selection
    read -rp "Select repository [0-$((index-1))]: " selection

    local repo
    if [[ "$selection" == "0" ]]; then
        read -rp "Enter GitHub repository (format: owner/repo): " repo
        if [[ -z "$repo" ]]; then
            print_error "Repository name cannot be empty"
            return 1
        fi
    elif [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -lt "$index" ]]; then
        repo="${repo_array[$((selection-1))]}"
        print_info "Selected: ${repo}"
    else
        print_error "Invalid selection"
        return 1
    fi

    local output_file="${OUTPUT_DIR}/github_actions_${repo//\//_}_${TIMESTAMP}.json"
    local report_file="${OUTPUT_DIR}/github_actions_${repo//\//_}_${TIMESTAMP}.txt"

    print_info "Fetching workflow runs for ${repo}..."

    local response
    response=$(gh api repos/${repo}/actions/runs?per_page=100 2>&1)

    echo "$response" > "$output_file"

    # Check if we got valid data
    if echo "$response" | jq -e '.workflow_runs' > /dev/null 2>&1; then
        # Generate readable report
        {
            echo "GitHub Actions Execution History"
            echo "Repository: ${repo}"
            echo "Generated: $(date)"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""

            echo "$response" | jq -r '
                .workflow_runs[] |
                "ID:         \(.id)\n" +
                "Workflow:   \(.name)\n" +
                "Status:     \(.status)\n" +
                "Conclusion: \(.conclusion // "N/A")\n" +
                "Branch:     \(.head_branch)\n" +
                "Actor:      \(.actor.login)\n" +
                "Created:    \(.created_at)\n" +
                "Updated:    \(.updated_at)\n" +
                "URL:        \(.html_url)\n" +
                "────────────────────────────────────────────────────────────────────\n"
            '
        } > "$report_file"

        print_success "Raw data saved to: ${output_file}"
        print_success "Report saved to: ${report_file}"

        local total_runs
        total_runs=$(echo "$response" | jq '.workflow_runs | length')
        print_info "Total runs retrieved: ${total_runs}"
    else
        print_error "Failed to fetch workflow runs. Check your token and repository name."
        print_info "Response: ${response}"
        return 1
    fi
}

#==============================================================================
# S3 Bucket Audit
#==============================================================================

audit_s3_buckets() {
    print_header "AWS S3 - Encryption & Logging Audit"

    check_command "aws"
    check_command "jq"

    local output_file="${OUTPUT_DIR}/s3_audit_${TIMESTAMP}.txt"

    print_info "Fetching S3 bucket list..."

    local buckets
    buckets=$(aws s3api list-buckets --query 'Buckets[].Name' --output text)

    if [[ -z "$buckets" ]]; then
        print_warning "No S3 buckets found"
        return 0
    fi

    {
        echo "S3 Bucket Encryption & Logging Audit"
        echo "Generated: $(date)"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        for bucket in $buckets; do
            echo "Bucket: ${bucket}"
            echo "────────────────────────────────────────────────────────────────────"

            # Get region
            local region
            region=$(aws s3api get-bucket-location --bucket "$bucket" --query 'LocationConstraint' --output text 2>/dev/null || echo "us-east-1")
            [[ "$region" == "None" || "$region" == "null" ]] && region="us-east-1"
            echo "Region: ${region}"

            # Check encryption
            echo ""
            echo "Encryption Configuration:"
            local encryption
            encryption=$(aws s3api get-bucket-encryption --bucket "$bucket" 2>&1 || echo "No encryption configured")

            if echo "$encryption" | grep -q "ServerSideEncryptionConfiguration"; then
                echo "$encryption" | jq -r '.ServerSideEncryptionConfiguration.Rules[] |
                    "  • Algorithm: \(.ApplyServerSideEncryptionByDefault.SSEAlgorithm)\n" +
                    "  • KMS Master Key: \(.ApplyServerSideEncryptionByDefault.KMSMasterKeyID // "N/A")\n" +
                    "  • Bucket Key Enabled: \(.BucketKeyEnabled // false)"'
            else
                echo "  ⚠ No encryption configured"
            fi

            # Check logging
            echo ""
            echo "Logging Configuration:"
            local logging
            logging=$(aws s3api get-bucket-logging --bucket "$bucket" 2>&1)

            if echo "$logging" | jq -e '.LoggingEnabled' > /dev/null 2>&1; then
                echo "$logging" | jq -r '.LoggingEnabled |
                    "  • Target Bucket: \(.TargetBucket)\n" +
                    "  • Target Prefix: \(.TargetPrefix)"'
            else
                echo "  ⚠ No logging configured"
            fi

            # Check versioning
            echo ""
            echo "Versioning:"
            local versioning
            versioning=$(aws s3api get-bucket-versioning --bucket "$bucket" --query 'Status' --output text 2>/dev/null || echo "Disabled")
            echo "  • Status: ${versioning}"

            # Check public access block
            echo ""
            echo "Public Access Block:"
            local public_access
            public_access=$(aws s3api get-public-access-block --bucket "$bucket" 2>&1)

            if echo "$public_access" | jq -e '.PublicAccessBlockConfiguration' > /dev/null 2>&1; then
                echo "$public_access" | jq -r '.PublicAccessBlockConfiguration |
                    "  • Block Public ACLs: \(.BlockPublicAcls)\n" +
                    "  • Ignore Public ACLs: \(.IgnorePublicAcls)\n" +
                    "  • Block Public Policy: \(.BlockPublicPolicy)\n" +
                    "  • Restrict Public Buckets: \(.RestrictPublicBuckets)"'
            else
                echo "  ⚠ No public access block configured"
            fi

            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
        done
    } > "$output_file"

    print_success "Audit report saved to: ${output_file}"
}

#==============================================================================
# IAM Role Audit
#==============================================================================

audit_iam_roles() {
    print_header "AWS IAM - Role Usage Audit"

    check_command "aws"
    check_command "jq"

    read -rp "Enter number of days to look back (default: 90): " days
    days=${days:-90}

    local cutoff_date
    cutoff_date=$(date -u -v-"${days}"d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "${days} days ago" +%Y-%m-%dT%H:%M:%SZ)

    local output_file="${OUTPUT_DIR}/iam_roles_audit_${TIMESTAMP}.txt"

    print_info "Analyzing IAM roles used in the last ${days} days..."

    local roles
    roles=$(aws iam list-roles --query 'Roles[].RoleName' --output text)

    {
        echo "IAM Role Usage Audit"
        echo "Generated: $(date)"
        echo "Period: Last ${days} days (since ${cutoff_date})"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        local used_count=0
        local unused_count=0

        for role in $roles; do
            local role_data
            role_data=$(aws iam get-role --role-name "$role" 2>/dev/null || continue)

            local last_used
            last_used=$(echo "$role_data" | jq -r '.Role.RoleLastUsed.LastUsedDate // empty')

            if [[ -n "$last_used" ]] && [[ "$last_used" > "$cutoff_date" ]]; then
                ((used_count++))

                echo "Role: ${role}"
                echo "────────────────────────────────────────────────────────────────────"
                echo "Last Used: ${last_used}"

                local region
                region=$(echo "$role_data" | jq -r '.Role.RoleLastUsed.Region // "N/A"')
                echo "Region: ${region}"

                # Get services from assume role policy
                echo ""
                echo "Trusted Services/Principals:"
                echo "$role_data" | jq -r '.Role.AssumeRolePolicyDocument.Statement[] |
                    if .Principal.Service then
                        "  • Service: \(.Principal.Service)"
                    elif .Principal.AWS then
                        "  • AWS Account/Role: \(.Principal.AWS)"
                    elif .Principal.Federated then
                        "  • Federated: \(.Principal.Federated)"
                    else
                        "  • Other principal type"
                    end'

                # Get attached policies
                echo ""
                echo "Attached Policies:"
                aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyName' --output text | \
                    tr '\t' '\n' | sed 's/^/  • /'

                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
            else
                ((unused_count++))
            fi
        done

        echo ""
        echo "Summary"
        echo "────────────────────────────────────────────────────────────────────"
        echo "Roles used in last ${days} days: ${used_count}"
        echo "Roles not used in last ${days} days: ${unused_count}"

    } > "$output_file"

    print_success "Audit report saved to: ${output_file}"
}

#==============================================================================
# CloudWatch Log Groups Report
#==============================================================================

cloudwatch_log_report() {
    print_header "AWS CloudWatch - Log Groups Ingestion Report"

    check_command "aws"
    check_command "jq"

    read -rp "Enter number of days to analyze (default: 7): " days
    days=${days:-7}

    local start_time
    local end_time
    start_time=$(($(date +%s) - (days * 86400)))
    end_time=$(date +%s)

    start_time=$((start_time * 1000))  # Convert to milliseconds
    end_time=$((end_time * 1000))

    local output_file="${OUTPUT_DIR}/cloudwatch_logs_${TIMESTAMP}.txt"

    print_info "Fetching CloudWatch Log Groups..."

    local log_groups
    log_groups=$(aws logs describe-log-groups --query 'logGroups[].logGroupName' --output text)

    if [[ -z "$log_groups" ]]; then
        print_warning "No CloudWatch Log Groups found"
        return 0
    fi

    {
        echo "CloudWatch Log Groups Ingestion Report"
        echo "Generated: $(date)"
        echo "Period: Last ${days} days"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # Use a temp file for storing data (compatible with bash 3.2)
        local temp_data=$(mktemp)
        trap "rm -f $temp_data" EXIT

        for log_group in $log_groups; do
            print_info "Processing: ${log_group}"

            local group_info
            group_info=$(aws logs describe-log-groups --log-group-name-prefix "$log_group" --query 'logGroups[0]')

            local stored_bytes
            stored_bytes=$(echo "$group_info" | jq -r '.storedBytes // 0')

            local retention
            retention=$(echo "$group_info" | jq -r '.retentionInDays // "Never expire"')

            # Try to get metrics
            local ingested_bytes=0

            # Store data for sorting (format: stored_bytes|retention|ingested_bytes|log_group_name)
            echo "${stored_bytes}|${retention}|${ingested_bytes}|${log_group}" >> "$temp_data"
        done

        # Sort by stored bytes (descending) and display
        sort -t'|' -k1 -rn "$temp_data" | while IFS='|' read -r stored retention ingested name; do
            echo "Log Group: ${name}"
            echo "────────────────────────────────────────────────────────────────────"

            # Convert bytes to human readable
            local stored_hr
            if [[ $stored -ge 1073741824 ]]; then
                stored_hr=$(awk "BEGIN {printf \"%.2f GB\", $stored/1073741824}")
            elif [[ $stored -ge 1048576 ]]; then
                stored_hr=$(awk "BEGIN {printf \"%.2f MB\", $stored/1048576}")
            elif [[ $stored -ge 1024 ]]; then
                stored_hr=$(awk "BEGIN {printf \"%.2f KB\", $stored/1024}")
            else
                stored_hr="${stored} bytes"
            fi

            echo "Stored Data: ${stored_hr}"
            echo "Retention: ${retention} days"
            echo ""
        done

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    } > "$output_file"

    print_success "Report saved to: ${output_file}"
}

#==============================================================================
# AWS Resource Listing
#==============================================================================

list_aws_resources() {
    print_header "AWS Resources - Service Inventory"

    check_command "aws"
    check_command "jq"

    echo "Available services:"
    echo "  1) EC2 Instances"
    echo "  2) RDS Databases"
    echo "  3) Lambda Functions"
    echo "  4) S3 Buckets"
    echo "  5) DynamoDB Tables"
    echo "  6) ECS Clusters & Services"
    echo "  7) All of the above"
    echo ""

    read -rp "Select service (1-7): " service_choice

    local output_file="${OUTPUT_DIR}/aws_resources_${TIMESTAMP}.txt"

    {
        echo "AWS Resources Inventory"
        echo "Generated: $(date)"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # Determine which services to run
        local run_ec2=0 run_rds=0 run_lambda=0 run_s3=0 run_dynamodb=0 run_ecs=0

        case $service_choice in
            1) run_ec2=1 ;;
            2) run_rds=1 ;;
            3) run_lambda=1 ;;
            4) run_s3=1 ;;
            5) run_dynamodb=1 ;;
            6) run_ecs=1 ;;
            7) run_ec2=1; run_rds=1; run_lambda=1; run_s3=1; run_dynamodb=1; run_ecs=1 ;;
            *)
                print_error "Invalid selection"
                return 1
                ;;
        esac

        # EC2 Instances
        if [[ $run_ec2 -eq 1 ]]; then
            echo "═══ EC2 INSTANCES ═══"
            echo ""
            aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`].Value|[0]]' --output text | \
                sort -k2,2 -k1,1 | \
                awk 'BEGIN {print "Resource Type: EC2 Instance\n"} {printf "  • %s (%s) - %s - %s\n", $1, $2, $3, ($4 ? $4 : "No Name")}'
            echo ""
        fi

        # RDS Databases
        if [[ $run_rds -eq 1 ]]; then
            echo "═══ RDS DATABASES ═══"
            echo ""
            aws rds describe-db-instances --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceClass,Engine,DBInstanceStatus]' --output text | \
                sort -k2,2 -k1,1 | \
                awk 'BEGIN {print "Resource Type: RDS Instance\n"} {printf "  • %s (%s) - %s - %s\n", $1, $2, $3, $4}'
            echo ""
        fi

        # Lambda Functions
        if [[ $run_lambda -eq 1 ]]; then
            echo "═══ LAMBDA FUNCTIONS ═══"
            echo ""
            aws lambda list-functions --query 'Functions[].[FunctionName,Runtime,MemorySize]' --output text | \
                sort -k2,2 -k1,1 | \
                awk 'BEGIN {print "Resource Type: Lambda Function\n"} {printf "  • %s - %s (%sMB)\n", $1, $2, $3}'
            echo ""
        fi

        # S3 Buckets
        if [[ $run_s3 -eq 1 ]]; then
            echo "═══ S3 BUCKETS ═══"
            echo ""
            aws s3api list-buckets --query 'Buckets[].[Name,CreationDate]' --output text | \
                sort -k1,1 | \
                awk 'BEGIN {print "Resource Type: S3 Bucket\n"} {printf "  • %s (created: %s)\n", $1, $2}'
            echo ""
        fi

        # DynamoDB Tables
        if [[ $run_dynamodb -eq 1 ]]; then
            echo "═══ DYNAMODB TABLES ═══"
            echo ""
            aws dynamodb list-tables --query 'TableNames[]' --output text | \
                tr '\t' '\n' | sort | \
                awk 'BEGIN {print "Resource Type: DynamoDB Table\n"} {printf "  • %s\n", $0}'
            echo ""
        fi

        # ECS Clusters
        if [[ $run_ecs -eq 1 ]]; then
            echo "═══ ECS CLUSTERS ═══"
            echo ""
            echo "Resource Type: ECS Cluster"
            echo ""
            local clusters
            clusters=$(aws ecs list-clusters --query 'clusterArns[]' --output text)

            for cluster in $clusters; do
                local cluster_name
                cluster_name=$(basename "$cluster")
                echo "  • ${cluster_name}"

                # List services in cluster
                local services
                services=$(aws ecs list-services --cluster "$cluster_name" --query 'serviceArns[]' --output text)

                if [[ -n "$services" ]]; then
                    echo "    Services:"
                    for service in $services; do
                        echo "      - $(basename "$service")"
                    done
                fi
            done
            echo ""
        fi

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    } > "$output_file"

    print_success "Inventory saved to: ${output_file}"
}

#==============================================================================
# Main Menu
#==============================================================================

show_menu() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║              Cloud Audit Toolkit v1.0                        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    echo "Select an audit option:"
    echo ""
    echo "  1) GitHub Actions - Show execution history"
    echo "  2) AWS S3 - Audit encryption & logging"
    echo "  3) AWS IAM - Audit role usage"
    echo "  4) AWS CloudWatch - Log groups ingestion report"
    echo "  5) AWS Resources - List service resources"
    echo "  6) Run all AWS audits"
    echo ""
    echo "  0) Exit"
    echo ""
}

main() {
    setup_output_dir

    while true; do
        show_menu
        read -rp "Enter your choice [0-6]: " choice

        case $choice in
            1)
                github_actions_history
                ;;
            2)
                audit_s3_buckets
                ;;
            3)
                audit_iam_roles
                ;;
            4)
                cloudwatch_log_report
                ;;
            5)
                list_aws_resources
                ;;
            6)
                print_info "Running all AWS audits..."
                audit_s3_buckets
                audit_iam_roles
                cloudwatch_log_report
                list_aws_resources
                ;;
            0)
                print_info "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please try again."
                ;;
        esac

        echo ""
        read -rp "Press Enter to continue..."
    done
}

# Run main menu if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
