#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Uso: $0 VERSION" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ROOT_DIR}/formando/compose/.env.prod"
BASE_FILE="${ROOT_DIR}/formando/compose/compose.yaml"
PROD_FILE="${ROOT_DIR}/formando/compose/compose.prod.yaml"
VALIDATE="${ROOT_DIR}/formando/scripts/validate.sh"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERRO: .env.prod não existe. Copie .env.prod.example." >&2
  exit 1
fi

if grep -q '^APP_VERSION=' "$ENV_FILE"; then
  sed -i "s/^APP_VERSION=.*/APP_VERSION=${VERSION}/" "$ENV_FILE"
else
  printf '\nAPP_VERSION=%s\n' "$VERSION" >> "$ENV_FILE"
fi

COMPOSE=(docker compose --env-file "$ENV_FILE" -f "$BASE_FILE" -f "$PROD_FILE")

"${COMPOSE[@]}" config >/dev/null

APP_PORT="${APP_PORT:-$(awk -F= '$1=="APP_PORT"{print $2}' "$ENV_FILE" | tail -1)}"
APP_PORT="${APP_PORT:-8080}"

if ! [[ "$APP_PORT" =~ ^[0-9]+$ ]] || (( APP_PORT < 1 || APP_PORT > 65535 )); then
  echo "ERRO: APP_PORT inválida: ${APP_PORT}" >&2
  exit 1
fi

OWN_CID="$(${COMPOSE[@]} ps -q app 2>/dev/null || true)"

while read -r cid; do
  [[ -z "$cid" ]] && continue
  if [[ "$cid" != "$OWN_CID" ]]; then
    echo "ERRO: porta ${APP_PORT} já publicada por outro container:" >&2
    docker ps --filter "id=${cid}" --format '  {{.ID}} {{.Names}} {{.Image}} {{.Ports}}' >&2
    exit 1
  fi
done < <(docker ps -q --filter "publish=${APP_PORT}")

if [[ -z "$OWN_CID" ]] && command -v ss >/dev/null 2>&1; then
  if ss -ltn "sport = :${APP_PORT}" | tail -n +2 | grep -q .; then
    echo "ERRO: porta ${APP_PORT} já está em utilização no host." >&2
    ss -ltnp "sport = :${APP_PORT}" >&2 || true
    exit 1
  fi
fi

echo "==> Pull"
"${COMPOSE[@]}" pull db app

echo "==> PostgreSQL"
"${COMPOSE[@]}" up -d db

DB_CID="$(${COMPOSE[@]} ps -q db)"
for _ in $(seq 1 20); do
  STATUS="$(docker inspect "$DB_CID" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}starting{{end}}')"
  [[ "$STATUS" == "healthy" ]] && break
  sleep 3
done

if [[ "$(docker inspect "$DB_CID" --format '{{.State.Health.Status}}')" != "healthy" ]]; then
  echo "ERRO: PostgreSQL não ficou healthy." >&2
  exit 1
fi

SCHEMA_EXISTS="$("${COMPOSE[@]}" exec -T db \
  psql -U symfony -d symfony -tAc \
  "SELECT 1 FROM pg_tables WHERE schemaname='public' AND tablename='symfony_demo_post';")"

if [[ "$SCHEMA_EXISTS" == "1" ]]; then
  echo "Schema da aplicação já inicializado; sem alterações automáticas."
else
  echo "Schema da aplicação não encontrado. A inicializar..."
  "${COMPOSE[@]}" run --rm app \
    php bin/console doctrine:schema:create --no-interaction
fi

echo "==> Aplicação ${VERSION}"
"${COMPOSE[@]}" up -d app
sleep 8

"$VALIDATE"
