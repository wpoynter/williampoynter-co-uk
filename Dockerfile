# syntax=docker/dockerfile:1.7

# Hugo extended pinned to the same version as the GitHub Pages workflow.
# When bumping, bump .github/workflows/hugo.yml in lockstep.
FROM hugomods/hugo:exts-0.125.4 AS builder
WORKDIR /src
COPY . .
ENV HUGO_ENVIRONMENT=production HUGO_ENV=production TZ=Europe/London
# Build sentinel (PLAT-240): CI passes the image tag so verify-staging can
# poll /build-tag.txt and know exactly which build staging is serving.
ARG BUILD_TAG=dev
RUN hugo --gc --minify && printf '%s\n' "$BUILD_TAG" > /src/public/build-tag.txt

FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY --from=builder /src/public /usr/share/nginx/html
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
