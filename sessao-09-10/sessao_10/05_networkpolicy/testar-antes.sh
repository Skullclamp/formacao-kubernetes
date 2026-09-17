#!/usr/bin/env bash
set -euo pipefail

NS="${NS:-$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)}"
if [ -z "$NS" ]; then
  echo "ERRO: namespace não definido em \$NS nem no contexto kubectl atual."
  exit 1
fi

echo "== ANTES da NetworkPolicy =="
for pod in client-allowed client-blocked; do
  printf '%s -> ' "$pod"
  kubectl -n "$NS" exec "$pod" -- wget -T 3 -qO- http://symfony-demo/health
  echo
done

echo "Baseline de conectividade: OK"
