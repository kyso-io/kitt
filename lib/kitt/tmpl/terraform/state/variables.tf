variable "aws_region" {
  description = "AWS Region to use."
  type        = string
  default     = "__CLUSTER_REGION__"
}

variable "bucket_name" {
  description = "The name of the S3 bucket. Must be globally unique."
  type        = string
  default     = "__TF_STATE_BUCKET_NAME__"
}

variable "table_name" {
  description = "Name of the DynamoDB table. Must be unique in the AWS account."
  type        = string
  default     = "__TF_STATE_TABLE_NAME__"
}
