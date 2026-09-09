#!/usr/bin/env bash
# Verificação pós-instalação — apenas leitura.
set -u

echo "=== Cluster ==="
kubectl cluster-info || true
echo

echo "=== Nodes ==="
kubectl get nodes -o wide || true
echo

echo "=== Pods ==="
kubectl get pods -A -o wide || true
echo

echo "=== Tigera ==="
kubectl get tigerastatus 2>/dev/null || echo "tigerastatus indisponível."
echo

echo "=== Tigera Operator ==="
kubectl get pods -n tigera-operator 2>/dev/null || true
echo

echo "=== Calico ==="
kubectl get pods -n calico-system 2>/dev/null || true
echo

echo "=== CoreDNS ==="
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide 2>/dev/null || true
echo

echo "=== Contexto ==="
kubectl config current-context || true
echo

echo "Interpreta os resultados; o script não substitui a validação manual."
