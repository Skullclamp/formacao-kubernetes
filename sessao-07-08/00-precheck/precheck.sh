#!/usr/bin/env bash
set -euo pipefail

fail=0

ok()   { printf 'OK   %s\n' "$1"; }
warn() { printf 'WARN %s\n' "$1"; }
err()  { printf 'ERRO %s\n' "$1"; fail=1; }

command -v kubectl >/dev/null 2>&1 && ok 'kubectl disponível' || err 'kubectl não encontrado'
command -v helm >/dev/null 2>&1 && ok 'Helm disponível' || err 'Helm não encontrado'

if command -v kubectl >/dev/null 2>&1; then
  kubectl cluster-info >/dev/null 2>&1 && ok 'API Kubernetes acessível' || err 'API Kubernetes inacessível'

  ready_workers=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2 ~ /Ready/ && $3 !~ /control-plane|master/ {c++} END {print c+0}')
  if [ "$ready_workers" -ge 2 ]; then
    ok "pelo menos 2 Worker Nodes Ready ($ready_workers)"
  else
    err "são necessários pelo menos 2 Worker Nodes Ready; encontrados: $ready_workers"
  fi

  kubectl get storageclass local-path >/dev/null 2>&1 \
    && ok 'StorageClass local-path disponível' \
    || err 'StorageClass local-path não encontrada'

  if kubectl get pods -A 2>/dev/null | grep -qi calico; then
    ok 'Calico identificado no cluster'
  else
    warn 'Calico não identificado; validar o CNI antes dos exercícios de rede'
  fi

  if kubectl kustomize --help >/dev/null 2>&1; then
    ok 'Kustomize integrado no kubectl disponível'
  else
    err 'kubectl kustomize indisponível'
  fi
fi

if command -v helm >/dev/null 2>&1; then
  helm version --short || true
fi

printf '\nResumo de Nodes:\n'
kubectl get nodes -o wide 2>/dev/null || true

printf '\nStorageClasses:\n'
kubectl get storageclass 2>/dev/null || true

if [ "$fail" -ne 0 ]; then
  printf '\nPré-validação concluída com erros. Corrigir antes do laboratório.\n'
  exit 1
fi

printf '\nPré-validação concluída com sucesso.\n'
