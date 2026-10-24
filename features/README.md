# Behaviour tests

Plain-language checks of what the live site does, one file per concern.
They are read-only, so the same suite runs against a local static server,
staging (where it gates production promotion), production right after
the CDN purge (`verify-live`) and production on a schedule (`probe-prod`,
as a health check). Lists of pages come from
`config.toml` and `content/` (features/support/content.js), never from
copy, so the suite follows the content.

Every request goes to the URL a visitor would use, with no cache-busting
query: in CI the production run (`verify-live`, porter-valley-infra
`ci-templates/product-deploy.yml`, PLAT-766) starts only after the CDN
purge, so the bunny edge already serves the promoted build. A query here
would hide a stale edge, which is what that run is there to catch.

Scenarios tagged `@origin` need the real nginx image (health endpoint,
build tag, trailing-slash redirects); `yarn bdd:local` leaves them out
when testing `yarn serve`. The site publishes no security.txt, so there
is no scenario for one; add it here when the file lands in `static/`.
