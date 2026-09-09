#!/usr/bin/env bash
# Descarrega os recursos oficiais do Calico para inspeção local.
# NÃO aplica recursos ao cluster.
set -euo pipefail

: "${CALICO_VERSION:?Define explicitamente CALICO_VERSION depois de validares a compatibilidade com Kubernetes 1.37 na documentação oficial do Calico. Referência consultada em setembro de 2026: v3.32.2 (testada apenas até Kubernetes 1.36 à data). Uso: CALICO_VERSION=vX.Y.Z ./10_fetch_calico_operator.sh}"
OUT_DIR="${OUT_DIR:-./calico-${CALICO_VERSION}}"
BASE="https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests"

mkdir -p "$OUT_DIR"

curl -fL "${BASE}/v1_crd_projectcalico_org.yaml" -o "${OUT_DIR}/v1_crd_projectcalico_org.yaml"
curl -fL "${BASE}/tigera-operator.yaml" -o "${OUT_DIR}/tigera-operator.yaml"
curl -fL "${BASE}/custom-resources.yaml" -o "${OUT_DIR}/custom-resources.yaml"

echo "CIDR(s) em custom-resources.yaml:"
grep -n "cidr:" "${OUT_DIR}/custom-resources.yaml" || true

echo
echo "Antes de aplicar:"
echo "1. confirmar compatibilidade Calico <-> Kubernetes;"
echo "2. confirmar Pod CIDR 192.168.0.0/16;"
echo "3. inspecionar os ficheiros;"
echo "4. aplicar manualmente apenas depois da validação."
echo
echo "Nota atual: Calico 3.32 documenta testes com Kubernetes 1.34–1.36."
