# Multi-stage build: compile Sharry (Scala + Elm + Tailwind) and produce a
# slim runtime image. Build from the repo root:
#   docker build -f docker/sharry.dockerfile -t sharry:local .
# Or via docker-compose (which sets context: .. automatically).

# ---- builder ---------------------------------------------------------------
FROM sbtscala/scala-sbt:eclipse-temurin-17.0.15_6_1.12.9_3.3.7 AS builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates gnupg unzip \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Elm 0.19.1 via @lydell/elm (cross-arch npm package with linux/arm64 support)
RUN npm install -g @lydell/elm@0.19.1-14 --unsafe-perm=true \
    && ln -sf "$(npm root -g)/@lydell/elm/bin/elm" /usr/local/bin/elm \
    && elm --version

# Tailwind standalone CLI (sbt build invokes `tailwindcss`)
RUN set -eux; \
    arch="$(uname -m)"; \
    case "$arch" in \
      x86_64)  tw_url=https://github.com/tailwindlabs/tailwindcss/releases/download/v3.4.17/tailwindcss-linux-x64 ;; \
      aarch64) tw_url=https://github.com/tailwindlabs/tailwindcss/releases/download/v3.4.17/tailwindcss-linux-arm64 ;; \
      *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "$tw_url" -o /usr/local/bin/tailwindcss; \
    chmod +x /usr/local/bin/tailwindcss; \
    tailwindcss --help >/dev/null

WORKDIR /src

# Prime sbt/ivy caches from build definition only (better layer reuse)
COPY build.sbt version.sbt ./
COPY project ./project
RUN sbt -Dsbt.ci=true update || true

# Full source + build
COPY . .
RUN sbt -Dsbt.ci=true \
    "set ThisBuild / version := \"1.16.0-SNAPSHOT\"" \
    ";make ;make-zip" \
    && cp modules/restserver/target/universal/sharry-restserver-*.zip /tmp/sharry.zip

# ---- runtime ---------------------------------------------------------------
FROM alpine:latest

LABEL maintainer="john@neerdael.nl"

RUN apk -U add --no-cache openjdk17 tzdata unzip curl bash

WORKDIR /opt

COPY --from=builder /tmp/sharry.zip /opt/sharry.zip

RUN unzip /opt/sharry.zip \
    && rm /opt/sharry.zip \
    && ln -snf sharry-restserver-* sharry \
    && addgroup -S user -g 10001 \
    && adduser -SDH user -u 10001 -G user

USER 10001

ENTRYPOINT ["/opt/sharry/bin/sharry-restserver"]
