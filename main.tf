terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "brightonsbox"

    workspaces {
      name = "htts-environment"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "template" {
}

resource "aws_iam_user" "circleci" {
  name = var.user
  path = "/system/"
}

resource "aws_iam_access_key" "circleci" {
  user = aws_iam_user.circleci.name
}

data "template_file" "circleci_policy" {
  template = file("circleci_s3_access.tpl.json")
  vars = {
    s3_bucket_arn = aws_s3_bucket.htts.arn
  }
}

resource "aws_iam_user_policy" "circleci" {
  name   = "AllowCircleCI"
  user   = aws_iam_user.circleci.name
  policy = data.template_file.circleci_policy.rendered
}

resource "aws_s3_bucket" "htts" {
  tags = {
    Name = "htts website bucket"
  }

  bucket = var.bucket
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  force_destroy = true
}

resource "aws_acm_certificate" "cert" {
  provider = "aws.us-east-1"
  domain_name = var.domain
  validation_method = "EMAIL"
  subject_alternative_names = [var.bucket]
}

output "bucket-endpoint" {
  value = aws_s3_bucket.htts.website_endpoint
}

