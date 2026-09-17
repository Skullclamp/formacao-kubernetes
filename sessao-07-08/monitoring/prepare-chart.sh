#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Uso: $0 <versao-kube-prometheus-stack-validada>"
  echo "A versão deve ser escolhida e testada previamente no cluster da formação."
  exit 1
fi

command -v helm >/dev/null 2>&1 || {
  echo "ERRO: Helm não encontrado no PATH."
  echo "Instalar/validar primeiro com:"
  echo "  bash 00-precheck/install-helm.sh"
  exit 1
}

VERSION="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="$ROOT_DIR/packages"
PACKAGE="$DEST_DIR/kube-prometheus-stack-$VERSION.tgz"

mkdir -p "$DEST_DIR"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo update
helm pull prometheus-community/kube-prometheus-stack \
  --version "$VERSION" \
  --destination "$DEST_DIR"

echo
printf 'Chart preparado em: %s\n' "$PACKAGE"
printf 'Metadados do chart descarregado:\n'
helm show chart "$PACKAGE"

echo
printf 'ATENÇÃO: descarregar o chart não constitui validação.\n'
printf 'Testar esta versão no cluster de formação antes de a congelar para a sessão.\n'
