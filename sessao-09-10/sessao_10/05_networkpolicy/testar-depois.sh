#!/usr/bin/env bash
set -euo pipefail
NS="${NS:-s10-validacao}"

echo "== DEPOIS da NetworkPolicy =="
printf 'client-allowed -> '
kubectl -n "$NS" exec client-allowed -- wget -T 3 -qO- http://symfony-demo/ready
echo

if kubectl -n "$NS" exec client-blocked -- wget -T 3 -qO- http://symfony-demo/health; then
  echo
  echo "ERRO: client-blocked conseguiu comunicar."
  exit 1
else
  echo
  echo "OK: client-blocked foi bloqueado pela NetworkPolicy."
fi
