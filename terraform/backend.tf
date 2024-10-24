terraform {
  backend "s3" {
    bucket = "devops2401-adolfodelcastillo"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}