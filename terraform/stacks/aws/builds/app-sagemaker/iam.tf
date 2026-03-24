data "aws_caller_identity" "current" {}

resource "aws_iam_role" "sagemaker" {
  name = "${var.project_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "sagemaker" {
  name = "${var.project_name}-policy"
  role = aws_iam_role.sagemaker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject",
          "s3:ListBucket", "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.pipeline.arn,
          "${aws_s3_bucket.pipeline.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreateTrainingJob", "sagemaker:DescribeTrainingJob",
          "sagemaker:CreateProcessingJob", "sagemaker:DescribeProcessingJob",
          "sagemaker:CreateModel", "sagemaker:DescribeModel",
          "sagemaker:CreateEndpointConfig", "sagemaker:CreateEndpoint",
          "sagemaker:DescribeEndpoint", "sagemaker:UpdateEndpoint",
          "sagemaker:DeleteEndpoint", "sagemaker:DeleteEndpointConfig",
          "sagemaker:DeleteModel", "sagemaker:CreateModelPackage",
          "sagemaker:DescribeModelPackage", "sagemaker:UpdateModelPackage",
          "sagemaker:CreateModelPackageGroup", "sagemaker:DescribeModelPackageGroup",
          "sagemaker:ListTags", "sagemaker:AddTags"
        ]
        Resource = "arn:aws:sagemaker:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/sagemaker/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface", "ec2:CreateNetworkInterfacePermission",
          "ec2:DeleteNetworkInterface", "ec2:DeleteNetworkInterfacePermission",
          "ec2:DescribeNetworkInterfaces", "ec2:DescribeVpcs",
          "ec2:DescribeDhcpOptions", "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:*:repository/*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.sagemaker.arn
        Condition = {
          StringEquals = { "iam:PassedToService" = "sagemaker.amazonaws.com" }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData", "cloudwatch:GetMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "cloudwatch:namespace" = "/aws/sagemaker/Endpoints" }
        }
      }
    ]
  })
}
