# Runtime image for Sharry (Netskope Secure File Transfer rebrand).
# Consumes the pre-built zip at docker/sharry-restserver.zip. To refresh the zip
# after source changes, run: ./docker/build-zip.sh
FROM alpine:latest

LABEL maintainer="john@neerdael.nl"

RUN apk -U add --no-cache openjdk17 tzdata unzip curl bash

WORKDIR /opt

# Build context must be the docker/ directory (see docker-compose.yml)
COPY sharry-restserver.zip /opt/sharry.zip

RUN unzip /opt/sharry.zip \
    && rm /opt/sharry.zip \
    && ln -snf sharry-restserver-* sharry \
    && addgroup -S user -g 10001 \
    && adduser -SDH user -u 10001 -G user

USER 10001

ENTRYPOINT ["/opt/sharry/bin/sharry-restserver"]
