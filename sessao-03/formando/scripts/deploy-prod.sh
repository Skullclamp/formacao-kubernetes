#!/usr/bin/env bash

# Modo seguro: termina perante erro, variável não definida ou falha num pipeline.
set -euo pipefail

# A versão a colocar em execução é recebida no primeiro argumento.
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Uso: $0 VERSION" >&2
  exit 2
fi

# Localiza os ficheiros necessários e o script de validação.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ROOT_DIR}/formando/compose/.env.prod"
BASE_FILE="${ROOT_DIR}/formando/compose/compose.yaml"
PROD_FILE="${ROOT_DIR}/formando/compose/compose.prod.yaml"
VALIDATE="${ROOT_DIR}/formando/scripts/validate.sh"

# O deployment depende de um .env.prod local criado a partir do exemplo.
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERRO: .env.prod não existe. Copie .env.prod.example." >&2
  exit 1
fi

# Atualiza APP_VERSION no .env.prod.
# Se a variável já existir, sed substitui a linha; se não existir, printf acrescenta-a.
if grep -q '^APP_VERSION=' "$ENV_FILE"; then
  sed -i "s/^APP_VERSION=.*/APP_VERSION=${VERSION}/" "$ENV_FILE"
else
  printf '\nAPP_VERSION=%s\n' "$VERSION" >> "$ENV_FILE"
fi

# Guarda o comando Compose completo num array para reutilização consistente.
COMPOSE=(docker compose --env-file "$ENV_FILE" -f "$BASE_FILE" -f "$PROD_FILE")

# Valida a configuração efetiva antes de alterar containers.
# O output é descartado; interessa o exit code do comando.
"${COMPOSE[@]}" config >/dev/null

# Determina a porta publicada pela aplicação.
# Dá prioridade à variável exportada no shell, depois ao .env.prod e por fim a 8080.
APP_PORT="${APP_PORT:-$(awk -F= '$1=="APP_PORT"{print $2}' "$ENV_FILE" | tail -1)}"
APP_PORT="${APP_PORT:-8080}"

# Garante que a porta é numérica e pertence ao intervalo TCP/UDP válido.
if ! [[ "$APP_PORT" =~ ^[0-9]+$ ]] || (( APP_PORT < 1 || APP_PORT > 65535 )); then
  echo "ERRO: APP_PORT inválida: ${APP_PORT}" >&2
  exit 1
fi

# Obtém o ID do container app já pertencente a esta stack, se existir.
OWN_CID="$(${COMPOSE[@]} ps -q app 2>/dev/null || true)"

# Procura outros containers que já publiquem a mesma porta.
# Se encontrar um container diferente do nosso, interrompe o deployment.
while read -r cid; do
  [[ -z "$cid" ]] && continue
  if [[ "$cid" != "$OWN_CID" ]]; then
    echo "ERRO: porta ${APP_PORT} já publicada por outro container:" >&2
    docker ps --filter "id=${cid}" --format '  {{.ID}} {{.Names}} {{.Image}} {{.Ports}}' >&2
    exit 1
  fi
done < <(docker ps -q --filter "publish=${APP_PORT}")

# Se não existe ainda container app, verifica também processos do próprio host.
# ss lista sockets em escuta e evita tentar publicar uma porta já ocupada fora do Docker.
if [[ -z "$OWN_CID" ]] && command -v ss >/dev/null 2>&1; then
  if ss -ltn "sport = :${APP_PORT}" | tail -n +2 | grep -q .; then
    echo "ERRO: porta ${APP_PORT} já está em utilização no host." >&2
    ss -ltnp "sport = :${APP_PORT}" >&2 || true
    exit 1
  fi
fi

# Obtém do registry as imagens configuradas para app e db.
# pull não reconstrói a aplicação: consome o artefacto já publicado.
echo "==> Pull"
"${COMPOSE[@]}" pull db app

# Inicia primeiro o PostgreSQL em background.
echo "==> PostgreSQL"
"${COMPOSE[@]}" up -d db

# Obtém o ID do container da base de dados e aguarda pelo respetivo HEALTHCHECK.
# Faz até 20 tentativas com intervalo de 3 segundos.
DB_CID="$(${COMPOSE[@]} ps -q db)"
for _ in $(seq 1 20); do
  STATUS="$(docker inspect "$DB_CID" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}starting{{end}}')"
  [[ "$STATUS" == "healthy" ]] && break
  sleep 3
done

# Se a base de dados não ficar healthy, não prossegue para a aplicação.
if [[ "$(docker inspect "$DB_CID" --format '{{.State.Health.Status}}')" != "healthy" ]]; then
  echo "ERRO: PostgreSQL não ficou healthy." >&2
  exit 1
fi

# Verifica se a tabela principal da Symfony Demo já existe.
# -T desativa pseudo-TTY; -tA remove formatação extra; -c executa o SQL fornecido.
SCHEMA_EXISTS="$("${COMPOSE[@]}" exec -T db \
  psql -U symfony -d symfony -tAc \
  "SELECT 1 FROM pg_tables WHERE schemaname='public' AND tablename='symfony_demo_post';")"

# Só numa base de dados vazia cria o schema didático.
# Em produção real, alterações de schema devem ser feitas por migrations explícitas.
if [[ "$SCHEMA_EXISTS" == "1" ]]; then
  echo "Schema da aplicação já inicializado; sem alterações automáticas."
else
  echo "Schema da aplicação não encontrado. A inicializar..."
  "${COMPOSE[@]}" run --rm app \
    php bin/console doctrine:schema:create --no-interaction
fi

# Inicia/atualiza o serviço app com a versão escolhida.
echo "==> Aplicação ${VERSION}"
"${COMPOSE[@]}" up -d app

# Pequena espera para permitir o arranque antes das validações HTTP/healthcheck.
sleep 8

# Executa a validação comum: /health, /ready, /info e Docker HEALTHCHECK.
"$VALIDATE"
