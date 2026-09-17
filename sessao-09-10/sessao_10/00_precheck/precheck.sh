#!/usr/bin/env bash
set -u

ok=1

echo "== Contexto =="
kubectl config current-context || ok=0
echo

echo "== Nodes =="
kubectl get nodes -o wide || ok=0
echo

echo "== StorageClass esperada no laboratório =="
kubectl get storageclass local-path || {
  echo "AVISO: StorageClass 'local-path' não encontrada. Adaptar o manifesto PostgreSQL."
  ok=0
}
echo

echo "== IngressClass =="
kubectl get ingressclass || echo "AVISO: sem IngressClass; o laboratório principal pode continuar via Service."
echo

echo "== CNI / Calico =="
CALICO_DS_NS="$(
  kubectl get daemonsets -A \
    -o jsonpath='{range .items[?(@.metadata.name=="calico-node")]}{.metadata.namespace}{"\n"}{end}' \
    2>/dev/null
)"

if [ -z "$CALICO_DS_NS" ]; then
  echo "Calico: DaemonSet calico-node NÃO ENCONTRADO."
  ok=0
elif [ "$(printf '%s\n' "$CALICO_DS_NS" | wc -l)" -ne 1 ]; then
  echo "Calico: foram encontrados vários DaemonSets calico-node; confirmar manualmente:"
  printf '%s\n' "$CALICO_DS_NS"
  ok=0
else
  echo "namespace=$CALICO_DS_NS"
  kubectl -n "$CALICO_DS_NS" get daemonset calico-node -o wide || ok=0

  CALICO_STATUS="$(
    kubectl -n "$CALICO_DS_NS" get daemonset calico-node \
      -o jsonpath='{.status.desiredNumberScheduled}{"\t"}{.status.currentNumberScheduled}{"\t"}{.status.updatedNumberScheduled}{"\t"}{.status.numberReady}{"\t"}{.status.numberAvailable}{"\n"}' \
      2>/dev/null
  )"

  IFS=$'\t' read -r CALICO_DESIRED CALICO_CURRENT CALICO_UPDATED CALICO_READY CALICO_AVAILABLE <<< "$CALICO_STATUS"

  printf 'Calico: desired=%s current=%s updated=%s ready=%s available=%s\n' \
    "$CALICO_DESIRED" "$CALICO_CURRENT" "$CALICO_UPDATED" "$CALICO_READY" "$CALICO_AVAILABLE"

  if [[ ! "$CALICO_DESIRED" =~ ^[0-9]+$ ]] || [ "$CALICO_DESIRED" -eq 0 ] || \
     [ "$CALICO_CURRENT" != "$CALICO_DESIRED" ] || \
     [ "$CALICO_UPDATED" != "$CALICO_DESIRED" ] || \
     [ "$CALICO_READY" != "$CALICO_DESIRED" ] || \
     [ "$CALICO_AVAILABLE" != "$CALICO_DESIRED" ]; then
    echo "Calico: DaemonSet calico-node NÃO ESTÁ totalmente convergido."
    ok=0
  else
    echo "Calico: DaemonSet calico-node totalmente convergido."
  fi
fi
echo

echo "== Metrics API / HPA =="
if kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null 2>&1 && kubectl top nodes; then
  echo "Metrics Server: OK"
else
  echo "Metrics Server: INDISPONÍVEL — corrigir antes do exercício HPA."
  ok=0
fi
echo

echo "== Helm =="
if command -v helm >/dev/null 2>&1; then
  if helm version --short; then
    :
  else
    echo "helm: encontrado, mas não foi possível obter a versão."
    ok=0
  fi
else
  echo "helm: INDISPONÍVEL — necessário para a microprática M6."
  ok=0
fi
echo

echo "== Kustomize via kubectl =="
if kubectl kustomize --help >/dev/null 2>&1; then
  echo "kubectl kustomize: OK"
else
  echo "kubectl kustomize: INDISPONÍVEL — necessário para a microprática M6."
  ok=0
fi

echo
if [ "$ok" -eq 1 ]; then
  echo "PRECHECK PRINCIPAL: OK"
  exit 0
else
  echo "PRECHECK PRINCIPAL: existem pontos a corrigir/adaptar."
  exit 1
fi
