# Behaviour tests

Plain-language checks of what the live site does, one file per concern.
They are read-only, so the same suite runs against a local static server,
staging (where it gates production promotion), production right after
promotion (`verify-prod`, which gates the CDN purge) and production on a
schedule (`probe-prod`, as a health check). Lists of pages come from
`config.toml` and `content/` (features/support/content.js), never from
copy, so the suite follows the content.

In `verify-prod` (PROMOTED_TAG set) every request carries `?v=<tag>`:
the suite runs before the CDN purge, and the query makes the bunny edge
fetch the promoted build instead of serving the previous one from cache.

Scenarios tagged `@origin` need the real nginx image (health endpoint,
build tag, trailing-slash redirects); `yarn bdd:local` leaves them out
when testing `yarn serve`. The site publishes no security.txt, so there
is no scenario for one; add it here when the file lands in `static/`.
