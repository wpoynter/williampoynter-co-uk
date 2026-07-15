#!/bin/sh
# Trust the Porter Valley internal CA and write kaniko's registry auth, so
# the executor can push to registry.sheffield.exchange. Runs inside the
# kaniko executor image (which ships a busybox shell - the "-debug" variant
# exists for exactly this) before /kaniko/executor - see the build job in
# .gitlab-ci.yml.
set -eu

cat ci/porter-valley-root-ca.crt >> /kaniko/ssl/certs/ca-certificates.crt

mkdir -p /kaniko/.docker
cat > /kaniko/.docker/config.json <<EOF
{
  "auths": {
    "$CI_REGISTRY": {
      "auth": "$(printf "%s:%s" "$CI_REGISTRY_USER" "$CI_REGISTRY_PASSWORD" | base64 | tr -d '\n')"
    }
  }
}
EOF
