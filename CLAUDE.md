# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal resume / portfolio site for Will Poynter, served at https://williampoynter.co.uk. Hugo static site built on the [hugo-resume](https://github.com/eddiewebb/hugo-resume) theme (vendored as a git submodule at `themes/resume`).

There are **two** deploy paths - both build from the same source on push:

1. **Porter Valley K8s cluster** (`.gitlab-ci.yml` + `flux/`) - **current public deploy**: public DNS is the AWS Route 53 hosted zone, hand-managed by Will in the Route 53 console (no IaC applies it: `porter-valley-infra/dns/zones/williampoynter.co.uk.public.yaml` is only a shadow, and this repo's `infra/route53.tf` is not live either). Its apex A and wildcard A must target the Pangolin web edge on beta, the role address 188.220.22.12 (ADR-0042, `porter-valley-infra/docs/adr/0042-portable-edge-addressing.md`), which fronts the cluster nginx. That is the target state, not yet the live answer: as of 2026-10-01 the console still answers beta's OVH-native address (plus a link-local wildcard AAAA to delete) until Will's Route 53 flip (Linear PLAT-409) lands. The native address is the box's admin identity only and must not stay in DNS; check with `dig +short A williampoynter.co.uk @1.1.1.1`. CI builds a Docker image to `registry.sheffield.exchange/porter-valley-tech/williampoynter-co-uk`; Flux reconciles the manifests in `flux/` (registered from `porter-valley-infra/flux/clusters/gen-cluster/`). Mirrors the `sheffield-rocks-site` pattern, minus DB/workers/secrets - it's a static nginx serve. Also serves internal staging at `williampoynter.sheffield.exchange`. The apex is the canonical host; `flux/ingress.yaml` 308s www to it (fonts break on www otherwise - absolute apex asset URLs make font loads cross-origin and nginx sends no CORS headers).
2. **GitHub Pages** (`.github/workflows/hugo.yml`) - the pre-Pangolin public deploy (cutover 2026-07-17); the workflow still runs but nothing points at it.

The `infra/` Terraform (S3 + CloudFront + Route53 + ACM in `eu-west-2`) is the **original** hosting setup, no longer the deployment target (see commit `233d4d2` "Moving to GitHub pages") but kept in-tree. Don't edit `infra/` expecting it to affect the live site. It has no backend, no committed state and no CI job: never `init`, `plan` or `apply` it, because `aws_route53_zone.primary` would create a duplicate, undelegated hosted zone (see the header of `infra/route53.tf`).

## Commands

Hugo (extended) `0.125.4` is the toolchain pinned by CI - match locally (or build with the same image: `docker run --rm --user "$(id -u):$(id -g)" -v "$PWD":/src -w /src hugomods/hugo:exts-0.125.4 hugo --gc --minify`).

```bash
git submodule update --init --recursive   # required: theme is a submodule
yarn install                              # lint deps and the behaviour suite
hugo serve                                # local dev server with live reload
hugo --gc --minify                        # production build -> ./public
yarn run eslint static/js/search.js features   # JS linting
yarn run html-validate public/**/*.html   # HTML validation (run after a build)

# Behaviour tests (features/, see features/README.md)
yarn bdd:install                          # once: playwright's Chromium
yarn serve                                # serve ./public on :3000 (after a build)
yarn bdd:local                            # suite against :3000, minus @origin
yarn bdd:staging                          # suite against the staging FQDN
yarn bdd:prod                             # suite against https://williampoynter.co.uk
```

`npm test` is a stub; the tests are the behaviour suite. CI does not run lint - the `eslint` and `html-validate` deps are local only (`html-validate` reports two duplicate-id errors from the theme's section partials today).

### Behaviour tests

`features/` holds read-only Cucumber scenarios (`@cucumber/cucumber` + `playwright`, plain ESM JavaScript, `cucumber.json` at the root) that describe what the live site does: the home page, every section and published content page (heading + `<title>`), the side navigation, internal links, sitemap and robots.txt, health and build tag, trailing-slash redirects, the 404 page, a clean browser load and the phone menu. Lists of pages and nav links are derived from `config.toml` and `content/` by `features/support/content.js` (drafts, future-dated and expired pages excluded, as Hugo does), so new content is covered without editing a feature. `BASE_URL` selects the target; `NODE_EXTRA_CA_CERTS` (set by `bdd:staging` to `ci/porter-valley-root-ca.crt`) trusts the vault-pki staging cert, and the browser context then skips certificate checks (Chromium keeps its own store; `features/support/world.js`). Scenarios tagged `@origin` need the real nginx image (`/healthz`, `/build-tag.txt`, redirects); to run them locally, `docker build --build-arg BUILD_TAG=local -t wpcouk . && docker run -p 18080:8080 wpcouk` and `BASE_URL=http://localhost:18080 yarn bdd`.

## Architecture

The site is **data-driven**, not page-driven - most homepage content comes from JSON files, not Markdown.

- **`config.toml`** - global site config and `[params]` toggles (`showEducation`, `showPublications`, etc.) that gate which homepage sections render. Flip these to hide a section.
- **`data/*.json`** - homepage content lives here, not in `content/`. `experience.json` (work history), `education.json`, `skills.json` (grouped, with optional Devicon `icon` keys), `devicon.json` (icon registry). Edit these to change the resume body.
- **`content/`** - only used for collections that have their own pages: `publications/*.md` (each is a blog/article entry with frontmatter `pubtype`, `featured`, `tags`, `link`, `image`) and a stub `projects/`. The homepage pulls these via `partial "sectionSummary"` in `layouts/index.html`.
- **`layouts/`** - local overrides of the theme. Hugo merges these on top of `themes/resume/layouts/`, so any file here wins. `layouts/_default/baseof.html` is fully overridden (loads Bootstrap 4.6, FontAwesome, Devicon, and the Umami tracker). `layouts/partials/portfolio/*` are the theme partials referenced from `index.html` - those live in the submodule unless overridden here.
- **`static/`** - copied verbatim to site root. `static/js/search.js` powers Fuse.js search over the `index.json` Hugo emits (see `[outputs] home = ["HTML", "JSON"]` in `config.toml`).

### Theme submodule gotcha

`themes/resume` is a submodule pinned to a specific commit of `eddiewebb/hugo-resume`. Without `git submodule update --init --recursive` the theme directory is empty and `hugo serve` will fail or produce a near-blank page. If a layout reference can't be found, check the submodule is checked out before assuming it's a missing override.

### Deploy flow

**GitHub Pages**: GitHub Actions checks out submodules recursively, runs `hugo --gc --minify --baseURL <pages-url>/`, and uploads `./public` as a Pages artifact. `TZ=Europe/London` is set so any date-sensitive templating matches the author's locale. To preview what CI will produce, run `hugo --gc --minify` and inspect `./public`.

**K8s (GitLab -> Flux)**: ADR-0018 pull-based delivery. `.gitlab-ci.yml` keeps the manifest checks (`validate-manifests`, `publish-product-manifests`) and the Kaniko `build` (`GIT_SUBMODULE_STRATEGY: recursive` - the theme submodule is mandatory or Hugo emits a near-blank site), which pushes `registry.sheffield.exchange/porter-valley-tech/williampoynter-co-uk:master-<epoch>-<sha8>` from the multi-stage `Dockerfile` (Hugo build -> `nginxinc/nginx-unprivileged:1.27-alpine` on port 8080, build tag baked at `/build-tag.txt`). The rest of the path is the porter-valley-infra template `ci-templates/product-deploy.yml` (PLAT-763), included with this site's `STAGING_URL`, `PROD_URL`, `BDD_SUITE_CMD`, yarn `.bdd` install, `VAULT_ROLE` and `CDN_PURGE_PRODUCT`; every push to `master` runs it hands-off:

1. Flux image automation deploys the new tag to staging (`williampoynter-co-uk.app.staging.psl.sheffield.exchange`, ImagePolicy marker on `flux/deployment-staging.yaml`).
2. `verify-staging` waits until staging serves this pipeline's tag (`ci/verify-staging.sh`), then runs the behaviour suite there.
3. `promote` (automatic) writes the tag into `flux/deployment.yaml` and pushes a `promote: ... [skip ci]` commit (`ci/promote.sh`, Vault JWT role `ci-williampoynter-co-uk-promote`, shared git-write credential). Kill switch: set the project CI variable `PROMOTE_GATE=manual` (Settings > CI/CD > Variables) and promote and cdn-purge become manual clicks again.
4. `verify-prod` waits until the origin serves the promoted tag (`ci/verify-prod.sh`; `/build-tag.txt` bypasses the bunny edge), then runs the suite against prod.
5. `cdn-purge` triggers a porter-valley-infra main pipeline that empties the bunny.net pull zone (ADR-0043 Decision 6, PLAT-497).

`probe-prod` runs the same suite against prod from a pipeline schedule with `PROBE=prod` (Build > Pipeline schedules, branch `master`); a failure is the alert. The three `ci/*.sh` scripts stay in this repo (the template runs `sh ci/<name>.sh`); every rule uses `$CI_DEFAULT_BRANCH`. No job holds kubectl or cluster credentials. The Hugo version in `Dockerfile` (`hugomods/hugo:exts-0.125.4`) must stay in lockstep with `.github/workflows/hugo.yml`. `docker/nginx.conf` configures clean-URL `try_files` (with `absolute_redirect off`, so `/foo` -> `/foo/` stays on the public origin instead of `http://<host>:8080`), asset cache headers, and a `/healthz` endpoint for the kubelet probes.

## Adding content

- **New publication / blog post**: `hugo new publications/<slug>.md` (uses `archetypes/default.md`), then fill in `pubtype`, `featured`, `tags`, `link`, `image`, `description`. Drafts (`draft: true`) are excluded from production builds.
- **Update resume body**: edit the relevant `data/*.json` - no template changes needed.
- **Toggle a section on/off**: flip the corresponding `show*` flag under `[params]` in `config.toml`.
