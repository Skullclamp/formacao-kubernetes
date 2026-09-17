#!/usr/bin/env bash
set -euo pipefail

fail=0
api_ok=0

ok()   { printf 'OK   %s\n' "$1"; }
warn() { printf 'WARN %s\n' "$1"; }
err()  { printf 'ERRO %s\n' "$1"; fail=1; }

command -v git >/dev/null 2>&1 && ok 'git disponível' || err 'git não encontrado'
command -v kubectl >/dev/null 2>&1 && ok 'kubectl disponível' || err 'kubectl não encontrado'
if command -v helm >/dev/null 2>&1; then
  ok 'Helm disponível'
else
  err 'Helm não encontrado'
  printf '     Instalar/validar com: bash 00-precheck/install-helm.sh\n'
fi

if command -v kubectl >/dev/null 2>&1; then
  if kubectl cluster-info >/dev/null 2>&1; then
    ok 'API Kubernetes acessível'
    api_ok=1
  else
    err 'API Kubernetes inacessível'
  fi
fi

if [ "$api_ok" -eq 1 ]; then
  ready_workers=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2 == "Ready" && $3 !~ /control-plane|master/ {c++} END {print c+0}')
  if [ "$ready_workers" -ge 2 ]; then
    ok "pelo menos 2 Worker Nodes Ready ($ready_workers)"
  else
    err "são necessários pelo menos 2 Worker Nodes Ready; encontrados: $ready_workers"
  fi

  kubectl get storageclass local-path >/dev/null 2>&1 \
    && ok 'StorageClass local-path disponível' \
    || err 'StorageClass local-path não encontrada'

  # Não usar `kubectl ... | grep -q` com `set -o pipefail`: o grep pode sair
  # após a primeira correspondência e provocar SIGPIPE no kubectl, originando
  # um falso negativo. Identificamos diretamente o DaemonSet calico-node e
  # comparamos o número desejado de Pods com o número Ready.
  calico_ns=$(kubectl get daemonset -A \
    -o jsonpath='{range .items[?(@.metadata.name=="calico-node")]}{.metadata.namespace}{"\n"}{end}' \
    2>/dev/null || true)

  if [ -n "$calico_ns" ]; then
    desired=$(kubectl get daemonset calico-node -n "$calico_ns" \
      -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || true)
    ready=$(kubectl get daemonset calico-node -n "$calico_ns" \
      -o jsonpath='{.status.numberReady}' 2>/dev/null || true)

    if [ -n "$desired" ] && [ "$desired" -gt 0 ] && [ "$ready" -eq "$desired" ]; then
      ok "Calico operacional: calico-node $ready/$desired Ready em $calico_ns"
    else
      warn "Calico identificado em $calico_ns, mas calico-node não está totalmente Ready ($ready/$desired)"
    fi
  else
    warn 'DaemonSet calico-node não identificado; validar o CNI'
  fi

  kubectl kustomize --help >/dev/null 2>&1 \
    && ok 'Kustomize integrado no kubectl disponível' \
    || err 'kubectl kustomize indisponível'

  kubectl get crd prometheusrules.monitoring.coreos.com >/dev/null 2>&1 \
    && ok 'CRD PrometheusRule disponível' \
    || err 'Prometheus Operator/CRD não preparado; o formador deve instalar a monitorização antes da sessão'

  kubectl get namespace monitoring >/dev/null 2>&1 \
    && ok 'Namespace monitoring disponível' \
    || err 'Namespace monitoring não encontrado'
fi

if command -v helm >/dev/null 2>&1; then
  helm version --short || true

  # Tal como no teste do CNI, evitamos `grep -q` sob pipefail para não
  # transformar um eventual SIGPIPE do comando a montante num falso negativo.
  if helm upgrade --help 2>/dev/null | grep -- '--take-ownership' >/dev/null; then
    ok 'Helm suporta --take-ownership'
  else
    err 'Helm não suporta --take-ownership; atualizar Helm antes do laboratório'
  fi

  helm status monitoring -n monitoring >/dev/null 2>&1 \
    && ok 'release monitoring disponível' \
    || err 'release monitoring não está operacional; preparar antes da sessão'
fi

if [ "$api_ok" -eq 1 ]; then
  printf '\nResumo de Nodes:\n'
  kubectl get nodes -o wide 2>/dev/null || true
fi

if [ "$fail" -ne 0 ]; then
  printf '\nPré-validação concluída com erros. Corrigir antes do laboratório.\n'
  exit 1
fi

printf '\nPré-validação concluída com sucesso.\n'
