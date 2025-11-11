run "verify_s3_bucket_configuration" {
  command = plan

  variables {
    bucket_name = "test-bucket-12345"
    tags = {
      Environment = "test"
    }
  }

  # Verify bucket is created
  assert {
    condition     = aws_s3_bucket.main.bucket == var.bucket_name
    error_message = "Bucket name does not match expected value"
  }

  # Verify versioning is enabled
  assert {
    condition     = aws_s3_bucket_versioning.main.versioning_configuration[0].status == "Enabled"
    error_message = "S3 bucket versioning should be enabled"
  }

  # Verify encryption is configured
  assert {
    condition     = aws_s3_bucket_server_side_encryption_configuration.main.rule[0].apply_server_side_encryption_by_default[0].sse_algorithm != null
    error_message = "S3 bucket encryption should be configured"
  }

  # Verify public access is blocked
  assert {
    condition = (
      aws_s3_bucket_public_access_block.main.block_public_acls == true &&
      aws_s3_bucket_public_access_block.main.block_public_policy == true &&
      aws_s3_bucket_public_access_block.main.ignore_public_acls == true &&
      aws_s3_bucket_public_access_block.main.restrict_public_buckets == true
    )
    error_message = "All public access should be blocked"
  }
}

run "verify_s3_bucket_with_kms" {
  command = plan

  variables {
    bucket_name = "test-bucket-kms-12345"
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  }

  assert {
    condition     = aws_s3_bucket_server_side_encryption_configuration.main.rule[0].apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"
    error_message = "S3 bucket should use KMS encryption when KMS key ARN is provided"
  }

  assert {
    condition     = aws_s3_bucket_server_side_encryption_configuration.main.rule[0].apply_server_side_encryption_by_default[0].kms_master_key_id == var.kms_key_arn
    error_message = "S3 bucket should use the provided KMS key"
  }
}
