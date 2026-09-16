# Incidente 3 — Degradação após falha de um Worker

## Situação entregue ao formando

Durante o funcionamento normal da aplicação ocorre uma falha num dos Worker Nodes. A equipa deve avaliar o impacto e acompanhar a recuperação.

> Se a turma utilizar um cluster partilhado, a falha é provocada exclusivamente pelo formador.

## Antes da falha

Registar a distribuição das réplicas:

```bash
kubectl get nodes
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab
```

## Durante o incidente

Observar, sem efetuar alterações precipitadas:

```bash
kubectl get nodes
kubectl get pods -n s78-lab -o wide
kubectl get events -A --sort-by=.lastTimestamp
kubectl get endpointslices -n s78-lab
```

## Questões de análise

1. Qual foi o primeiro sintoma observável?
2. Quanto tempo decorreu até o Node mudar de estado?
3. Que réplicas estavam associadas ao Node afetado?
4. O Service manteve endpoints utilizáveis?
5. Que mecanismos do Kubernetes contribuíram para a continuidade do workload?
6. Esta experiência prova Alta Disponibilidade do Control Plane? Justifique.
7. Esta experiência constitui um backup? Justifique.

## Registo do incidente

| Campo | Registo |
|---|---|
| Node afetado | |
| Estado inicial | |
| Estado após falha | |
| Réplicas afetadas | |
| Events relevantes | |
| Impacto no Service | |
| Evidência após recuperação | |

## Critério de conclusão

O formando deve distinguir corretamente:

```text
resiliência do workload
        ≠
Alta Disponibilidade do Control Plane
        ≠
backup / recuperação de dados
```
