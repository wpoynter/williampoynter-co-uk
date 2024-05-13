# Site S3 Bucket

## Bucket
resource "aws_s3_bucket" "site-bucket" {
  bucket = var.domain_name

  logging {
    target_bucket = aws_s3_bucket.site-logs.bucket
    target_prefix = "${var.domain_name}/s3/root"
  }
}

resource "aws_s3_bucket_ownership_controls" "site-bucket" {
  bucket = aws_s3_bucket.site-bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site-bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

## Bucket public access
resource "aws_s3_bucket_public_access_block" "site-bucket" {
  bucket = aws_s3_bucket.site-bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

## Bucket policy
data "template_file" "site-bucket-policy" {
  template = file("public_bucket_policy.json")
  vars = {
    bucket = aws_s3_bucket.site-bucket.id
  }
}

resource "aws_s3_bucket_policy" "site-bucket" {
  bucket = aws_s3_bucket.site-bucket.id
  policy = data.template_file.site-bucket-policy.rendered
}

resource "aws_s3_bucket_acl" "site-bucket" {
  depends_on = [
    aws_s3_bucket_ownership_controls.site-bucket,
    aws_s3_bucket_public_access_block.site-bucket,
  ]

  bucket = aws_s3_bucket.site-bucket.id
  acl    = "public-read"
}

# Redirect www. S3 bucket

## Bucket
resource "aws_s3_bucket" "www-site-bucket" {
  bucket = "www.${var.domain_name}"

  website {
    redirect_all_requests_to = var.domain_name
  }

  logging {
    target_bucket = aws_s3_bucket.site-logs.bucket
    target_prefix = "${var.domain_name}/s3/www"
  }
}

## Bucket public access
resource "aws_s3_bucket_public_access_block" "www-site-bucket" {
  bucket = aws_s3_bucket.www-site-bucket.id
}

## Bucket policy
data "template_file" "www-site-bucket-policy" {
  template = file("public_bucket_policy.json")
  vars = {
    bucket = aws_s3_bucket.www-site-bucket.id
  }
}

resource "aws_s3_bucket_policy" "www-site-bucket" {
  bucket = aws_s3_bucket.www-site-bucket.id
  policy = data.template_file.www-site-bucket-policy.rendered
}

resource "aws_s3_bucket_ownership_controls" "www-site-bucket" {
  bucket = aws_s3_bucket.www-site-bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "www-site-bucket" {
  depends_on = [
    aws_s3_bucket_ownership_controls.www-site-bucket,
    aws_s3_bucket_public_access_block.www-site-bucket,
  ]

  bucket = aws_s3_bucket.www-site-bucket.id
  acl    = "public-read"
}

# Logs S3 bucket

## Bucket
resource "aws_s3_bucket" "site-logs" {
  bucket = var.logs_bucket
}

## Disable bucket public access
resource "aws_s3_bucket_public_access_block" "site-logs" {
  bucket                  = aws_s3_bucket.site-logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "site-logs" {
  bucket = aws_s3_bucket.site-logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "site-logs" {
  depends_on = [
    aws_s3_bucket_ownership_controls.site-logs,
    aws_s3_bucket_public_access_block.site-logs,
  ]

  bucket = aws_s3_bucket.site-logs.id
  acl    = "log-delivery-write"
}