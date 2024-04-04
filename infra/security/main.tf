
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy" "CodeDeployAccess" {
  arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# Create an IAM role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}


resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution_role.name
}


data "aws_iam_policy_document" "task_role_policy" {
  statement {
    actions   = ["logs:*","s3:*","dynamodb:*","cloudwatch:*","sns:*","lambda:*","secretsmanager:*","ds:*","ec2:*","ecr:*","ecs:*","iam:*","kms:*","sqs:*","ssm:*","sts:*","es:*"]
    effect   = "Allow"
    resources = ["*"]
  }

}


# -----------------for codebuild
data "aws_iam_policy_document" "codebuildpolicydoc" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codebuildrole" {
  name               = "codebuildrolecust"
  assume_role_policy = data.aws_iam_policy_document.codebuildpolicydoc.json
}

data "aws_iam_policy_document" "codebuildpolicy" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "s3:Get*",
      "s3:List*",
      "s3:PutObject",
      "secretsmanager:GetSecretValue"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "codecommit:GitPull"
    ]

    resources = [var.codecommitarn]
  }

  statement {
    effect = "Allow"

    actions = [
      "codebuild:CreateReportGroup",
      "codebuild:CreateReport",
      "codebuild:UpdateReport",
      "codebuild:BatchPutTestCases",
      "codebuild:BatchPutCodeCoverages"
    ]

    resources = ["*"]
  } 

  statement {
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      var.builds3arn,
      "${var.builds3arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "codebuildpolicy" {
  role   = aws_iam_role.codebuildrole.name
  policy = data.aws_iam_policy_document.codebuildpolicy.json
}



# ------------------for codedeploy
resource "aws_iam_role" "code_deploy_service_role" {
  name               = "bgCodeDeployServiceRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "code_deploy_service_role_policy_attachment" {
  role       = aws_iam_role.code_deploy_service_role.name
  policy_arn = "${data.aws_iam_policy.CodeDeployAccess.arn}"
  
}

# ---------------------for codepipeline
resource "aws_iam_policy" "code_pipeline_role_default_policy" {
  name        = "app-pipeline-role-policy"
  description = "Policy for CodePipeline Role"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "iam:PassRole",
        "sts:AssumeRole",
        "codecommit:Get*",
        "codecommit:List*",
        "codecommit:GitPull",
        "codecommit:UploadArchive",
        "codecommit:CancelUploadArchive",
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild",
        "codedeploy:CreateDeployment",
        "codedeploy:Get*",
        "codedeploy:RegisterApplicationRevision",
        "s3:Get*",
        "s3:List*",
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "s3:GetObject*",
        "s3:GetBucket*",
        "s3:List*",
        "s3:DeleteObject*",
        "s3:PutObject",
        "s3:PutObjectLegalHold",
        "s3:PutObjectRetention",
        "s3:PutObjectTagging",
        "s3:PutObjectVersionTagging",
        "s3:Abort*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Resource": "${aws_iam_role.source_code_pipeline_action_role.arn}"
    },
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Resource": "${aws_iam_role.build_code_pipeline_action_role.arn}"
    },
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Resource": "${aws_iam_role.deploy_code_pipeline_action_role.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role" "codepipeline_default_role" {
  name               = "bg-codepipeline-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "code_pipeline_role_policy_attachment" {
  role       = aws_iam_role.codepipeline_default_role.name
  policy_arn = aws_iam_policy.code_pipeline_role_default_policy.arn
}

resource "aws_iam_role" "source_code_pipeline_action_role" {
  name               = "source-code-pipeline-action-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${data.aws_caller_identity.current.account_id}"
      }
    }
  ]
}
EOF
}
resource "aws_iam_policy" "source_code_pipeline_action_role_default_policy" {
  name        = "source-code-pipeline-action-role-policy"
  description = "Policy for Source CodePipeline Action Role"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetObject*",
        "s3:GetBucket*",
        "s3:List*",
        "s3:DeleteObject*",
        "s3:PutObject",
        "s3:PutObjectLegalHold",
        "s3:PutObjectRetention",
        "s3:PutObjectTagging",
        "s3:PutObjectVersionTagging",
        "s3:Abort*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "codecommit:GetBranch",
        "codecommit:GetCommit",
        "codecommit:UploadArchive",
        "codecommit:GetUploadArchiveStatus",
        "codecommit:CancelUploadArchive"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "source_code_pipeline_action_role_policy_attachment" {
  role       = aws_iam_role.source_code_pipeline_action_role.name
  policy_arn = aws_iam_policy.source_code_pipeline_action_role_default_policy.arn
}

resource "aws_iam_policy" "ecs_blue_green_events_role_default_policy" {
  name        = "events-policy"
  description = "Policy for ECS Blue Green Events Role"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "codepipeline:StartPipelineExecution",
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_blue_green_events_role_policy_attachment" {
  role       = aws_iam_role.ecs_blue_green_events_role.name
  policy_arn = aws_iam_policy.ecs_blue_green_events_role_default_policy.arn
}



resource "aws_iam_role" "ecs_blue_green_events_role" {
  name               = "ecs-blue-green-events-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


resource "aws_iam_role" "build_code_pipeline_action_role" {
  name               = "build-code-pipeline-action-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${data.aws_caller_identity.current.account_id}"
      }
    }
  ]
}
EOF
}

resource "aws_iam_policy" "build_code_pipeline_action_role_default_policy" {
  name        = "build-code-pipeline-action-role-policy"
  description = "Policy for Build CodePipeline Action Role"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild",
        "codebuild:StopBuild"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "build_code_pipeline_action_role_policy_attachment" {
  role       = aws_iam_role.build_code_pipeline_action_role.name
  policy_arn = aws_iam_policy.build_code_pipeline_action_role_default_policy.arn
}



resource "aws_iam_role" "deploy_code_pipeline_action_role" {
  name               = "deploy-code-pipeline-action-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${data.aws_caller_identity.current.account_id}"
      }
    }
  ]
}
EOF
}

resource "aws_iam_policy" "deploy_code_pipeline_action_role_default_policy" {
  name        = "deploy-code-pipeline-action-role-policy"
  description = "Policy for Deploy CodePipeline Action Role"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "codedeploy:GetApplication",
        "codedeploy:GetApplicationRevision",
        "codedeploy:RegisterApplicationRevision",
        "codedeploy:CreateDeployment",
        "codedeploy:GetDeployment",
        "codedeploy:GetDeploymentConfig",
        "ecs:RegisterTaskDefinition",
        "iam:PassRole",
        "s3:GetObject*",
        "s3:GetBucket*",
        "s3:List*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": "iam:PassRole",
      "Effect": "Allow",
      "Resource": "*",
      "Condition": {
        "StringEqualsIfExists": {
          "iam:PassedToService": "ecs-tasks.amazonaws.com"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "deploy_code_pipeline_action_role_policy_attachment" {
  role       = aws_iam_role.deploy_code_pipeline_action_role.name
  policy_arn = aws_iam_policy.deploy_code_pipeline_action_role_default_policy.arn
}