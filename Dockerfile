# Parent-owned production image for the pinned Depot submodule.
FROM node:24-bookworm-slim AS build

WORKDIR /src

RUN corepack enable && corepack prepare pnpm@10.20.0 --activate

# Keep the upstream repository isolated under vendor/depot. The parent owns
# this Dockerfile and chooses which checked-out submodule contents to build.
COPY vendor/depot/ ./vendor/depot/
WORKDIR /src/vendor/depot

RUN pnpm install --frozen-lockfile
RUN pnpm build

FROM nginx:1.29-alpine AS production

COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/vendor/depot/packages/web/dist/ /usr/share/nginx/html/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --spider --quiet http://127.0.0.1/ || exit 1
