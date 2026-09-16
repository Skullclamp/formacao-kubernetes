# Incidente 1 — `Running` mas não `Ready`

## Situação

Após uma alteração, o rollout não termina. A nova réplica aparece `Running`, mas não fica pronta para receber tráfego.

## Objetivo

Compreender:

```text
Running ≠ Ready
```

E relacionar:

```text
readinessProbe
      ↓
Ready
      ↓
EndpointSlice
      ↓
tráfego do Service
```

## Introduzir a falha

```bash
kubectl apply -k app/overlays/incident-probe/
```

## Observar

```bash
kubectl get deployment symfony-demo -n s7-lab
kubectl get pods -n s7-lab -o wide
kubectl get events -n s7-lab --sort-by=.lastTimestamp
```

Identificar o Pod novo:

```bash
kubectl describe pod <POD> -n s7-lab
kubectl logs <POD> -n s7-lab
kubectl get endpointslices -n s7-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

## Perguntas orientadoras

- O processo está em execução?
- O Pod está `Ready`?
- Que probe falha?
- O endpoint não pronto recebe tráfego?
- Que evidência suporta a hipótese?

## Recuperar

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status deployment/symfony-demo \
  -n s7-lab --timeout=180s
```

Validar:

```bash
kubectl get pods -n s7-lab
kubectl get endpointslices -n s7-lab
```

O incidente só termina quando a aplicação regressar ao estado esperado.
