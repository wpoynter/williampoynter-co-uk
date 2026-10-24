#!/bin/sh
# Wait for the canonical staging FQDN to serve THIS pipeline's build tag.
# The static-site checks that used to follow here (/, the home body,
# /healthz, sitemap.xml) are now scenarios of the behaviour suite in
# features/ (PLAT-763), which the verify-staging job runs once this script
# returns. Needs STAGING_URL, CA_CERT, TAG in the environment (TAG arrives
# via the build job's build.env dotenv artifact) - see the verify-staging
# job of porter-valley-infra ci-templates/product-deploy.yml.
set -eu

# Worst-case pull-based latency: ImageRepository scan 1m + ImageUpdateAutomation
# 1m + git push + flux-system GitRepository 1m + Kustomization reconcile +
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

# The poll above matches on the NEW pod's first response, which lands
# mid-rollout (replicas 1 - the old pod is still terminating and endpoints
# flap 404/503 for a few seconds; killed pipelines 418/424). Give the
# rollout a moment to settle; the suite itself retries a failed scenario
# (--retry 2 in BDD_SUITE_CMD), which replaces the old per-check retry.
sleep 10
