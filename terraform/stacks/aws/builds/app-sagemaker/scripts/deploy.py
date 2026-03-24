"""SageMaker Processing - deploy latest approved model to endpoint."""
import os
import time
import boto3

region = os.environ["REGION"]
sm = boto3.client("sagemaker", region_name=region)

model_pkg_group = os.environ["MODEL_PACKAGE_GROUP"]
endpoint_name = os.environ["ENDPOINT_NAME"]
instance_type = os.environ["INSTANCE_TYPE"]
instance_count = int(os.environ["INSTANCE_COUNT"])
role_arn = os.environ["ROLE_ARN"]

# Get latest approved model package
packages = sm.list_model_packages(
    ModelPackageGroupName=model_pkg_group,
    ModelApprovalStatus="PendingManualApproval",
    SortBy="CreationTime",
    SortOrder="Descending",
    MaxResults=1,
)

if not packages["ModelPackageSummaryList"]:
    print("No model packages found, skipping deployment")
    exit(0)

model_pkg_arn = packages["ModelPackageSummaryList"][0]["ModelPackageArn"]
print(f"Deploying model: {model_pkg_arn}")

timestamp = str(int(time.time()))
model_name = f"{endpoint_name}-model-{timestamp}"
config_name = f"{endpoint_name}-config-{timestamp}"

# Create model from package
sm.create_model(
    ModelName=model_name,
    ExecutionRoleArn=role_arn,
    Containers=[{"ModelPackageName": model_pkg_arn}],
)

# Create endpoint config
sm.create_endpoint_config(
    EndpointConfigName=config_name,
    ProductionVariants=[{
        "VariantName": "primary",
        "ModelName": model_name,
        "InstanceType": instance_type,
        "InitialInstanceCount": instance_count,
        "InitialVariantWeight": 1.0,
    }],
)

# Create or update endpoint
try:
    sm.describe_endpoint(EndpointName=endpoint_name)
    print(f"Updating existing endpoint: {endpoint_name}")
    sm.update_endpoint(
        EndpointName=endpoint_name,
        EndpointConfigName=config_name,
    )
except sm.exceptions.ClientError:
    print(f"Creating new endpoint: {endpoint_name}")
    sm.create_endpoint(
        EndpointName=endpoint_name,
        EndpointConfigName=config_name,
    )

print(f"Endpoint deployment initiated: {endpoint_name}")
