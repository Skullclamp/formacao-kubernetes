#!/usr/bin/env bash

# Interrompe o script perante erros, variáveis não definidas ou falhas em pipelines.
set -euo pipefail

# Localiza a raiz da Sessão 3 e prepara os nomes usados no backup.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKUP_DIR="${ROOT_DIR}/formando/compose/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${BACKUP_DIR}/symfony-${STAMP}.sql"
COMPOSE_WRAPPER="${ROOT_DIR}/formando/scripts/compose-prod.sh"

# Cria a diretoria de backups se ainda não existir.
# -p evita erro se a diretoria já existir e cria diretórios intermédios necessários.
mkdir -p "$BACKUP_DIR"

# Executa pg_dump dentro do serviço db através do wrapper Compose.
# Em vez de repetir utilizador/base de dados no script, reutilizamos as variáveis
# POSTGRES_USER e POSTGRES_DB que o próprio compose.yaml entrega ao container db.
# Assim, o backup permanece coerente se os valores didáticos de .env.prod forem alterados.
# -T desativa pseudo-TTY, importante porque o stdout é redirecionado para o host.
"$COMPOSE_WRAPPER" exec -T db \
  sh -c 'exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
  > "$OUT"

# Confirma que o ficheiro existe e tem tamanho superior a zero.
# -s testa precisamente se o ficheiro não está vazio.
if [[ ! -s "$OUT" ]]; then
  echo "ERRO: backup vazio: ${OUT}" >&2
  exit 1
fi

# Mostra ao operador o caminho do ficheiro criado.
echo "Backup criado: ${OUT}"
