output "bucket_name" {
  value = aws_s3_bucket.vault.id
}

output "access_key_id" {
  value = aws_iam_access_key.obsidian.id
}

output "secret_access_key" {
  value     = aws_iam_access_key.obsidian.secret
  sensitive = true
}
