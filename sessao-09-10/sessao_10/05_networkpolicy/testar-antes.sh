#!/usr/bin/env bash
set -euo pipefail

NS="${NS:-$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)}"
if [ -z "$NS" ]; then
  echo "ERRO: namespace não definido em \$NS nem no contexto kubectl atual."
  exit 1
fi

check_client() {
  local pod="$1"
  local expected_label="$2"
  local phase ready label

  if ! kubectl -n "$NS" get pod "$pod" >/dev/null 2>&1; then
    echo "ERRO: Pod $pod não existe."
    exit 1
  fi

  phase="$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.status.phase}')"
  ready="$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')"
  label="$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.metadata.labels.access}')"

  printf '%s: phase=%s ready=%s access=%s\n' "$pod" "$phase" "$ready" "$label"

  if [ "$phase" != "Running" ] || [ "$ready" != "True" ]; then
    echo "ERRO: $pod não está Running/Ready; o teste de rede não seria conclusivo."
    exit 1
  fi

  if [ "$label" != "$expected_label" ]; then
    echo "ERRO: $pod tem access=$label; esperado access=$expected_label."
    exit 1
  fi
}

echo "== ANTES da NetworkPolicy =="
check_client client-allowed symfony-demo
check_client client-blocked blocked

if kubectl -n "$NS" get networkpolicy symfony-demo-ingress >/dev/null 2>&1; then
  echo "ERRO: NetworkPolicy symfony-demo-ingress já existe."
  echo "Remover a policy antes de estabelecer a baseline ANTES."
  exit 1
fi

echo "NetworkPolicy symfony-demo-ingress: ausente (esperado)."
echo

for pod in client-allowed client-blocked; do
  printf '%s -> ' "$pod"
  kubectl -n "$NS" exec "$pod" -- wget -T 3 -qO- http://symfony-demo/health
  echo
done

echo "Baseline de conectividade: OK — ambos os clientes alcançam o mesmo endpoint /health."
