# Observabilidade/troubleshooting — cenário opcional validado

Este exercício foi validado em runtime, mas **não faz parte dos 80 minutos do percurso principal**. Pode ser usado como demonstração adicional, exercício de recuperação ou alternativa ao troubleshooting embebido no cenário de rollback.

## Objetivo

Demonstrar que:

```text
Running ≠ Ready
```

e relacionar:

```text
readinessProbe → condição Ready → EndpointSlice → Service
```

## Aplicar a falha

```bash
kubectl -n "$NS" apply -f 03_observabilidade_opcional/falha-readiness.yaml
kubectl -n "$NS" get pods -l app=symfony-troubleshoot -w
```

Recolher evidências com `get`, `describe`, `logs` e `events` antes de corrigir.

## Ver condição do EndpointSlice

```bash
kubectl -n "$NS" get endpointslice \
  -l kubernetes.io/service-name=symfony-troubleshoot \
  -o jsonpath='{range .items[*].endpoints[*]}IP={.addresses[0]}{"  ready="}{.conditions.ready}{"  serving="}{.conditions.serving}{"  terminating="}{.conditions.terminating}{"\n"}{end}'
```

## Corrigir

```bash
kubectl -n "$NS" patch deployment symfony-troubleshoot \
  --type strategic \
  --patch-file 03_observabilidade_opcional/patch-readiness-correta.yaml
kubectl -n "$NS" rollout status deployment/symfony-troubleshoot --timeout=120s
```

## Limpar

```bash
kubectl -n "$NS" delete deployment symfony-troubleshoot --ignore-not-found
kubectl -n "$NS" delete service symfony-troubleshoot --ignore-not-found
kubectl -n "$NS" delete pod obs-client --ignore-not-found
```
