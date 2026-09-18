# Guião do Formador — Laboratório Integrado Sessões 9–10

## Objetivo de condução

O laboratório tem **120 minutos** e apenas **três checkpoints principais**.

~~~text
Preflight
   ↓
CP1 — Fiabilidade + escala
   ↓
CP2 — Ambientes + releases
   ↓
CP3 — Troubleshooting + rollback
~~~

A prioridade é ensinar a ler outputs, não maximizar o número de comandos executados.

Em cada etapa exigir:

~~~text
campo observado
→ valor esperado
→ comparação
→ interpretação
→ conclusão
~~~

## Distribuição temporal

| Bloco | Tempo |
|---|---:|
| Preflight | 5 min |
| CP1 — resources/probes + hardening + HPA | 35 min |
| CP2 — Kustomize + Helm | 35 min |
| CP3 — release defeituosa + diagnóstico + rollback | 40 min |
| Síntese | 5 min |
| **Total** | **120 min** |

## CP1 — evidência mínima

Antes de avançar, a turma deve demonstrar:

~~~text
resources 100m/128Mi → 500m/512Mi
liveness  /health
readiness /ready
SA        symfony-demo
automount false
seccomp   RuntimeDefault
allowPrivilegeEscalation false
HPA       CPU/target observado + scale-out
~~~

Não esperar pelo scale-in. Parar a carga, remover o HPA e repor 2 réplicas.

## CP2 — evidência mínima

### Kustomize

~~~text
DEV ≠ PROD
APP_ENV dev/prod
replicas 1/2
nameSuffix -dev/-prod
label app mantém symfony-demo-kustomize
DEV aplicado e Ready
EndpointSlice ready=true
cleanup concluído
~~~

### Helm

~~~text
lint sem falhas
template renderizado
release deployed
Deployment Ready
Service presente
EndpointSlice ready=true
uninstall concluído
baseline principal preservada
~~~

Não transformar o bloco numa análise exaustiva de templates.

## CP3 — prioridade pedagógica

Este é o bloco que **não deve ser comprimido**.

Não revelar imediatamente a causa. Conduzir por:

~~~text
Deployment
  ↓
ReplicaSets
  ↓
Pod candidato
  ↓
Running mas Ready=false
  ↓
imagem + readiness
  ↓
Events 404
  ↓
causa raiz
  ↓
rollback
  ↓
validação final
~~~

O método é:

~~~text
Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação
~~~

## Se houver atraso

Reduzir primeiro:

1. quantidade de linhas observadas no diff Kustomize;
2. detalhe do helm history/status;
3. discussão de campos secundários.

Não cortar:

- validação da baseline;
- relação resources ↔ HPA;
- prova de readiness no CP3;
- recolha de Events;
- identificação explícita da causa raiz;
- validação pós-rollback.

## Recursos opcionais

A NetworkPolicy e o cenário isolado de readiness estão em **optional/** e não entram no percurso principal. Usar apenas se houver tempo ou como recuperação de conteúdo.

## Turma até 5 formandos

Escalonar a geração de carga HPA. Evitar cinco geradores de carga simultâneos sem observar primeiro o consumo dos nodes.
