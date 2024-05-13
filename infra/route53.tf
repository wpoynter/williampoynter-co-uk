resource "aws_route53_zone" "primary" {
  name = "williampoynter.co.uk"
}

# resource "aws_route53_record" "root" {
#   zone_id = aws_route53_zone.primary.zone_id
#   name    = var.domain_name
#   type    = "A"

#   alias {
#     name                   = aws_cloudfront_distribution.site.domain_name
#     zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
#     evaluate_target_health = false
#   }
# }

# resource "aws_route53_record" "www" {
#   zone_id = aws_route53_zone.primary.zone_id
#   name    = "www.${var.domain_name}"
#   type    = "CNAME"
#   ttl     = 300

#   records = [
#     var.domain_name
#   ]
# }

// MX record for Gmail
resource "aws_route53_record" "gmail" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "MX"
  ttl     = 300

  records = [
    "1 aspmx.l.google.com",
    "5 alt1.aspmx.l.google.com",
    "5 alt2.aspmx.l.google.com",
    "10 alt3.aspmx.l.google.com",
    "10 alt4.aspmx.l.google.com",
  ]
}

// TXT verfiication records
resource "aws_route53_record" "txt" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "TXT"
  ttl     = 300

  records = [
    "v=spf1 include:_spf.google.com -all",
    "google-site-verification=B5lxOpkU1anBzEevtFPnR2x2K3UkhyDH1nW3mfuXXTE",
    "google-site-verification=QAgdq3FMjVbwYyPyXh7T2IS65dyRmHsQvNEXJR0ZnFc",
    "keybase-site-verification=uqno7hxoTtWjNHskGYppg0kJNmhOfNbadStStuIEJZI"
  ]
}

resource "aws_route53_record" "dkim" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "google._domainkey.${var.domain_name}"
  type    = "TXT"
  ttl     = 300

  records = [
    "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCn6raXDFCuJ36bLMvGFqUcdYeUxnlJvkuykGi1glMB75Kz7E445RT3eG3XSi+J0vvbjZSdkCr9IOiruYWLCn9RbRQ1RYAxDBVFWFYeH3VKklMrRwhUwuNdKhIMFyI8yJhTngk+AZrISNx1sdhrdpgMIM3qgfBQLdpHFb4TIV8NPwIDAQAB"
  ]
}

resource "aws_route53_record" "site" {
  provider = aws.us-east-1

  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.primary.zone_id
}

resource "aws_acm_certificate_validation" "site" {
    provider = aws.us-east-1

  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for record in aws_route53_record.site : record.fqdn]
}