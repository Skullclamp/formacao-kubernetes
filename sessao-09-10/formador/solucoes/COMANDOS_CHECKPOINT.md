# Comandos de checkpoint — Sessão 10

Assumir:

```bash
export NS=s10-validacao
```

## Estado geral

```bash
kubectl -n "$NS" get deployment symfony-demo
kubectl -n "$NS" get statefulset postgres
kubectl -n "$NS" get pods -o wide
kubectl -n "$NS" get svc,pvc,hpa
```

## Eventos

```bash
kubectl -n "$NS" get events --sort-by='.lastTimestamp' | tail -25
```

## HPA

```bash
kubectl -n "$NS" get hpa
kubectl -n "$NS" describe hpa symfony-demo
kubectl -n "$NS" top pods
```

## SecurityContext

```bash
kubectl -n "$NS" get pods -l app=symfony-demo \
  -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[0].ready,SA:.spec.serviceAccountName,NODE:.spec.nodeName'
```

## NetworkPolicy

```bash
bash 05_networkpolicy/testar-antes.sh
kubectl -n "$NS" apply -f 05_networkpolicy/networkpolicy.yaml
bash 05_networkpolicy/testar-depois.sh
```

## Release candidata

```bash
kubectl -n "$NS" patch deployment symfony-demo \
  --type strategic \
  --patch-file 06_rollback/patch-release-candidata.yaml
kubectl -n "$NS" rollout status deployment/symfony-demo --timeout=30s || true
```

## Rollback

```bash
kubectl -n "$NS" rollout history deployment/symfony-demo
kubectl -n "$NS" rollout undo deployment/symfony-demo
kubectl -n "$NS" rollout status deployment/symfony-demo --timeout=120s
```
