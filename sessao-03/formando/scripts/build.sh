#!/usr/bin/env bash

# Modo seguro do Bash:
# -e termina perante erro; -u falha em variáveis não definidas;
# pipefail propaga falhas ocorridas dentro de pipelines.
set -euo pipefail

# Primeiro argumento: versão/tag a construir.
# Segundo argumento opcional: endpoint usado pelo HEALTHCHECK.
VERSION="${1:-}"
HEALTH_PATH="${2:-/health}"

# Impede a execução sem uma versão explícita.
if [[ -z "$VERSION" ]]; then
  echo "Uso: $0 VERSION [HEALTH_PATH]" >&2
  exit 2
fi

# Calcula a raiz da Sessão 3 independentemente da diretoria de onde o script é chamado.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# O build depende do source preparado por comum/prepare-source.sh.
if [[ ! -d "${ROOT_DIR}/app" ]]; then
  echo "ERRO: app/ não existe. Execute ./comum/prepare-source.sh" >&2
  exit 1
fi

# Constrói a imagem com o Dockerfile multi-stage:
# -f escolhe o Dockerfile;
# --build-arg fornece valores aos ARG do Dockerfile;
# -t atribui nome:tag à imagem;
# ROOT_DIR é o build context disponibilizado ao builder.
docker build \
  -f "${ROOT_DIR}/formando/docker/Dockerfile" \
  --build-arg "APP_VERSION=${VERSION}" \
  --build-arg "SOURCE_REF=v3.1.0" \
  --build-arg "HEALTH_PATH=${HEALTH_PATH}" \
  -t "symfony-demo:${VERSION}" \
  "${ROOT_DIR}"

# Confirma ao operador a referência local criada.
echo "Imagem criada: symfony-demo:${VERSION}"
