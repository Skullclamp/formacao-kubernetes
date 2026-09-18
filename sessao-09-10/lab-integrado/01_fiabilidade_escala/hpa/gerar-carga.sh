#!/usr/bin/env bash
set -euo pipefail

NS="${NS:-$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)}"
if [ -z "$NS" ]; then
  echo "ERRO: namespace não definido em \$NS nem no contexto kubectl atual."
  exit 1
fi

POD="hpa-load"

echo "=== HPA | Iniciar carga ==="

if ! kubectl -n "$NS" get hpa symfony-demo >/dev/null 2>&1; then
  echo "ERRO: HPA symfony-demo não existe no namespace $NS."
  echo "Aplicar 01_fiabilidade_escala/hpa/hpa.yaml antes de iniciar a carga."
  exit 1
fi

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

echo "=== HPA | Preflight HTTP a partir do Pod de carga ==="
if kubectl -n "$NS" exec "$POD" -- wget -T 5 -qO- http://symfony-demo/health >/dev/null; then
  echo "Preflight HTTP: OK"
else
  echo "ERRO: o Pod de carga está Running/Ready, mas não consegue chegar a http://symfony-demo/health."
  echo "A carga não pode ser considerada válida."
  kubectl -n "$NS" delete pod "$POD" --ignore-not-found --wait=true >/dev/null 2>&1 || true
  exit 1
fi

echo
echo "Carga ativa e conectividade ao endpoint confirmada."
echo "Observar noutro terminal:"
echo "  kubectl -n $NS get hpa"
echo "  kubectl -n $NS top pods"
echo "  kubectl -n $NS get pods"
echo
echo "Terminar com: ./01_fiabilidade_escala/hpa/parar-carga.sh"
