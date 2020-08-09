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

provider "aws" {
  alias = "acm"
  region = "us-east-1"
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
  provider = aws.acm
  domain_name = var.domain
  validation_method = "EMAIL"
  subject_alternative_names = [var.bucket]
}

resource "aws_cloudfront_distribution" "s3_distribution" {

  provider = aws.acm

  origin {
    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }

    domain_name = "${aws_s3_bucket.htts.website_endpoint}"
    origin_id   = var.domain
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = var.domain
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  aliases = [var.domain]

  viewer_certificate {
    acm_certificate_arn      = "${aws_acm_certificate.cert.arn}"
    minimum_protocol_version = "TLSv1"
    ssl_support_method       = "sni-only"
  }
  depends_on = [
    aws_acm_certificate.cert
  ]
}

output "bucket-endpoint" {
  value = aws_s3_bucket.htts.website_endpoint
}

