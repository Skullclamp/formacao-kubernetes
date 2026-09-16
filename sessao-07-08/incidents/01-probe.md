# Incidente 1 — Rollout bloqueado: nova réplica `Running` mas não `Ready`

## Situação entregue ao formando

Após uma alteração de configuração, o Deployment inicia uma atualização. A aplicação continua parcialmente disponível, mas o rollout não termina: uma nova réplica está em execução e não fica pronta para receber tráfego.

Não é fornecida a causa.

## Objetivo

Aplicar o método:

```text
Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação
```

E demonstrar duas ideias:

```text
Running ≠ Ready

readiness correta
      ↓
protege os endpoints utilizáveis do Service
      ↓
evita enviar tráfego para uma réplica não pronta
```

## Regras

- Não editar recursos diretamente com `kubectl edit`.
- Recolher evidência antes de alterar a configuração.
- Registar pelo menos três comandos utilizados no diagnóstico.
- Confirmar as condições `ready` dos endpoints, não apenas a existência do EndpointSlice.
- A correção deve repor a baseline declarativa conhecida como boa.

## Comandos de arranque sugeridos

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo -o yaml
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

Nos EndpointSlices, observar especialmente:

```yaml
conditions:
  ready: true|false
```

Utilizar `describe` e `logs` se necessário.

## Registo do incidente

| Campo | Registo |
|---|---|
| Sintoma | |
| Estado do rollout | |
| Réplica antiga disponível? | |
| Nova réplica `Running`? | |
| Nova réplica `Ready`? | |
| Condições dos endpoints | |
| Hipótese | |
| Teste | |
| Causa raiz | |
| Correção | |
| Evidência de recuperação | |

## Critério de conclusão

O incidente termina quando:

- as duas réplicas estão novamente `Running` e `Ready`;
- o rollout termina com sucesso;
- os endpoints apresentam as condições esperadas;
- o formando consegue explicar, com evidência, por que a réplica defeituosa não recebeu tráfego.
