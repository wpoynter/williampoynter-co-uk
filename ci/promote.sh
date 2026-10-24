#!/bin/sh
# Vault-authenticates, confirms staging is healthy, then writes the
# staging-proven tag into flux/deployment.yaml as plain text and pushes with
# [skip ci] - prod (ADR-0018 amendment 2026-07-11) advances only here. Needs
# CA_CERT, VAULT_CLI_VERSION, VAULT_ROLE, VAULT_ID_TOKEN, STAGING_URL, TAG and
# CI_DEFAULT_BRANCH in the environment - see the promote job of
# porter-valley-infra ci-templates/product-deploy.yml. Hands the tag on to
# verify-prod as PROMOTED_TAG in promote.env (dotenv artifact, PLAT-763).
set -eu

# promote.env first, before anything can fail or exit early: verify-prod
# and cdn-purge `needs:` this artifact, and a missing dotenv fails them
# before their own script runs. $CI_PROJECT_DIR because the clone below
# cd's away from the checkout the artifact is collected from.
echo "PROMOTED_TAG=${TAG}" > "${CI_PROJECT_DIR:-.}/promote.env"

# TLS trust: CA_CERT is the cluster trust bundle the runner mounts; curl
# reads it via --cacert below and the runner environment (CURL_CA_BUNDLE,
# VAULT_CACERT, GIT_SSL_CAINFO) covers vault and git. Nothing is installed.
curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_CLI_VERSION}/vault_${VAULT_CLI_VERSION}_linux_amd64.zip" -o /tmp/vault.zip
unzip -d /usr/local/bin /tmp/vault.zip vault
chmod +x /usr/local/bin/vault

export VAULT_ADDR="${VAULT_ADDR:-https://vault.sheffield.exchange}"
# export FOO=$(vault ...) masks the subshell's exit code - the empty-check
# below is the real failure gate (pvt-gitlab-ci-authoring rule 5).
VAULT_TOKEN="$(vault write -field=token auth/jwt/login role="${VAULT_ROLE}" jwt="${VAULT_ID_TOKEN}")"
export VAULT_TOKEN
if [ -z "${VAULT_TOKEN}" ]; then
  echo "ERROR: Failed to obtain Vault token for role ${VAULT_ROLE}"
  exit 1
fi

# Platform verdict - PLACEHOLDER (docs/contracts.md Environment axis says
# the source is recorded back once proven; ticket tracks the real one).
# Today: the staging health endpoint must answer 200 at promote time.
test "$(curl -sS --cacert "$CA_CERT" -o /dev/null -w '%{http_code}' "$STAGING_URL/healthz")" = "200"

# Informational: verify-staging already proved $TAG served on staging. If a
# newer build has since auto-deployed there, promoting $TAG is still legal
# (it was staging-proven); just make it visible.
served="$(curl -fsS --cacert "$CA_CERT" "$STAGING_URL/build-tag.txt" || true)"
if [ "$served" != "$TAG" ]; then
  echo "NOTE: staging currently serves '${served}'; promoting the staging-proven tag ${TAG}"
fi

# Shared group git-write credential (ADR-0018 2026-07-03 amendment) via
# ~/.netrc so it never appears in the process list or job log.
GIT_USER="$(vault kv get -field=username secret/infrastructure/flux/git-write)"
GIT_PASS="$(vault kv get -field=password secret/infrastructure/flux/git-write)"
printf 'machine vcs.sheffield.exchange login %s password %s\n' "$GIT_USER" "$GIT_PASS" > ~/.netrc
chmod 600 ~/.netrc

git clone --depth 1 --branch "${CI_DEFAULT_BRANCH}" https://vcs.sheffield.exchange/porter-valley-tech/williampoynter-co-uk.git /tmp/promote
cd /tmp/promote

# Plain-text tag write: prod's image line has NO $imagepolicy marker, so
# this sed is the ONLY writer of the prod tag. (The old inline version of
# this line needed a YAML block scalar because "image: " plus a colon-space
# scalar silently parsed as a mapping and GitLab rejected the pipeline at
# creation with zero jobs - pipeline 411/413. That trap is YAML-specific and
# does not apply now that this is a plain shell script.)
sed -i -E "s|(image: registry\.sheffield\.exchange/porter-valley-tech/williampoynter-co-uk:)[A-Za-z0-9._-]+|\1${TAG}|" flux/deployment.yaml
grep -q "williampoynter-co-uk:${TAG}" flux/deployment.yaml

# Early exit is still a success: promote.env already names the tag, so
# verify-prod runs the suite against the prod that serves it (worth
# verifying either way) and cdn-purge follows (a purge is harmless).
if git diff --quiet -- flux/deployment.yaml; then
  echo "prod already runs ${TAG} - nothing to promote"
  exit 0
fi

git config user.name "promote-bot"
git config user.email "flux@sheffield.exchange"
# [skip ci] is load-bearing: the promote commit must trigger NO pipeline
# (ADR-0018 [skip ci] discipline is UNCHANGED by the PLAT-240 amendment).
git commit -m "promote: williampoynter-co-uk ${TAG} to prod [skip ci]" -- flux/deployment.yaml
git push origin HEAD:"${CI_DEFAULT_BRANCH}"
echo "promoted ${TAG} to prod - Flux reconciles it within ~10m"
