#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
HEALTH_PATH="${2:-/health}"

if [[ -z "$VERSION" ]]; then
  echo "Uso: $0 VERSION [HEALTH_PATH]" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ ! -d "${ROOT_DIR}/app" ]]; then
  echo "ERRO: app/ não existe. Execute ./comum/prepare-source.sh" >&2
  exit 1
fi

docker build \
  -f "${ROOT_DIR}/formando/docker/Dockerfile" \
  --build-arg "APP_VERSION=${VERSION}" \
  --build-arg "SOURCE_REF=v3.1.0" \
  --build-arg "HEALTH_PATH=${HEALTH_PATH}" \
  -t "symfony-demo:${VERSION}" \
  "${ROOT_DIR}"

echo "Imagem criada: symfony-demo:${VERSION}"
