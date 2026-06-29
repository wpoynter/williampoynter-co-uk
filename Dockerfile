# syntax=docker/dockerfile:1.7

# Hugo extended pinned to the same version as the GitHub Pages workflow.
# When bumping, bump .github/workflows/hugo.yml in lockstep.
FROM hugomods/hugo:exts-0.125.4 AS builder
WORKDIR /src
COPY . .
ENV HUGO_ENVIRONMENT=production HUGO_ENV=production TZ=Europe/London
RUN hugo --gc --minify

FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY --from=builder /src/public /usr/share/nginx/html
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
