#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Uso: $0 <versao-kube-prometheus-stack>"
  echo "Exemplo: $0 77.0.0"
  exit 1
fi

VERSION="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="$ROOT_DIR/packages"

mkdir -p "$DEST_DIR"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo update
helm pull prometheus-community/kube-prometheus-stack \
  --version "$VERSION" \
  --destination "$DEST_DIR"

echo
printf 'Chart preparado em %s\n' "$DEST_DIR"
printf 'Validar antes da formação com:\n  helm show chart %s/kube-prometheus-stack-%s.tgz\n' "$DEST_DIR" "$VERSION"
