#!/usr/bin/env bash
set -u

fail=0
NS="${NS:-$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)}"
NS="${NS:-default}"

section() { printf '\n== %s ==\n' "$1"; }

section "Namespace"
echo "$NS"

section "Objetos principais"
kubectl -n "$NS" get deployment symfony-demo || fail=1
kubectl -n "$NS" get statefulset postgres || fail=1
kubectl -n "$NS" get service symfony-demo postgres || fail=1
kubectl -n "$NS" get pvc || fail=1

section "Secret — apenas nomes das chaves"
if kubectl -n "$NS" get secret postgres-credentials >/dev/null 2>&1; then
  kubectl -n "$NS" get secret postgres-credentials \
    -o go-template='{{range $k,$v := .data}}{{$k}}{{"\n"}}{{end}}' | sort
else
  echo "Secret postgres-credentials: EM FALTA"
  fail=1
fi

section "ConfigMap"
kubectl -n "$NS" get configmap symfony-demo-config \
  -o go-template='{{range $k,$v := .data}}{{$k}}{{"\n"}}{{end}}' 2>/dev/null | sort || fail=1

section "Rollouts"
kubectl -n "$NS" rollout status statefulset/postgres --timeout=120s || fail=1
kubectl -n "$NS" rollout status deployment/symfony-demo --timeout=120s || fail=1

section "PostgreSQL"
kubectl -n "$NS" exec postgres-0 -- \
  sh -c 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' || fail=1

section "PVC"
kubectl -n "$NS" get pvc \
  -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,SC:.spec.storageClassName,SIZE:.spec.resources.requests.storage'

PVC_NAME="data-postgres-0"
if PVC_PHASE="$(kubectl -n "$NS" get pvc "$PVC_NAME" -o jsonpath='{.status.phase}' 2>/dev/null)"; then
  PVC_SC="$(kubectl -n "$NS" get pvc "$PVC_NAME" -o jsonpath='{.spec.storageClassName}' 2>/dev/null)"
  PVC_SIZE="$(kubectl -n "$NS" get pvc "$PVC_NAME" -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)"

  printf '%s: phase=%s storageClass=%s size=%s\n' \
    "$PVC_NAME" "$PVC_PHASE" "$PVC_SC" "$PVC_SIZE"

  if [ "$PVC_PHASE" != "Bound" ]; then
    echo "$PVC_NAME: esperado phase=Bound, observado phase=$PVC_PHASE"
    fail=1
  fi
else
  echo "$PVC_NAME: EM FALTA"
  fail=1
fi

section "Imagem Symfony"
kubectl -n "$NS" get deployment symfony-demo \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}' || fail=1

section "Endpoints internos"
kubectl -n "$NS" delete pod baseline-check --ignore-not-found --wait=true >/dev/null 2>&1 || true
kubectl -n "$NS" run baseline-check \
  --image=busybox:1.36 \
  --labels="access=symfony-demo" \
  --restart=Never \
  --command -- sleep 3600 >/dev/null || fail=1
kubectl -n "$NS" wait --for=condition=Ready pod/baseline-check --timeout=60s || fail=1

for path in health ready info; do
  echo "GET /${path}"
  if ! kubectl -n "$NS" exec baseline-check -- wget -T 5 -qO- "http://symfony-demo/${path}"; then
    fail=1
  fi
  echo
done

kubectl -n "$NS" delete pod baseline-check --ignore-not-found --wait=true >/dev/null 2>&1 || true

section "Metrics"
if kubectl -n "$NS" top pods; then
  echo "Metrics: OK"
else
  echo "Metrics: INDISPONÍVEIS — não avançar para HPA."
  fail=1
fi

section "Resultado"
if [ "$fail" -eq 0 ]; then
  echo "BASELINE VALIDADO"
else
  echo "BASELINE COM PONTOS A CORRIGIR"
fi
exit "$fail"
