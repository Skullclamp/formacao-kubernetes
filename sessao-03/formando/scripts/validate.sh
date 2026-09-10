#!/usr/bin/env bash

# Garante que qualquer erro relevante interrompe a validação.
set -euo pipefail

# Localiza os ficheiros Compose e o ambiente de produção.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ROOT_DIR}/formando/compose/.env.prod"
BASE_FILE="${ROOT_DIR}/formando/compose/compose.yaml"
PROD_FILE="${ROOT_DIR}/formando/compose/compose.prod.yaml"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERRO: .env.prod não existe." >&2
  exit 1
fi

# Guarda o comando Compose completo num array para o reutilizar sem repetir opções.
COMPOSE=(docker compose --env-file "$ENV_FILE" -f "$BASE_FILE" -f "$PROD_FILE")

# A versão esperada pode ser fornecida explicitamente. Se não for, usa a versão
# definida em .env.prod. Isto mantém compatibilidade com a utilização anterior.
EXPECTED_VERSION="${1:-$(awk -F= '$1=="APP_VERSION"{print $2}' "$ENV_FILE" | tail -1)}"
if [[ -z "$EXPECTED_VERSION" ]]; then
  echo "ERRO: não foi possível determinar APP_VERSION esperada." >&2
  exit 1
fi

# Repositório esperado para permitir também validar a imagem efetivamente usada.
IMAGE_REPO="$(awk -F= '$1=="IMAGE_REPO"{print $2}' "$ENV_FILE" | tail -1)"
if [[ -z "$IMAGE_REPO" ]]; then
  echo "ERRO: IMAGE_REPO não está definido em .env.prod." >&2
  exit 1
fi
EXPECTED_IMAGE="${IMAGE_REPO}:${EXPECTED_VERSION}"

# Determina a porta HTTP da aplicação:
# 1) usa APP_PORT já exportada no shell, se existir;
# 2) caso contrário lê APP_PORT do .env.prod;
# 3) se ainda não existir, usa 8080.
APP_PORT="${APP_PORT:-}"
if [[ -z "$APP_PORT" ]]; then
  APP_PORT="$(awk -F= '$1=="APP_PORT"{print $2}' "$ENV_FILE" | tail -1)"
fi
APP_PORT="${APP_PORT:-8080}"
BASE_URL="http://localhost:${APP_PORT}"

# Valida /health e /ready. curl -f falha em HTTP 4xx/5xx; -s reduz ruído;
# -S continua a mostrar erros.
for path in health ready; do
  echo "==> GET /${path}"
  curl -fsS "${BASE_URL}/${path}"
  echo
done

# /info é capturado para podermos verificar também a versão devolvida pela aplicação.
echo "==> GET /info"
INFO_JSON="$(curl -fsS "${BASE_URL}/info")"
echo "$INFO_JSON"

if [[ "$INFO_JSON" != *"\"version\":\"${EXPECTED_VERSION}\""* ]]; then
  echo "ERRO: /info não reporta a versão esperada ${EXPECTED_VERSION}." >&2
  exit 1
fi

echo "Versão da aplicação confirmada: ${EXPECTED_VERSION}"

# Obtém apenas o ID do container do serviço app.
CID="$(${COMPOSE[@]} ps -q app)"
if [[ -z "$CID" ]]; then
  echo "ERRO: container app não encontrado." >&2
  exit 1
fi

# Valida também a imagem configurada no container, para detetar divergências entre
# .env.prod, /info e o artefacto realmente em execução.
RUNNING_IMAGE="$(docker inspect "$CID" --format '{{.Config.Image}}')"
echo "Imagem em execução: ${RUNNING_IMAGE}"

if [[ "$RUNNING_IMAGE" != "$EXPECTED_IMAGE" ]]; then
  echo "ERRO: imagem em execução diferente da esperada." >&2
  echo "Esperada: ${EXPECTED_IMAGE}" >&2
  echo "Atual:    ${RUNNING_IMAGE}" >&2
  exit 1
fi

# Aguarda pelo resultado do Docker HEALTHCHECK.
# São feitas até 12 observações com 5 segundos de intervalo.
echo "==> A aguardar Docker HEALTHCHECK"
for _ in $(seq 1 12); do
  STATUS="$(docker inspect "$CID" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}sem-healthcheck{{end}}')"
  echo "health=${STATUS}"

  # Se estiver healthy, mostra também imagem, limites e restart policy.
  # Se estiver unhealthy ou sem healthcheck, termina a espera e reporta a falha.
  case "$STATUS" in
    healthy)
      docker inspect "$CID" --format \
        'Image={{.Config.Image}} Memory={{.HostConfig.Memory}} NanoCpus={{.HostConfig.NanoCpus}} Restart={{.HostConfig.RestartPolicy.Name}}'
      exit 0
      ;;
    unhealthy|sem-healthcheck)
      break
      ;;
  esac

  sleep 5
done

# Em caso de falha, apresenta o detalhe completo do healthcheck para diagnóstico.
echo "ERRO: aplicação sem estado healthy." >&2
docker inspect "$CID" --format '{{json .State.Health}}' || true
exit 1
