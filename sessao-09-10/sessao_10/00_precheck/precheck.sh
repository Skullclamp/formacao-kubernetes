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
kubectl -n kube-system get pods -l k8s-app=calico-node 2>/dev/null || \
  echo "AVISO: não foi possível confirmar Calico por esta label. Confirmar o CNI antes da NetworkPolicy."
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
