#!/usr/bin/env bash
set -euo pipefail
NS="${NS:-s10-validacao}"

echo "=== HPA | Terminar carga ==="
kubectl -n "$NS" delete pod hpa-load --ignore-not-found --wait=true
echo "Carga terminada."
