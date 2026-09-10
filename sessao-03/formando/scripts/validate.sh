#!/usr/bin/env bash

# Garante que qualquer erro relevante interrompe a validação.
set -euo pipefail

# Localiza os ficheiros Compose e o ambiente de produção.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ROOT_DIR}/formando/compose/.env.prod"
BASE_FILE="${ROOT_DIR}/formando/compose/compose.yaml"
PROD_FILE="${ROOT_DIR}/formando/compose/compose.prod.yaml"

# Guarda o comando Compose completo num array para o reutilizar sem repetir opções.
COMPOSE=(docker compose --env-file "$ENV_FILE" -f "$BASE_FILE" -f "$PROD_FILE")

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

# Valida os três endpoints pedagógicos da aplicação.
# curl -f falha em HTTP 4xx/5xx; -s reduz ruído; -S continua a mostrar erros.
for path in health ready info; do
  echo "==> GET /${path}"
  curl -fsS "${BASE_URL}/${path}"
  echo
done

# Obtém apenas o ID do container do serviço app.
CID="$(${COMPOSE[@]} ps -q app)"
if [[ -z "$CID" ]]; then
  echo "ERRO: container app não encontrado." >&2
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
