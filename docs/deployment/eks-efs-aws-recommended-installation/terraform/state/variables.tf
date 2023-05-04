variable "aws_region" {
  description = "AWS Region to use."
  type        = string
  default     = "eu-west-1"
}

variable "bucket_name" {
  description = "The name of the S3 bucket. Must be globally unique."
  type        = string
  default     = "kyso-tftest-terraform-858604803370"
}

variable "table_name" {
  description = "Name of the DynamoDB table. Must be unique in the AWS account."
  type        = string
  default     = "kyso-tftest-terraform"
}
