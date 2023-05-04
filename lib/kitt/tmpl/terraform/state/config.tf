terraform {
  backend "s3" {
    bucket = "__TF_STATE_BUCKET_NAME__"
    key    = "__CLUSTER_NAME__/state.tfstate"
    region = "__CLUSTER_REGION__"
  }
}
