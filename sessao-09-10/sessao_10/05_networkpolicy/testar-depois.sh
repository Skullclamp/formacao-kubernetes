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

echo "== DEPOIS da NetworkPolicy =="
check_client client-allowed symfony-demo
check_client client-blocked blocked

if ! kubectl -n "$NS" get networkpolicy symfony-demo-ingress >/dev/null 2>&1; then
  echo "ERRO: NetworkPolicy symfony-demo-ingress não existe."
  exit 1
fi

POLICY_APP="$(kubectl -n "$NS" get networkpolicy symfony-demo-ingress -o jsonpath='{.spec.podSelector.matchLabels.app}')"
POLICY_ACCESS="$(kubectl -n "$NS" get networkpolicy symfony-demo-ingress -o jsonpath='{.spec.ingress[0].from[0].podSelector.matchLabels.access}')"
POLICY_PORT="$(kubectl -n "$NS" get networkpolicy symfony-demo-ingress -o jsonpath='{.spec.ingress[0].ports[0].port}')"

printf 'policy: app=%s allowedAccess=%s port=%s\n' "$POLICY_APP" "$POLICY_ACCESS" "$POLICY_PORT"

if [ "$POLICY_APP" != "symfony-demo" ] || [ "$POLICY_ACCESS" != "symfony-demo" ] || [ "$POLICY_PORT" != "80" ]; then
  echo "ERRO: a NetworkPolicy não corresponde ao cenário esperado."
  exit 1
fi

echo
echo "== TESTE PERMITIDO =="
printf 'client-allowed -> '
kubectl -n "$NS" exec client-allowed -- wget -T 3 -qO- http://symfony-demo/health
echo

echo
echo "== TESTE BLOQUEADO =="
set +e
BLOCKED_OUTPUT="$(kubectl -n "$NS" exec client-blocked -- wget -T 3 -O- http://symfony-demo/health 2>&1)"
BLOCKED_RC=$?
set -e

printf '%s\n' "$BLOCKED_OUTPUT"

if [ "$BLOCKED_RC" -eq 0 ]; then
  echo "ERRO: client-blocked conseguiu comunicar; a policy não está a produzir o bloqueio esperado."
  exit 1
fi

if ! printf '%s\n' "$BLOCKED_OUTPUT" | grep -Eqi 'timed out|timeout'; then
  echo "ERRO: client-blocked falhou, mas a causa observada não foi um timeout."
  echo "Não concluir que a NetworkPolicy bloqueou o tráfego sem investigar esta falha."
  exit 1
fi

echo "OK: client-allowed alcança /health e client-blocked falha por timeout."
echo "Conclusão: o resultado observado é coerente com a NetworkPolicy aplicada."
