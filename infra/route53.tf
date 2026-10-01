# ===========================================================================
# NOT THE LIVE SOURCE. NO STATE. DO NOT INIT, PLAN OR APPLY.
#
# The live williampoynter.co.uk zone is an AWS Route 53 hosted zone,
# delegated to ns-287.awsdns-35.com, ns-800.awsdns-36.net,
# ns-1450.awsdns-53.org and ns-1984.awsdns-56.co.uk, and hand-managed by
# Will in the Route 53 console. Changes to it are tracked in Linear
# PLAT-409; the edge addressing model is ADR-0042 in porter-valley-infra
# (docs/adr/0042-portable-edge-addressing.md).
#
# This directory (williampoynter-co-uk repo, infra/) has no backend block,
# no committed state and no CI job. An apply would NOT edit the live zone:
# aws_route53_zone.primary would create a SECOND, undelegated hosted zone
# for the same name, and every record below would be written into that
# duplicate while the internet kept reading the console-managed one.
#
# What is kept here is a reference for a hand restore, aimed at the TARGET
# state rather than at whatever the console answers today:
#   - apex A and wildcard A: 188.220.22.12, the web-edge role address on
#     the beta edge node (cdn-2), per ADR-0042. Never an OVH-native VPS
#     address: those are per-box admin identities (gateway repo,
#     edge/nodes.yml public_ip) and must not appear in any DNS record.
#     The console may still answer beta's native address until Will's
#     Route 53 flip (PLAT-409) lands.
#   - no AAAA, deliberately: IPv6 stays unpublished until the ASN/PI
#     programme (ADR-0042). The console currently also carries a wildcard
#     AAAA holding cdn-2's link-local fe80:: address. That is a defect to
#     delete (PLAT-409), not a record to restore.
#   - mail: live mail is ProtonMail (MX mail.protonmail.ch and
#     mailsec.protonmail.ch, SPF include:_spf.protonmail.ch,
#     protonmail*._domainkey CNAMEs, _dmarc). The Google Workspace MX and
#     SPF below are STALE. For mail records use the console, or the shadow
#     at porter-valley-infra dns/zones/williampoynter.co.uk.public.yaml.
#
# Last compared with the live Route 53 answers: 2026-10-01.
# ===========================================================================

resource "aws_route53_zone" "primary" {
  name = "williampoynter.co.uk"
}

resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "A"

  ttl = 300

  # Web-edge role address on beta (ADR-0042). Pangolin serves the site
  # here. Route 53 (console) stays authoritative; see the header.
  records = ["188.220.22.12"]
}

# The live zone has a wildcard A; analytics.williampoynter.co.uk (the Umami
# Pangolin resource) is served through it. Same target as the apex.
resource "aws_route53_record" "wildcard" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "*.${var.domain_name}"
  type    = "A"

  ttl = 300

  records = ["188.220.22.12"]
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300

  records = [
    var.domain_name
  ]
}

// MX record for Gmail
// STALE: live MX is ProtonMail (see the header). Do not restore.
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
// STALE SPF: live SPF is include:_spf.protonmail.ch ~all, and live also
// has a protonmail-verification TXT (see the header).
resource "aws_route53_record" "txt" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "TXT"
  ttl     = 300

  records = [
    "v=spf1 include:_spf.google.com -all",
    "google-site-verification=B5lxOpkU1anBzEevtFPnR2x2K3UkhyDH1nW3mfuXXTE",
    "google-site-verification=QAgdq3FMjVbwYyPyXh7T2IS65dyRmHsQvNEXJR0ZnFc",
    "keybase-site-verification=uqno7hxoTtWjNHskGYppg0kJNmhOfNbadStStuIEJZI",
    "openai-domain-verification=dv-05ag1fwosBGrD94r1dCQvePT"
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

# resource "aws_route53_record" "site" {
#   provider = aws.us-east-1

#   for_each = {
#     for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   }

#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = aws_route53_zone.primary.zone_id
# }

# resource "aws_acm_certificate_validation" "site" {
#     provider = aws.us-east-1

#   certificate_arn         = aws_acm_certificate.site.arn
#   validation_record_fqdns = [for record in aws_route53_record.site : record.fqdn]
# }
