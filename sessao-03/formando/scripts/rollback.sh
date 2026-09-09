#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.1.0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "Rollback para versão conhecida como boa: ${VERSION}"
exec "${ROOT_DIR}/formando/scripts/deploy-prod.sh" "$VERSION"
