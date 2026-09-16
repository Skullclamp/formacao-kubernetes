# Incidente 1 — Aplicação em execução, mas indisponível

## Situação entregue ao formando

Após uma alteração de configuração, os Pods da aplicação continuam em estado `Running`, mas deixam de ficar disponíveis para receber tráfego.

Não é fornecida a causa.

## Objetivo

Aplicar o método:

```text
Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação
```

## Regras

- Não editar recursos diretamente com `kubectl edit`.
- Recolher evidência antes de alterar a configuração.
- Registar pelo menos três comandos utilizados no diagnóstico.
- A correção deve repor a baseline declarativa conhecida como boa.

## Comandos de arranque sugeridos

```bash
kubectl get pods -n s78-lab
kubectl get deployment symfony-demo -n s78-lab
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

Utilizar `describe` e `logs` se necessário.

## Registo do incidente

| Campo | Registo |
|---|---|
| Sintoma | |
| Evidência inicial | |
| Hipótese | |
| Teste | |
| Causa raiz | |
| Correção | |
| Evidência de recuperação | |

## Critério de conclusão

O incidente só termina quando as duas réplicas estiverem simultaneamente `Running` e `Ready`, e a causa for explicada com base em evidência observada no cluster.
