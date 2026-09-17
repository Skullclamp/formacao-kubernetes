#!/usr/bin/env bash
set -euo pipefail
NS="${NS:-s10-validacao}"

echo "Namespace alvo: $NS"
echo "Este script remove apenas recursos temporários do laboratório, não o PostgreSQL/Symfony principal."
read -r -p "Continuar? [s/N] " ans
[[ "$ans" =~ ^[sS]$ ]] || exit 0

kubectl -n "$NS" delete pod hpa-load client-allowed client-blocked obs-client \
  --ignore-not-found --wait=false || true
kubectl -n "$NS" delete deployment symfony-troubleshoot --ignore-not-found || true
kubectl -n "$NS" delete service symfony-troubleshoot --ignore-not-found || true

echo "Recursos temporários removidos."
echo "Para eliminar todo o ambiente, rever primeiro e executar manualmente:"
echo "  kubectl delete namespace $NS"
