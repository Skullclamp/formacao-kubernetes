#!/usr/bin/env bash

# Ativa tratamento rigoroso de erros e variáveis.
set -euo pipefail

# Usa a versão indicada no primeiro argumento; se não for fornecida,
# assume 1.1.0 como última versão conhecida como válida no laboratório.
VERSION="${1:-1.1.0}"

# Determina a raiz da Sessão 3 para localizar o script de deployment.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Informa o operador da versão escolhida para recuperação.
echo "Rollback para versão conhecida como boa: ${VERSION}"

# O rollback reutiliza exatamente o mesmo mecanismo de deployment,
# mas fornecendo uma versão anterior conhecida como válida.
# exec substitui este processo pelo deploy-prod.sh.
exec "${ROOT_DIR}/formando/scripts/deploy-prod.sh" "$VERSION"
