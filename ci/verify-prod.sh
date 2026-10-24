#!/bin/sh
# Wait for production to serve the tag the promote job just wrote, so the
# behaviour suite (features/) judges the promoted build and cdn-purge fires
# only once the origin has it (ADR-0043 D6). /build-tag.txt is a bunny
# bypass path: this reads the origin, while HTML pages come from the edge.
# The edge is purged only after this job, so the suite adds ?v=$PROMOTED_TAG
# to its requests (features/support/world.js) to read the promoted build.
# Needs PROMOTED_TAG (the promote job's promote.env dotenv artifact) and
# BASE_URL in the environment - see the verify-prod job of porter-valley-infra
# ci-templates/product-deploy.yml.
# Public CA on prod, so no --cacert.
set -eu

# Flux: GitRepository 1m + Kustomization reconcile + rollout. 20 minutes of
# headroom; poll every 20s. VERIFY_PROD_DEADLINE (seconds) overrides the
# wait for a local dry run.
deadline=$(( $(date +%s) + ${VERIFY_PROD_DEADLINE:-1200} ))
while :; do
  served="$(curl -fsS "$BASE_URL/build-tag.txt" 2>/dev/null || true)"
  if [ "$served" = "$PROMOTED_TAG" ]; then
    echo "prod serves $PROMOTED_TAG"
    break
  fi
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "ERROR: prod never served tag $PROMOTED_TAG (last seen: '${served:-<none>}')"
    echo "Flux has not rolled the promote commit ('promote: williampoynter-co-uk ${PROMOTED_TAG} to prod' on ${CI_DEFAULT_BRANCH:-master})."
    echo "Check: flux-system GitRepository and the williampoynter-co-uk Kustomization healthy? prod Deployment rolling? (CLAUDE.md, Deploy flow)"
    exit 1
  fi
  echo "prod serves '${served:-<none>}', waiting for $PROMOTED_TAG ..."
  sleep 20
done

# Same settle as staging: the poll matches the new pod's first answer, which
# can land mid-rollout. The suite itself retries a failed scenario.
sleep 10
