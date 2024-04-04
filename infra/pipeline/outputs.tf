

output "codebuilds3_arn" {
    value = aws_s3_bucket.codebuilds3.arn
  
}

output "codecommit_repo_arn" {
    value = aws_codecommit_repository.apprepo.arn
}