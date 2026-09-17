# Guião do Formador — Sessão 10

## Condução do laboratório

O laboratório é acompanhado por checkpoints. Em cada etapa:

```text
1. objetivo
2. previsão do comportamento
3. demonstração curta
4. execução pelos formandos
5. recolha de evidência
6. interpretação
7. checkpoint comum
```

## Progressão de ajuda no troubleshooting

```text
Nível 1 — pergunta: "O que observas?"
Nível 2 — fonte: "Onde podes recolher evidência?"
Nível 3 — comando: get / describe / logs / events
Nível 4 — apontar a secção do manifesto
Nível 5 — mostrar a solução
```

Evitar corrigir o YAML antes de os formandos recolherem evidência.

## Checkpoints do percurso principal

| Checkpoint | Evidência mínima |
|---|---|
| A — baseline | Symfony 2/2, PostgreSQL 1/1, PVC Bound, endpoints funcionais |
| B — resources/probes | requests/limits e `/health` + `/ready` visíveis no Pod |
| C — HPA | métricas válidas e scale-out observado; scale-in pode ser confirmado depois |
| D — segurança | SA dedicada, token ausente, seccomp e no privilege escalation, app funcional |
| E — NetworkPolicy | allowed funciona e blocked falha |
| F — release/rollback | candidata NotReady, versão estável disponível, rollback 2/2 |

## Pontos de atenção resultantes do ensaio

### HPA

- não usar um único watch com HPA e Pods neste ambiente; observar os recursos separadamente;
- usar watches separados;
- o scale-down não é imediato; pode ser confirmado mais tarde, enquanto o grupo avança;
- escalonar geradores de carga numa turma de 5 formandos.

### SecurityContext

Criar primeiro a `ServiceAccount`, só depois alterar o Deployment. No ensaio, inverter esta ordem bloqueou temporariamente a criação dos novos Pods.

Não selecionar `.items[0]` durante um RollingUpdate para concluir que o novo Pod tem hardening; podem coexistir revisões antigas e novas.

### NetworkPolicy

A existência do objeto **não prova enforcement**. Exigir:

```text
antes: allowed ✅ / blocked ✅
depois: allowed ✅ / blocked ❌
```

O teste externo via Traefik pode deixar de funcionar com a policy usada no exercício. O percurso principal valida por cliente interno autorizado. Se for necessário manter Ingress, criar uma regra específica depois de confirmar labels/namespace reais do controller.

### Rollback

A release candidata altera imagem e readiness na mesma revisão. O diagnóstico deve mostrar:

```text
container Running
Pod NotReady
stable Service disponível
```

O warning de `last-applied-configuration` deve ser explicado, não escondido.

## Contingências

Se Metrics Server, CNI, registry ou storage não estiverem prontos, não gastar o tempo principal da aula a reparar infraestrutura. Utilizar outputs previamente recolhidos para explicar o conceito e corrigir o cluster fora do bloco de 80 minutos.
