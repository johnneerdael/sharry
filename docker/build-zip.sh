#!/usr/bin/env bash
# Build the Sharry restserver zip inside Docker and emit it to docker/.
# Usage: ./docker/build-zip.sh
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

echo ">>> Building sharry-restserver zip via docker/build.dockerfile"
docker build \
    -f docker/build.dockerfile \
    --target export \
    --output "docker/" \
    .

echo ">>> Done. Artifact:"
ls -la docker/sharry-restserver.zip
