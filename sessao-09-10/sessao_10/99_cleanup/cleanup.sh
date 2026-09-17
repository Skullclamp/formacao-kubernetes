#!/usr/bin/env bash
set -euo pipefail

NS="${NS:-$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)}"
if [ -z "$NS" ]; then
  echo "ERRO: namespace não definido em \$NS nem no contexto kubectl atual."
  exit 1
fi

echo "Namespace alvo: $NS"
echo "Este script remove recursos auxiliares do laboratório e repõe o Symfony em 2 réplicas."
echo "Não remove o PostgreSQL nem o Deployment/Service principal do Symfony."
read -r -p "Continuar? [s/N] " ans
[[ "$ans" =~ ^[sS]$ ]] || exit 0

echo
echo "== Remover controladores/regras temporários =="
kubectl -n "$NS" delete hpa symfony-demo --ignore-not-found
kubectl -n "$NS" delete networkpolicy symfony-demo-ingress --ignore-not-found

echo
echo "== Remover Pods e workloads auxiliares =="
kubectl -n "$NS" delete pod hpa-load client-allowed client-blocked obs-client \
  --ignore-not-found --wait=false
kubectl -n "$NS" delete deployment symfony-troubleshoot --ignore-not-found
kubectl -n "$NS" delete service symfony-troubleshoot --ignore-not-found

echo
echo "== Repor réplicas do Symfony =="
if kubectl -n "$NS" get deployment symfony-demo >/dev/null 2>&1; then
  kubectl -n "$NS" scale deployment symfony-demo --replicas=2
  kubectl -n "$NS" rollout status deployment/symfony-demo --timeout=120s
else
  echo "ERRO: Deployment symfony-demo não existe; não é possível confirmar o estado final."
  exit 1
fi

echo
echo "== Validação pós-cleanup =="

HPA_LEFT="$(kubectl -n "$NS" get hpa symfony-demo --ignore-not-found -o name)"
NP_LEFT="$(kubectl -n "$NS" get networkpolicy symfony-demo-ingress --ignore-not-found -o name)"
CLIENTS_LEFT="$(kubectl -n "$NS" get pod client-allowed client-blocked hpa-load obs-client \
  --ignore-not-found -o name)"

if [ -n "$HPA_LEFT" ]; then
  echo "ERRO: HPA symfony-demo continua presente: $HPA_LEFT"
  exit 1
fi

if [ -n "$NP_LEFT" ]; then
  echo "ERRO: NetworkPolicy symfony-demo-ingress continua presente: $NP_LEFT"
  exit 1
fi

if [ -n "$CLIENTS_LEFT" ]; then
  echo "ERRO: ainda existem Pods auxiliares:"
  printf '%s\n' "$CLIENTS_LEFT"
  exit 1
fi

kubectl -n "$NS" get deployment symfony-demo \
  -o jsonpath='deployment={.metadata.name} replicas={.spec.replicas} readyReplicas={.status.readyReplicas}{"\n"}'
kubectl -n "$NS" get statefulset postgres \
  -o jsonpath='statefulset={.metadata.name} replicas={.spec.replicas} readyReplicas={.status.readyReplicas}{"\n"}'

echo "HPA symfony-demo: removido"
echo "NetworkPolicy symfony-demo-ingress: removida"
echo "Pods auxiliares: removidos"
echo "CLEANUP VALIDADO"

echo
echo "Para eliminar todo o ambiente, rever primeiro e executar manualmente:"
echo "  kubectl delete namespace $NS"
