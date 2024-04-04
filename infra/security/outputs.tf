output "task_execution_role_arn" {
    value = aws_iam_role.ecs_task_execution_role.arn
}

output "codebuild_assume_role_arn" {
    value = aws_iam_role.codebuildrole.arn
}

output "codedeploy_service_role_arn" {
    value = aws_iam_role.code_deploy_service_role.arn
}


output "codepipeline_default_role_arn" {
    value = aws_iam_role.codepipeline_default_role.arn
}

output "codepipeline_build_role_arn" {
    value = aws_iam_role.build_code_pipeline_action_role.arn
}

output "codepipeline_source_role_arn" {
    value = aws_iam_role.source_code_pipeline_action_role.arn
}

output "codepipeline_deploy_role_arn" {
    value = aws_iam_role.deploy_code_pipeline_action_role.arn
}

output "events_role_arn" {
    value = aws_iam_role.ecs_blue_green_events_role.arn
}