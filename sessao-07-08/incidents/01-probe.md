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
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get events -n s78-lab --sort-by=.metadata.creationTimestamp
```

Identificar o Pod novo:

```bash
kubectl describe pod <POD> -n s78-lab
kubectl logs <POD> -n s78-lab
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

## Evidência esperada

A falha controlada aponta a `readinessProbe` para `/ready-inexistente`. É esperado observar:

- Pod `Running`, mas `Ready=False`;
- respostas HTTP `404` na readiness probe;
- Deployment sem convergir para `2/2`;
- o Pod não pronto pode **continuar presente no EndpointSlice**, mas com `ready: false` e `serving: false`;
- a réplica saudável permanece com `ready: true`.

> **Nota importante:** presença no `EndpointSlice` não significa que o endpoint esteja Ready/elegível para tráfego normal do Service. A condição `ready` é a evidência que deve ser interpretada.

Um `FailedScheduling` transitório devido à anti-affinity pode aparecer durante o rollout. Só deve ser considerado causa raiz se persistir e impedir o agendamento. Neste incidente, a causa raiz pedagógica é a readiness probe inválida.

## Perguntas orientadoras

- O processo está em execução?
- O Pod está `Ready`?
- Que probe falha?
- O Pod aparece no EndpointSlice? Com que condição `ready`?
- O endpoint não pronto é elegível para tráfego normal?
- Que evidência suporta a hipótese?

## Recuperar

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status deployment/symfony-demo \
  -n s78-lab --timeout=180s
```

Validar:

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -l app=symfony-demo -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

O incidente só termina quando o Deployment regressar a `2/2` e os dois endpoints estiverem `ready: true`.
