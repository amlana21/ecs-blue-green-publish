data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}


resource "aws_codecommit_repository" "apprepo" {
  repository_name = "App_Repository"
  description     = "This is the Sample App Repository"
}

resource "aws_ecr_repository" "appimagerepo" {
  name                 = "appimagerepo"
  image_tag_mutability = "MUTABLE"
}


resource "aws_s3_bucket" "codebuilds3" {
  bucket = "<bucket_name>"
}




# --------------------------------codebuild project--------------------------------
resource "aws_codebuild_project" "bluegreenbuild" {
  name          = "bluegreenbuild-project"
  description   = "bluegreenbuild"
  build_timeout = 5
  service_role  = var.codebuild_role_arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type     = "S3"
    location = aws_s3_bucket.codebuilds3.bucket
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "REPOSITORY_URI"
      value = aws_ecr_repository.appimagerepo.repository_url
    }

    environment_variable {
      name  = "TASK_EXECUTION_ARN"
      value = var.task_execution_role_arn
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "bluegreen-log-group"
      stream_name = "bluegreen-log-stream"
    }

    s3_logs {
      status   = "ENABLED"
      location = "${aws_s3_bucket.codebuilds3.id}/build-log"
    }
  }

  source {
    type            = "CODECOMMIT"
    location        = aws_codecommit_repository.apprepo.clone_url_http
    git_clone_depth = 1

    git_submodules_config {
      fetch_submodules = true
    }
  }

  source_version = "master"


  tags = {
    Project = "BlueGreenBlog"
  }
}


# --------------------------------code deploy--------------------------------

resource "aws_codedeploy_app" "bluegreenapp" {
  compute_platform = "ECS"
  name             = "bluegreenapp"
}

resource "aws_codedeploy_deployment_group" "ecs_deployment_group" {
  app_name               = aws_codedeploy_app.bluegreenapp.name
  deployment_group_name  = "app-deployment-group"
  service_role_arn       = var.codedeploy_service_role_arn
  deployment_config_name = "CodeDeployDefault.ECSLinear10PercentEvery1Minutes"

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM", "DEPLOYMENT_STOP_ON_REQUEST"]
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  ecs_service {
    cluster_name = var.ecs_cluster_name
    service_name = var.ecs_service_name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [var.blue_listener_arn]
      }

      target_group {
        name = var.blue_target_group_name
      }

      target_group {
        name = var.green_target_group_name
      }

      test_traffic_route {
        listener_arns = [var.green_listener_arn]
      }
    }
  }

  alarm_configuration {
    alarms = ["blueUnhealthyHostAlarm","blue5xxAlarm","greenUnhealthyHostAlarm","green5xxAlarm" ]
    enabled = true
  }
}


# -----------------cloudwatch metrics and alarms---------------

resource "aws_cloudwatch_metric_alarm" "blue_unhealthy_host" {
  alarm_name          = "blueUnhealthyHostAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric checks for unhealthy hosts in the blue target group"
  alarm_actions       = []
  dimensions = {
    LoadBalancer = var.lb_name
    TargetGroup  = var.blue_target_group_name
  }
}

resource "aws_cloudwatch_metric_alarm" "blue_5xx" {
  alarm_name          = "blue5xxAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric checks for 5xx errors in the blue target group"
  alarm_actions       = []
  dimensions = {
    LoadBalancer = var.lb_name
    TargetGroup  = var.blue_target_group_name
  }
}

resource "aws_cloudwatch_metric_alarm" "green_unhealthy_host" {
  alarm_name          = "greenUnhealthyHostAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "SampleCount"
  threshold           = "1"
  alarm_description   = "This metric checks for unhealthy hosts in the green target group"
  alarm_actions       = []
  dimensions = {
    LoadBalancer = var.lb_name
    TargetGroup  = var.green_target_group_name
  }
}

resource "aws_cloudwatch_metric_alarm" "green_5xx" {
  alarm_name          = "green5xxAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric checks for 5xx errors in the green target group"
  alarm_actions       = []
  dimensions = {
    LoadBalancer = var.lb_name
    TargetGroup  = var.green_target_group_name
  }
}



# -----------artifact bucket----------------
resource "aws_s3_bucket" "artifacts_bucket" {
  bucket = "<bucket_name>"
  
}

resource "aws_s3_bucket_policy" "artifacts_bucket_policy" {
  bucket = aws_s3_bucket.artifacts_bucket.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "s3:PutObject",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      },
      "Effect": "Deny",
      "Principal": {
        "AWS": "*"
      },
      "Resource": "${aws_s3_bucket.artifacts_bucket.arn}/*"
    },
    {
      "Action": "s3:*",
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      },
      "Effect": "Deny",
      "Principal": {
        "AWS": "*"
      },
      "Resource": "${aws_s3_bucket.artifacts_bucket.arn}/*"
    }
  ]
}
POLICY
}


# ---------------------codepipeline---------------------
resource "aws_codepipeline" "ecs_blue_green" {
  name     = "app-pipeline"
  role_arn = var.code_pipeline_role

  artifact_store {
    location = aws_s3_bucket.artifacts_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      role_arn = var.code_pipeline_source_role
      run_order = 1
      output_artifacts = ["sourceArtifact"]
      configuration = {
        RepositoryName         = aws_codecommit_repository.apprepo.repository_name
        BranchName             = "master"
        PollForSourceChanges   = false
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      role_arn = var.code_pipeline_build_role
      run_order = 1
      input_artifacts  = ["sourceArtifact"]
      output_artifacts = ["buildArtifact"]
      configuration = {
        ProjectName = aws_codebuild_project.bluegreenbuild.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"
      input_artifacts = ["buildArtifact"]
      role_arn = var.code_pipeline_deploy_role
      run_order = 1
      configuration = {
        ApplicationName              = aws_codedeploy_app.bluegreenapp.name
        DeploymentGroupName          = aws_codedeploy_deployment_group.ecs_deployment_group.deployment_group_name
        TaskDefinitionTemplateArtifact = "buildArtifact"
        TaskDefinitionTemplatePath   = "taskdef.json"
        AppSpecTemplateArtifact      = "buildArtifact"
        AppSpecTemplatePath          = "appspec.yaml"
      }
    }
  }
}



resource "aws_cloudwatch_event_rule" "code_event_rule" {
  name        = "code_event_rule"
  description = "Event rule for CodeCommit Repository State Change"

  event_pattern = <<PATTERN
{
  "source": ["aws.codecommit"],
  "resources": ["arn:${data.aws_partition.current.partition}:codecommit:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_codecommit_repository.apprepo.repository_name}"],
  "detail-type": ["CodeCommit Repository State Change"],
  "detail": {
    "event": ["referenceCreated", "referenceUpdated"],
    "referenceName": ["main"]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "code_event_target" {
  rule      = aws_cloudwatch_event_rule.code_event_rule.name
  target_id = "Target0"
  arn       = "arn:${data.aws_partition.current.partition}:codepipeline:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_codepipeline.ecs_blue_green.name}"
  role_arn  = var.events_role_arn
}