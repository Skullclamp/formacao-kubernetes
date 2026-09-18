#!/usr/bin/env bash
set -euo pipefail

NS="${NS:-$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)}"
if [ -z "$NS" ]; then
  echo "ERRO: namespace não definido em \$NS nem no contexto kubectl atual."
  exit 1
fi

echo "=== HPA | Terminar carga ==="
kubectl -n "$NS" delete pod hpa-load --ignore-not-found --wait=true
echo "Carga terminada."
