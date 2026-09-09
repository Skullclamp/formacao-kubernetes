#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ROOT_DIR}/formando/compose/.env.prod"
BASE_FILE="${ROOT_DIR}/formando/compose/compose.yaml"
PROD_FILE="${ROOT_DIR}/formando/compose/compose.prod.yaml"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERRO: ${ENV_FILE} não existe." >&2
  echo "Copie .env.prod.example para .env.prod." >&2
  exit 1
fi

exec docker compose \
  --env-file "$ENV_FILE" \
  -f "$BASE_FILE" \
  -f "$PROD_FILE" \
  "$@"
