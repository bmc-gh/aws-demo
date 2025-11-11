run "verify_kms_key_creation" {
  command = plan

  variables {
    key_name    = "test-key"
    description = "Test KMS key"
  }

  # Verify KMS key is created
  assert {
    condition     = aws_kms_key.main.description == var.description
    error_message = "KMS key description should match the provided value"
  }

  # Verify key rotation is enabled
  assert {
    condition     = aws_kms_key.main.enable_key_rotation == true
    error_message = "KMS key rotation should be enabled"
  }

  # Verify alias is created
  assert {
    condition     = aws_kms_alias.main.name == "alias/${var.key_name}"
    error_message = "KMS alias should be correctly formatted"
  }
}

run "verify_kms_key_deletion_window" {
  command = plan

  variables {
    key_name                = "test-key"
    description             = "Test KMS key"
    deletion_window_in_days = 30
  }

  assert {
    condition     = aws_kms_key.main.deletion_window_in_days == var.deletion_window_in_days
    error_message = "KMS key deletion window should match configured value"
  }
}
