#!/usr/bin/env bash
set -euo pipefail

NS="${NS:-s10-validacao}"
POD="hpa-load"

echo "=== HPA | Iniciar carga ==="
kubectl -n "$NS" delete pod "$POD" --ignore-not-found --wait=true >/dev/null 2>&1 || true

kubectl -n "$NS" run "$POD" \
  --image=busybox:1.36 \
  --labels="access=symfony-demo" \
  --restart=Never \
  --command -- sh -c '
    for i in $(seq 1 30); do
      while true; do
        wget -qO- http://symfony-demo/health >/dev/null 2>&1
      done &
    done
    wait
  '

kubectl -n "$NS" wait --for=condition=Ready pod/"$POD" --timeout=60s

echo
echo "Carga ativa."
echo "Observar noutro terminal:"
echo "  kubectl -n $NS get hpa"
echo "  kubectl -n $NS top pods"
echo "  kubectl -n $NS get pods"
echo
echo "Terminar com: ./02_hpa/parar-carga.sh"
