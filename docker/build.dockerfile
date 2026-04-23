# Builder image: compiles Sharry (Scala + Elm + Tailwind) and emits the
# restserver universal zip under /out. Extract with:
#   docker build -f docker/build.dockerfile --target export --output docker/ .
# sbt launcher image; the actual sbt version (1.10.10) is pinned in
# project/build.properties and sbt will bootstrap it on first run.
FROM sbtscala/scala-sbt:eclipse-temurin-17.0.15_6_1.12.9_3.3.7 AS builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates gnupg xz-utils unzip \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Elm 0.19.1 via @lydell/elm (cross-arch npm package with arm64 Linux support;
# the upstream `elm` npm package lacks prebuilt linux/arm64 binaries).
RUN npm install -g @lydell/elm@0.19.1-14 --unsafe-perm=true \
    && ln -sf "$(npm root -g)/@lydell/elm/bin/elm" /usr/local/bin/elm \
    && elm --version

# Tailwind standalone CLI (avoids needing a full Tailwind npm toolchain here;
# the project also uses npm install for other deps, handled via sbt StylesPlugin).
# The sbt build invokes `tailwindcss`, so make it available.
RUN set -eux; \
    arch="$(uname -m)"; \
    case "$arch" in \
      x86_64) tw_url=https://github.com/tailwindlabs/tailwindcss/releases/download/v3.4.17/tailwindcss-linux-x64 ;; \
      aarch64) tw_url=https://github.com/tailwindlabs/tailwindcss/releases/download/v3.4.17/tailwindcss-linux-arm64 ;; \
    esac; \
    curl -fsSL "$tw_url" -o /usr/local/bin/tailwindcss; \
    chmod +x /usr/local/bin/tailwindcss; \
    tailwindcss --help >/dev/null

WORKDIR /src

# Prime sbt/ivy caches by copying only build definition first
COPY build.sbt version.sbt ./
COPY project ./project
RUN sbt -Dsbt.ci=true update || true

# Now copy the rest of the source and build
COPY . .
# `make` runs openapiCodegen (which generates target/elm-src) plus the prod-mode
# compile of webapp/elm and styles; `make-zip` then packages the universal zip.
RUN sbt -Dsbt.ci=true \
    "set ThisBuild / version := \"1.16.0-SNAPSHOT\"" \
    ";make ;make-zip"

# Collect the zip into a known location
RUN set -eux; \
    zip=$(ls modules/restserver/target/universal/sharry-restserver-*.zip | head -1); \
    mkdir -p /out; \
    cp "$zip" /out/sharry-restserver.zip; \
    ls -la /out

# Export stage: used to pull the zip out of the builder to the host
FROM scratch AS export
COPY --from=builder /out/sharry-restserver.zip /sharry-restserver.zip
