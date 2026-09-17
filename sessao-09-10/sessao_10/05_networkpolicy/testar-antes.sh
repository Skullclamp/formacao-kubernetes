#!/usr/bin/env bash
set -euo pipefail
NS="${NS:-s10-validacao}"

echo "== ANTES da NetworkPolicy =="
for pod in client-allowed client-blocked; do
  printf '%s -> ' "$pod"
  kubectl -n "$NS" exec "$pod" -- wget -T 3 -qO- http://symfony-demo/health
  echo
done

echo "Baseline de conectividade: OK"
