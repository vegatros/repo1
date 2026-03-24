# --- Model Registry ---
resource "aws_sagemaker_model_package_group" "main" {
  model_package_group_name = "${var.project_name}-models"

  tags = { Name = "${var.project_name}-model-registry" }
}
