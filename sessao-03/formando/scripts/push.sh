#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  echo "Uso: $0 VERSION" >&2
  exit 2
fi

: "${IMAGE_REPO:?Defina IMAGE_REPO, por exemplo ghcr.io/UTILIZADOR/symfony-demo}"

LOCAL_IMAGE="symfony-demo:${VERSION}"
REMOTE_IMAGE="${IMAGE_REPO}:${VERSION}"

docker image inspect "$LOCAL_IMAGE" >/dev/null
docker tag "$LOCAL_IMAGE" "$REMOTE_IMAGE"
docker push "$REMOTE_IMAGE"

echo "RepoDigests:"
docker image inspect "$REMOTE_IMAGE" \
  --format '{{range .RepoDigests}}{{println .}}{{end}}'
