#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKUP_DIR="${ROOT_DIR}/formando/compose/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${BACKUP_DIR}/symfony-${STAMP}.sql"

mkdir -p "$BACKUP_DIR"

"${ROOT_DIR}/formando/scripts/compose-prod.sh" exec -T db \
  pg_dump -U symfony -d symfony > "$OUT"

if [[ ! -s "$OUT" ]]; then
  echo "ERRO: backup vazio: ${OUT}" >&2
  exit 1
fi

echo "Backup criado: ${OUT}"
