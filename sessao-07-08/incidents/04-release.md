# Incidente 4 — Release candidata não fica operacional

## Situação entregue ao formando

A aplicação já é gerida por Helm. Uma nova release candidata é aplicada, mas o rollout não termina com sucesso. A estratégia de atualização permite que uma réplica anterior continue disponível enquanto a nova réplica evidencia a falha.

Não é fornecida a causa.

## Health gate antes da alteração

Confirmar primeiro uma release conhecida como boa:

```bash
helm list -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
```

Não avançar enquanto as duas réplicas não estiverem `Running` e `Ready`.

## Aplicar a candidata

```bash
helm upgrade symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-broken.yaml \
  --wait \
  --timeout 90s
```

É esperado que o comando não conclua com sucesso dentro do tempo definido.

## Diagnóstico

```bash
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

Utilizar `kubectl describe pod` no novo Pod afetado.

## Regras

- Não corrigir a release através de edição manual do Deployment.
- Confirmar se a réplica anterior continua utilizável.
- Identificar a revisão conhecida como boa.
- Decidir entre corrigir uma nova release ou efetuar rollback; neste exercício deverá ser praticado o rollback.

## Registo

| Campo | Registo |
|---|---|
| Revisão anterior | |
| Revisão candidata | |
| Estado da réplica anterior | |
| Estado da nova réplica | |
| Endpoints ainda disponíveis | |
| Sintoma | |
| Evidência | |
| Causa raiz | |
| Revisão escolhida para rollback | |
| Evidência final | |

## Critério de conclusão

A aplicação deve regressar a uma revisão operacional através de `helm rollback`. O formando deve validar o histórico, as duas réplicas, os endpoints do Service e explicar por que o rollout defeituoso não foi corrigido por edição manual no cluster.
