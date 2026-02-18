# Test S3 Bucket
resource "aws_s3_bucket" "test" {
  bucket = "test-coderabbit-bucket"
  
  tags = {
    Name        = "Test Bucket"
    Environment = "dev"
  }
}
