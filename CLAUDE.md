# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal resume / portfolio site for Will Poynter, served at https://williampoynter.co.uk. Hugo static site built on the [hugo-resume](https://github.com/eddiewebb/hugo-resume) theme (vendored as a git submodule at `themes/resume`).

There are **two** active deploy paths — both build from the same source on push:

1. **GitHub Pages** (`.github/workflows/hugo.yml`) — current public deploy at `williampoynter.co.uk`. DNS in `porter-valley-infra/dns/zones/williampoynter.co.uk.public.yaml` points at the GH Pages anycast IPs.
2. **Porter Valley K8s cluster** (`.gitlab-ci.yml` + `flux/`) — internal staging at `williampoynter.sheffield.exchange`. CI builds a Docker image to `registry.sheffield.exchange/porter-valley-tech/williampoynter-co-uk`; Flux reconciles the manifests in `flux/` (registered from `porter-valley-infra/flux/clusters/gen-cluster/`). Mirrors the `sheffield-rocks-site` pattern, minus DB/workers/secrets — it's a static nginx serve.

The `infra/` Terraform (S3 + CloudFront + Route53 + ACM in `eu-west-2`) is the **original** hosting setup, no longer the deployment target (see commit `233d4d2` "Moving to GitHub pages") but kept in-tree. Don't edit `infra/` expecting it to affect the live site.

## Commands

Hugo (extended) `0.125.4` is the toolchain pinned by CI — match locally.

```bash
git submodule update --init --recursive   # required: theme is a submodule
yarn install                              # only needed for lint deps
hugo serve                                # local dev server with live reload
hugo --gc --minify                        # production build → ./public
yarn run eslint <file>                    # JS linting (only static/js/search.js exists)
yarn run html-validate public/**/*.html   # HTML validation (run after a build)
```

There is **no test suite**; `npm test` is a stub. CI does not run lint either — the `eslint` and `html-validate` deps are available locally only.

## Architecture

The site is **data-driven**, not page-driven — most homepage content comes from JSON files, not Markdown.

- **`config.toml`** — global site config and `[params]` toggles (`showEducation`, `showPublications`, etc.) that gate which homepage sections render. Flip these to hide a section.
- **`data/*.json`** — homepage content lives here, not in `content/`. `experience.json` (work history), `education.json`, `skills.json` (grouped, with optional Devicon `icon` keys), `devicon.json` (icon registry). Edit these to change the resume body.
- **`content/`** — only used for collections that have their own pages: `publications/*.md` (each is a blog/article entry with frontmatter `pubtype`, `featured`, `tags`, `link`, `image`) and a stub `projects/`. The homepage pulls these via `partial "sectionSummary"` in `layouts/index.html`.
- **`layouts/`** — local overrides of the theme. Hugo merges these on top of `themes/resume/layouts/`, so any file here wins. `layouts/_default/baseof.html` is fully overridden (loads Bootstrap 4.6, FontAwesome, Devicon from CDNs, plus a Ketch consent banner). `layouts/partials/portfolio/*` are the theme partials referenced from `index.html` — those live in the submodule unless overridden here.
- **`static/`** — copied verbatim to site root. `static/js/search.js` powers Fuse.js search over the `index.json` Hugo emits (see `[outputs] home = ["HTML", "JSON"]` in `config.toml`).

### Theme submodule gotcha

`themes/resume` is a submodule pinned to a specific commit of `eddiewebb/hugo-resume`. Without `git submodule update --init --recursive` the theme directory is empty and `hugo serve` will fail or produce a near-blank page. If a layout reference can't be found, check the submodule is checked out before assuming it's a missing override.

### Deploy flow

**GitHub Pages**: GitHub Actions checks out submodules recursively, runs `hugo --gc --minify --baseURL <pages-url>/`, and uploads `./public` as a Pages artifact. `TZ=Europe/London` is set so any date-sensitive templating matches the author's locale. To preview what CI will produce, run `hugo --gc --minify` and inspect `./public`.

**K8s (GitLab → Flux)**: `.gitlab-ci.yml` sets `GIT_SUBMODULE_STRATEGY: recursive` (the theme submodule is mandatory or Hugo emits a near-blank site), runs `docker build` against the multi-stage `Dockerfile` (Hugo build → `nginxinc/nginx-unprivileged:1.27-alpine` runtime on port 8080), pushes to `registry.sheffield.exchange/porter-valley-tech/williampoynter-co-uk:{sha,latest}`, and the manual `deploy` job does `kubectl set image` against the `williampoynter-co-uk` namespace. The Hugo version in `Dockerfile` (`hugomods/hugo:exts-0.125.4`) must stay in lockstep with `.github/workflows/hugo.yml`. `docker/nginx.conf` configures clean-URL `try_files`, asset cache headers, and a `/healthz` endpoint for the kubelet probes.

## Adding content

- **New publication / blog post**: `hugo new publications/<slug>.md` (uses `archetypes/default.md`), then fill in `pubtype`, `featured`, `tags`, `link`, `image`, `description`. Drafts (`draft: true`) are excluded from production builds.
- **Update resume body**: edit the relevant `data/*.json` — no template changes needed.
- **Toggle a section on/off**: flip the corresponding `show*` flag under `[params]` in `config.toml`.
