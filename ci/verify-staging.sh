#!/bin/sh
# Wait for the canonical staging FQDN to serve THIS pipeline's build tag,
# then run the static-site checks. Needs STAGING_URL, CA_CERT, TAG in the
# environment (TAG arrives via the build job's build.env dotenv artifact) -
# see the verify-staging job in .gitlab-ci.yml.
set -eu

# Worst-case pull-based latency: ImageRepository scan 5m + ImageUpdateAutomation
# 5m + git push + flux-system GitRepository 1m + Kustomization reconcile +
# rollout. 25 minutes of headroom; poll every 20s.
deadline=$(( $(date +%s) + 1500 ))
while :; do
  served="$(curl -fsS --cacert "$CA_CERT" "$STAGING_URL/build-tag.txt" 2>/dev/null || true)"
  if [ "$served" = "$TAG" ]; then
    echo "staging serves $TAG"
    break
  fi
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "ERROR: staging never served tag $TAG (last seen: '${served:-<none>}')"
    echo "Check: DNS A record live (playbook 52)? ImagePolicy/automation healthy?"
    exit 1
  fi
  echo "staging serves '${served:-<none>}', waiting for $TAG ..."
  sleep 20
done

# Static-site checks. Each check retries for up to 2 minutes: the poll
# above matches on the NEW pod's first response, which lands mid-rollout
# (replicas 1 - the old pod is still terminating and endpoints flap
# 404/503 for a few seconds; killed pipelines 418/424). grep WITHOUT
# -q: under pipefail, grep -q exits at first match and curl dies on
# EPIPE writing the rest of the body (exit 23).
retry() { n=0; until "$@"; do n=$((n+1)); if [ "$n" -ge 24 ]; then echo "check failed after $n tries"; return 1; fi; sleep 5; done; }
code() { curl -sS --cacert "$CA_CERT" -o /dev/null -w '%{http_code}' "$1"; }
ok_root() { [ "$(code "$STAGING_URL/")" = "200" ]; }
ok_body() { curl -fsS --cacert "$CA_CERT" "$STAGING_URL/" | grep -i "William Poynter" >/dev/null; }
ok_health() { [ "$(code "$STAGING_URL/healthz")" = "200" ]; }
ok_map() { curl -fsS --cacert "$CA_CERT" "$STAGING_URL/sitemap.xml" | grep "<urlset" >/dev/null; }

retry ok_root && retry ok_body && retry ok_health && retry ok_map
echo "all staging checks green"
