terraform {
  backend "s3" {
    bucket = "kyso-tftest-terraform-858604803370"
    key    = "tftest/state.tfstate"
    region = "eu-west-1"
  }
}
