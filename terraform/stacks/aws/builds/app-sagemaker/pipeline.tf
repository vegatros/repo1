locals {
  account_id    = data.aws_caller_identity.current.account_id
  sklearn_image = "683313688378.dkr.ecr.${var.aws_region}.amazonaws.com/sagemaker-scikit-learn:1.2-1-cpu-py3"
  xgb_image     = "683313688378.dkr.ecr.${var.aws_region}.amazonaws.com/sagemaker-xgboost:1.7-1"

  vpc_config = {
    SecurityGroupIds = [aws_security_group.sagemaker.id]
    Subnets          = module.vpc.private_subnet_ids
  }
}

resource "aws_sagemaker_pipeline" "main" {
  pipeline_name         = "${var.project_name}-pipeline"
  pipeline_display_name = "${var.project_name}-mlops"
  role_arn              = aws_iam_role.sagemaker.arn

  pipeline_definition = jsonencode({
    Version    = "2020-12-01"
    Metadata   = {}
    Parameters = [
      {
        Name         = "InputData"
        Type         = "String"
        DefaultValue = "s3://${aws_s3_bucket.pipeline.id}/input"
      },
      {
        Name         = "ModelApprovalStatus"
        Type         = "String"
        DefaultValue = "PendingManualApproval"
      },
      {
        Name         = "AccuracyThreshold"
        Type         = "Float"
        DefaultValue = 0.75
      }
    ]

    Steps = [
      # Step 1: Preprocess
      {
        Name = "Preprocess"
        Type = "Processing"
        Arguments = {
          ProcessingResources = {
            ClusterConfig = {
              InstanceCount  = 1
              InstanceType   = var.processing_instance_type
              VolumeSizeInGB = 10
            }
          }
          AppSpecification = {
            ImageUri            = local.sklearn_image
            ContainerEntrypoint = ["python3", "/opt/ml/processing/code/preprocess.py"]
          }
          RoleArn = aws_iam_role.sagemaker.arn
          ProcessingInputs = [
            {
              InputName = "input"
              S3Input = {
                S3Uri       = { "Get" = "Parameters.InputData" }
                LocalPath   = "/opt/ml/processing/input"
                S3DataType  = "S3Prefix"
                S3InputMode = "File"
              }
            },
            {
              InputName = "code"
              S3Input = {
                S3Uri       = "s3://${aws_s3_bucket.pipeline.id}/scripts/preprocess.py"
                LocalPath   = "/opt/ml/processing/code"
                S3DataType  = "S3Prefix"
                S3InputMode = "File"
              }
            }
          ]
          ProcessingOutputConfig = {
            Outputs = [
              {
                OutputName = "train"
                S3Output = {
                  S3Uri        = "s3://${aws_s3_bucket.pipeline.id}/processing/train"
                  LocalPath    = "/opt/ml/processing/output/train"
                  S3UploadMode = "EndOfJob"
                }
              },
              {
                OutputName = "test"
                S3Output = {
                  S3Uri        = "s3://${aws_s3_bucket.pipeline.id}/processing/test"
                  LocalPath    = "/opt/ml/processing/output/test"
                  S3UploadMode = "EndOfJob"
                }
              }
            ]
          }
          NetworkConfig = { VpcConfig = local.vpc_config }
        }
      },

      # Step 2: Train (XGBoost)
      {
        Name      = "Train"
        Type      = "Training"
        DependsOn = ["Preprocess"]
        Arguments = {
          AlgorithmSpecification = {
            TrainingImage     = local.xgb_image
            TrainingInputMode = "File"
          }
          RoleArn = aws_iam_role.sagemaker.arn
          InputDataConfig = [
            {
              ChannelName     = "train"
              ContentType     = "text/csv"
              DataSource = {
                S3DataSource = {
                  S3DataType             = "S3Prefix"
                  S3Uri                  = "s3://${aws_s3_bucket.pipeline.id}/processing/train"
                  S3DataDistributionType = "FullyReplicated"
                }
              }
            },
            {
              ChannelName     = "validation"
              ContentType     = "text/csv"
              DataSource = {
                S3DataSource = {
                  S3DataType             = "S3Prefix"
                  S3Uri                  = "s3://${aws_s3_bucket.pipeline.id}/processing/test"
                  S3DataDistributionType = "FullyReplicated"
                }
              }
            }
          ]
          OutputDataConfig = {
            S3OutputPath = "s3://${aws_s3_bucket.pipeline.id}/models"
          }
          ResourceConfig = {
            InstanceCount  = 1
            InstanceType   = var.training_instance_type
            VolumeSizeInGB = 10
          }
          StoppingCondition = {
            MaxRuntimeInSeconds = 3600
          }
          HyperParameters = {
            objective        = "binary:logistic"
            eval_metric      = "auc"
            num_round        = "100"
            max_depth        = "5"
            eta              = "0.2"
            subsample        = "0.8"
            colsample_bytree = "0.8"
          }
          VpcConfig = local.vpc_config
        }
      },

      # Step 3: Evaluate
      {
        Name      = "Evaluate"
        Type      = "Processing"
        DependsOn = ["Train"]
        Arguments = {
          ProcessingResources = {
            ClusterConfig = {
              InstanceCount  = 1
              InstanceType   = var.processing_instance_type
              VolumeSizeInGB = 10
            }
          }
          AppSpecification = {
            ImageUri            = local.sklearn_image
            ContainerEntrypoint = ["python3", "/opt/ml/processing/code/evaluate.py"]
          }
          RoleArn = aws_iam_role.sagemaker.arn
          ProcessingInputs = [
            {
              InputName = "model"
              S3Input = {
                S3Uri       = "s3://${aws_s3_bucket.pipeline.id}/models"
                LocalPath   = "/opt/ml/processing/model"
                S3DataType  = "S3Prefix"
                S3InputMode = "File"
              }
            },
            {
              InputName = "test"
              S3Input = {
                S3Uri       = "s3://${aws_s3_bucket.pipeline.id}/processing/test"
                LocalPath   = "/opt/ml/processing/test"
                S3DataType  = "S3Prefix"
                S3InputMode = "File"
              }
            },
            {
              InputName = "code"
              S3Input = {
                S3Uri       = "s3://${aws_s3_bucket.pipeline.id}/scripts/evaluate.py"
                LocalPath   = "/opt/ml/processing/code"
                S3DataType  = "S3Prefix"
                S3InputMode = "File"
              }
            }
          ]
          ProcessingOutputConfig = {
            Outputs = [{
              OutputName = "evaluation"
              S3Output = {
                S3Uri        = "s3://${aws_s3_bucket.pipeline.id}/evaluation"
                LocalPath    = "/opt/ml/processing/evaluation"
                S3UploadMode = "EndOfJob"
              }
            }]
          }
          NetworkConfig = { VpcConfig = local.vpc_config }
        }
        PropertyFiles = [{
          PropertyFileName = "EvaluationReport"
          OutputName       = "evaluation"
          FilePath         = "evaluation.json"
        }]
      },

      # Step 4: Check accuracy threshold
      {
        Name      = "CheckAccuracy"
        Type      = "Condition"
        DependsOn = ["Evaluate"]
        Arguments = {
          Conditions = [{
            Type               = "GreaterThanOrEqualTo"
            LeftValue          = { "Std:Join" = { "On" = "", "Values" = [{ "Get" = "Steps.Evaluate.PropertyFiles.EvaluationReport.metrics.accuracy.value" }] } }
            RightValue         = { "Get" = "Parameters.AccuracyThreshold" }
          }]
          IfSteps  = ["RegisterModel", "CreateEndpoint"]
          ElseSteps = ["NotifyFailure"]
        }
      },

      # Step 5a: Register model (if accuracy passes)
      {
        Name = "RegisterModel"
        Type = "RegisterModel"
        Arguments = {
          ModelPackageGroupName = aws_sagemaker_model_package_group.main.model_package_group_name
          ModelApprovalStatus   = { "Get" = "Parameters.ModelApprovalStatus" }
          InferenceSpecification = {
            Containers = [{
              Image        = local.xgb_image
              ModelDataUrl = "s3://${aws_s3_bucket.pipeline.id}/models"
            }]
            SupportedContentTypes        = ["text/csv"]
            SupportedResponseMIMETypes   = ["text/csv"]
            SupportedRealtimeInferenceInstanceTypes = [var.endpoint_instance_type]
          }
        }
      },

      # Step 5b: Create/update endpoint (if accuracy passes)
      {
        Name = "CreateEndpoint"
        Type = "Processing"
        Arguments = {
          ProcessingResources = {
            ClusterConfig = {
              InstanceCount  = 1
              InstanceType   = var.processing_instance_type
              VolumeSizeInGB = 5
            }
          }
          AppSpecification = {
            ImageUri            = local.sklearn_image
            ContainerEntrypoint = ["python3", "/opt/ml/processing/code/deploy.py"]
          }
          RoleArn = aws_iam_role.sagemaker.arn
          Environment = {
            MODEL_PACKAGE_GROUP = aws_sagemaker_model_package_group.main.model_package_group_name
            ENDPOINT_NAME       = "${var.project_name}-endpoint"
            INSTANCE_TYPE       = var.endpoint_instance_type
            INSTANCE_COUNT      = "1"
            ROLE_ARN            = aws_iam_role.sagemaker.arn
            REGION              = var.aws_region
          }
          ProcessingInputs = [{
            InputName = "code"
            S3Input = {
              S3Uri       = "s3://${aws_s3_bucket.pipeline.id}/scripts/deploy.py"
              LocalPath   = "/opt/ml/processing/code"
              S3DataType  = "S3Prefix"
              S3InputMode = "File"
            }
          }]
          NetworkConfig = { VpcConfig = local.vpc_config }
        }
      },

      # Step 5c: Notify failure (if accuracy fails)
      {
        Name = "NotifyFailure"
        Type = "Fail"
        Arguments = {
          ErrorMessage = "Model accuracy below threshold. Check evaluation report."
        }
      }
    ]
  })

  tags = { Name = "${var.project_name}-pipeline" }
}
