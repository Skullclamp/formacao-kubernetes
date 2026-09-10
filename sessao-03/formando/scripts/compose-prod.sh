#!/usr/bin/env bash

# Ativa comportamento seguro do Bash para falhas, variáveis inexistentes e pipelines.
set -euo pipefail

# Determina a raiz da Sessão 3 e centraliza os caminhos dos ficheiros Compose.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ROOT_DIR}/formando/compose/.env.prod"
BASE_FILE="${ROOT_DIR}/formando/compose/compose.yaml"
PROD_FILE="${ROOT_DIR}/formando/compose/compose.prod.yaml"

# O wrapper exige uma cópia local de .env.prod.example.
# >&2 envia a mensagem para stderr e exit 1 assinala falha operacional.
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERRO: ${ENV_FILE} não existe." >&2
  echo "Copie .env.prod.example para .env.prod." >&2
  exit 1
fi

# Substitui o próprio processo pelo comando docker compose:
# --env-file fornece as variáveis;
# os dois -f fazem merge do ficheiro base com o override de produção;
# "$@" encaminha todos os argumentos recebidos, por exemplo ps, logs ou exec.
exec docker compose \
  --env-file "$ENV_FILE" \
  -f "$BASE_FILE" \
  -f "$PROD_FILE" \
  "$@"
