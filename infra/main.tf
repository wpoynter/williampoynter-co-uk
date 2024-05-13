terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.49"
    }
  }

  required_version = ">= 1.8.0"
}

provider "aws" {
  region = "eu-west-2"
}

# us-east-1 region.  Do not change this!  It's needed to create the ACM
# certificate in us-east-1, the only region CloudFront can use them from
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

provider "template" {
}