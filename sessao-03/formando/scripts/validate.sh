#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ROOT_DIR}/formando/compose/.env.prod"
BASE_FILE="${ROOT_DIR}/formando/compose/compose.yaml"
PROD_FILE="${ROOT_DIR}/formando/compose/compose.prod.yaml"

COMPOSE=(docker compose --env-file "$ENV_FILE" -f "$BASE_FILE" -f "$PROD_FILE")

APP_PORT="${APP_PORT:-}"
if [[ -z "$APP_PORT" ]]; then
  APP_PORT="$(awk -F= '$1=="APP_PORT"{print $2}' "$ENV_FILE" | tail -1)"
fi
APP_PORT="${APP_PORT:-8080}"
BASE_URL="http://localhost:${APP_PORT}"

for path in health ready info; do
  echo "==> GET /${path}"
  curl -fsS "${BASE_URL}/${path}"
  echo
done

CID="$(${COMPOSE[@]} ps -q app)"
if [[ -z "$CID" ]]; then
  echo "ERRO: container app não encontrado." >&2
  exit 1
fi

echo "==> A aguardar Docker HEALTHCHECK"
for _ in $(seq 1 12); do
  STATUS="$(docker inspect "$CID" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}sem-healthcheck{{end}}')"
  echo "health=${STATUS}"
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

echo "ERRO: aplicação sem estado healthy." >&2
docker inspect "$CID" --format '{{json .State.Health}}' || true
exit 1
