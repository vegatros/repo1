data "aws_caller_identity" "current" {}

# --- VPC ---
module "vpc" {
  source               = "../../../../modules/network/vpc"
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  azs                  = ["${var.aws_region}a"]
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  enable_nat_gateway   = false
  enable_flow_logs     = true
  flow_logs_retention_days = 7
}

# --- Security Groups ---
resource "aws_security_group" "sagemaker" {
  name_prefix = "${var.project_name}-sm-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [aws_vpc_endpoint.s3.prefix_list_id]
  }

  tags = { Name = "${var.project_name}-sagemaker-sg" }
}

resource "aws_security_group" "endpoints" {
  name_prefix = "${var.project_name}-vpce-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${var.project_name}-endpoints-sg" }
}

# --- VPC Endpoints ---
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = { Name = "${var.project_name}-s3-endpoint" }
}

resource "aws_vpc_endpoint" "sagemaker_api" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.sagemaker.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.project_name}-sagemaker-api" }
}

resource "aws_vpc_endpoint" "sagemaker_runtime" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.sagemaker.runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.project_name}-sagemaker-runtime" }
}

resource "aws_vpc_endpoint" "sts" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.project_name}-sts" }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.project_name}-logs" }
}

# --- S3 Bucket for Pipeline Data ---
resource "aws_s3_bucket" "pipeline" {
  bucket = "${var.project_name}-${data.aws_caller_identity.current.account_id}"

  tags = { Name = "${var.project_name}-data" }
}

resource "aws_s3_bucket_versioning" "pipeline" {
  bucket = aws_s3_bucket.pipeline.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline" {
  bucket = aws_s3_bucket.pipeline.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "pipeline" {
  bucket                  = aws_s3_bucket.pipeline.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- SageMaker Execution Role ---
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
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.pipeline.arn,
          "${aws_s3_bucket.pipeline.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreateTrainingJob",
          "sagemaker:CreateProcessingJob",
          "sagemaker:CreateModel",
          "sagemaker:CreateEndpointConfig",
          "sagemaker:CreateEndpoint",
          "sagemaker:DescribeTrainingJob",
          "sagemaker:DescribeProcessingJob",
          "sagemaker:DescribeEndpoint",
          "sagemaker:DescribeModel",
          "sagemaker:ListTags",
          "sagemaker:AddTags"
        ]
        Resource = "arn:aws:sagemaker:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/sagemaker/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:CreateNetworkInterfacePermission",
          "ec2:DeleteNetworkInterface",
          "ec2:DeleteNetworkInterfacePermission",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeVpcs",
          "ec2:DescribeDhcpOptions",
          "ec2:DescribeSubnets",
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
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:*:repository/*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-execution-role"
        Condition = {
          StringEquals = { "iam:PassedToService" = "sagemaker.amazonaws.com" }
        }
      }
    ]
  })
}

# --- SageMaker Pipeline ---
resource "aws_sagemaker_pipeline" "main" {
  pipeline_name         = "${var.project_name}-pipeline"
  pipeline_display_name = "${var.project_name}-pipeline"
  role_arn              = aws_iam_role.sagemaker.arn

  pipeline_definition = jsonencode({
    Version = "2020-12-01"
    Metadata = {}
    Parameters = [
      {
        Name         = "InputData"
        Type         = "String"
        DefaultValue = "s3://${aws_s3_bucket.pipeline.id}/input"
      },
      {
        Name         = "OutputData"
        Type         = "String"
        DefaultValue = "s3://${aws_s3_bucket.pipeline.id}/output"
      }
    ]
    Steps = [
      {
        Name = "Preprocess"
        Type = "Processing"
        Arguments = {
          ProcessingResources = {
            ClusterConfig = {
              InstanceCount  = 1
              InstanceType   = "ml.t3.medium"
              VolumeSizeInGB = 5
            }
          }
          AppSpecification = {
            ImageUri             = "683313688378.dkr.ecr.${var.aws_region}.amazonaws.com/sagemaker-scikit-learn:1.2-1-cpu-py3"
            ContainerEntrypoint  = ["python3", "/opt/ml/processing/code/preprocess.py"]
          }
          RoleArn = aws_iam_role.sagemaker.arn
          ProcessingInputs = [
            {
              InputName = "input"
              S3Input = {
                S3Uri            = { "Get" = "Parameters.InputData" }
                LocalPath        = "/opt/ml/processing/input"
                S3DataType       = "S3Prefix"
                S3InputMode      = "File"
              }
            },
            {
              InputName = "code"
              S3Input = {
                S3Uri            = "s3://${aws_s3_bucket.pipeline.id}/scripts/preprocess.py"
                LocalPath        = "/opt/ml/processing/code"
                S3DataType       = "S3Prefix"
                S3InputMode      = "File"
              }
            }
          ]
          ProcessingOutputConfig = {
            Outputs = [
              {
                OutputName = "output"
                S3Output = {
                  S3Uri       = { "Get" = "Parameters.OutputData" }
                  LocalPath   = "/opt/ml/processing/output"
                  S3UploadMode = "EndOfJob"
                }
              }
            ]
          }
          NetworkConfig = {
            VpcConfig = {
              SecurityGroupIds = [aws_security_group.sagemaker.id]
              Subnets          = module.vpc.private_subnet_ids
            }
          }
        }
      }
    ]
  })

  tags = { Name = "${var.project_name}-pipeline" }
}
