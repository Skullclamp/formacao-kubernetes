# Incidente 2 — Pods saudáveis, serviço sem resposta

## Situação entregue ao formando

Os Pods da aplicação estão `Running` e `Ready`. O objeto `Service` existe, mas os pedidos enviados através do Service não chegam à aplicação.

Não é fornecida a causa.

## Objetivo

Diagnosticar a cadeia lógica entre Service, selectors, labels e EndpointSlices.

## Regras

- Confirmar primeiro o estado dos Pods.
- Não assumir que se trata de um problema de CNI ou DNS.
- Comparar explicitamente labels dos Pods com selectors do Service.
- Validar o resultado no EndpointSlice associado especificamente ao Service `symfony-demo`.

## Comandos de arranque sugeridos

```bash
kubectl get pods -n s78-lab --show-labels
kubectl get svc symfony-demo -n s78-lab -o yaml
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo -o yaml
```

## Registo do incidente

| Campo | Registo |
|---|---|
| Sintoma | |
| Pods saudáveis? | |
| Selector do Service | |
| Labels dos Pods | |
| Endpoints encontrados | |
| Condições `ready` | |
| Causa raiz | |
| Correção | |
| Evidência de recuperação | |

## Critério de conclusão

O Service deve voltar a apresentar endpoints correspondentes aos Pods da aplicação, com condições de prontidão coerentes, e o formando deve explicar a relação:

```text
Service selector → labels dos Pods → EndpointSlices
```
