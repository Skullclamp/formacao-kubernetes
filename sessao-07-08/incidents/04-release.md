# Incidente 4 — Release candidata não fica operacional

## Situação entregue ao formando

A aplicação já é gerida por Helm. Uma nova release candidata é aplicada, mas o rollout não termina com sucesso.

Não é fornecida a causa.

## Preparação

Confirmar primeiro uma release conhecida como boa:

```bash
helm list -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get pods -n s78-lab
```

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
kubectl get pods -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

Utilizar `kubectl describe pod` no Pod afetado.

## Regras

- Não corrigir a release através de edição manual do Deployment.
- Identificar a revisão conhecida como boa.
- Decidir entre corrigir uma nova release ou efetuar rollback; neste exercício deverá ser praticado o rollback.

## Registo

| Campo | Registo |
|---|---|
| Revisão anterior | |
| Revisão candidata | |
| Sintoma | |
| Evidência | |
| Causa raiz | |
| Revisão escolhida para rollback | |
| Evidência final | |

## Critério de conclusão

A aplicação deve regressar a uma revisão operacional através de `helm rollback`, com histórico e estado final validados.
