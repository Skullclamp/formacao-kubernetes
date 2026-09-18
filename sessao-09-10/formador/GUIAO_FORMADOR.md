# Guião do Formador — Sessão 10

## Condução do laboratório

O laboratório é acompanhado por checkpoints. O objetivo do formador não é apenas indicar comandos, mas ensinar os formandos a **ler os outputs**.

Em cada etapa:

```text
1. objetivo
2. conceitos que estão a ser trabalhados
3. previsão do comportamento
4. demonstração curta
5. execução pelos formandos
6. indicar onde olhar no output
7. comparar com a baseline/valor esperado
8. recolher evidência
9. interpretar
10. checkpoint comum
```

Antes de avançar, pedir sempre aos formandos que respondam:

```text
Que campo observaste?
Qual era o valor esperado?
Com que valor o comparaste?
O que significa a diferença?
Que conclusão consegues sustentar com esse output?
```

Evitar dizer apenas “está certo” ou “está errado”. Pedir que a conclusão seja ligada a um campo concreto do output.

## Progressão de ajuda no troubleshooting

```text
Nível 1 — pergunta: "O que mudou relativamente à baseline?"
Nível 2 — campo: "Em que coluna/secção deves olhar?"
Nível 3 — comparação: "Que dois valores tens de comparar?"
Nível 4 — fonte: "Onde podes recolher mais evidência?"
Nível 5 — comando: get / describe / logs / events
Nível 6 — apontar a secção do manifesto
Nível 7 — mostrar a solução
```

Evitar corrigir YAML ou executar rollback antes de os formandos recolherem evidência.

## Distribuição temporal das micropráticas M6

Reservar **50 minutos** para as micropráticas M6, mantendo a execução acompanhada e a leitura orientada dos outputs:

| Bloco | Tempo | Intenção pedagógica |
|---|---:|---|
| Cloud-native / 12-factor | 10 min | relacionar princípios com o cenário Symfony + PostgreSQL |
| Kustomize | 20 min | renderizar, comparar DEV/PROD, aplicar DEV, validar selectors/endpoints e limpar |
| Helm | 20 min | lint, template, instalar, validar release/workload/backends e remover |
| **Total** | **50 min** | manter compreensão e evidência, evitando execução mecânica |

Não reduzir estes blocos a uma sequência de comandos. A prioridade é que o formando consiga identificar **onde olhar, o que comparar e o que concluir**.

## Checkpoints do percurso principal

| Checkpoint | Onde olhar | Evidência mínima |
|---|---|---|
| A — baseline | `READY`, `STATUS`, PVC, endpoints | Symfony 2/2, PostgreSQL 1/1, PVC Bound, endpoints funcionais |
| B — resources/probes | `jsonpath` do Deployment | requests/limits, `/health` e `/ready` confirmados |
| C — HPA | `TARGETS`, `MINPODS`, `MAXPODS`, `REPLICAS` | CPU acima do target e scale-out observado; scale-in pode ser confirmado depois |
| D — segurança | SA, Automount, Seccomp, AllowPrivilegeEscalation | SA dedicada, token ausente, seccomp e no privilege escalation |
| E — NetworkPolicy | resultado antes/depois | allowed funciona e blocked passa de permitido para bloqueado |
| F — release/rollback | Deployment, RS, Pod, Events, image/readiness | candidata NotReady, versão estável disponível, causa sustentada e rollback 2/2 |

## Como conduzir as comparações principais

### Baseline → resources/probes

Pedir que comparem:

```text
ANTES
resources/probes ausentes

DEPOIS
requests 100m/128Mi
limits   500m/512Mi
liveness /health
readiness /ready
```

### HPA

Não perguntar apenas “escalou?”. Pedir a leitura:

```text
TARGETS atual/target
REPLICAS antes/depois
MINPODS/MAXPODS
```

A conclusão deve ser do tipo:

> A CPU média ficou acima de 50% e o número de réplicas aumentou de 2 para N; portanto observámos scale-out controlado pelo HPA.

### NetworkPolicy

A existência do objeto **não prova enforcement**. Exigir a comparação:

```text
ANTES
client-allowed ✅
client-blocked ✅

DEPOIS
client-allowed ✅
client-blocked ❌
```

Só esta alteração de comportamento permite atribuir o bloqueio à policy.

### Release defeituosa

Não revelar imediatamente `/ready-errado`.

Conduzir os formandos por:

```text
Deployment READY
      ↓
ReplicaSets antigo/novo
      ↓
Pod candidato Running mas NotReady
      ↓
Events: Readiness probe failed / 404
      ↓
image + readiness do Pod
      ↓
comparação com baseline
      ↓
causa raiz
```

A conclusão só deve surgir depois de a evidência convergir.

## Pontos de atenção resultantes do ensaio

### HPA

- não usar um único watch multi-recurso dependente de sintaxe problemática no cliente utilizado;
- observar HPA e Pods no mesmo terminal através de comandos separados;
- o scale-down não é imediato; pode ser confirmado mais tarde enquanto o grupo avança;
- escalonar geradores de carga numa turma de 5 formandos;
- avisos transitórios de métricas durante criação de Pods não devem ser confundidos automaticamente com a causa de uma falha persistente.

### SecurityContext

Criar primeiro a `ServiceAccount`, só depois alterar o Deployment. No ensaio, inverter esta ordem bloqueou temporariamente a criação dos novos Pods.

Não selecionar `.items[0]` durante um RollingUpdate para concluir que o novo Pod tem hardening; podem coexistir revisões antigas e novas. Selecionar explicitamente um Pod com `SA=symfony-demo`.

### NetworkPolicy

O teste externo via Traefik pode deixar de funcionar com a policy usada no exercício. O percurso principal valida por cliente interno autorizado. Se for necessário manter Ingress, criar uma regra específica depois de confirmar labels/namespace reais do controller.

### Rollback

A release candidata altera imagem e readiness na mesma revisão. O diagnóstico deve mostrar:

```text
imagem 1.2.0-rc1
readiness /ready-errado
container Running
Pod NotReady
stable Service disponível
Events com falha de readiness
```

O warning de `last-applied-configuration` deve ser explicado, não escondido: `rollout undo` recupera o estado no cluster, mas não substitui a reposição da fonte declarativa num fluxo GitOps/declarativo.

## Contingências

Se Metrics Server, CNI, registry ou storage não estiverem prontos, não gastar o tempo principal da aula a reparar infraestrutura. Utilizar outputs previamente recolhidos para explicar o conceito e corrigir o cluster fora do bloco de 80 minutos.

Mesmo em contingência, manter a mesma lógica pedagógica:

```text
mostrar output
→ indicar campo
→ comparar valores
→ interpretar
→ concluir
```
