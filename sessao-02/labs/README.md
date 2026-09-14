# Labs — Sessão 2

Os laboratórios da Sessão 2 foram normalizados segundo o mesmo princípio pedagógico usado na Sessão 4: **executar não chega; é necessário compreender e provar o efeito**.

A estrutura comum é:

```text
OBJETIVO
   ↓
O QUE ESTAMOS A FAZER E PORQUÊ
   ↓
COMANDO
   ↓
FLAGS / ARGUMENTOS
   ↓
O QUE OBSERVAR
   ↓
CHECKPOINT
   ↓
EVIDÊNCIA
```

## Sequência

| Lab | Tema | Evidência principal |
|---|---|---|
| [`01-containers.md`](01-containers.md) | imagens, containers, portas e ciclo de vida | `run/stop/start/rm`, duas publicações e conflito de porta |
| [`02-diagnostico.md`](02-diagnostico.md) | logs, exec, inspect e stats | estado, logs, IP, porta, configuração e recursos |
| [`03-networking.md`](03-networking.md) | redes Docker e DNS interno | comunicação por nome + teste negativo entre redes |
| [`04-storage.md`](04-storage.md) | filesystem, bind mounts e named volumes | persistência provada por outro container |
| [`05-compose.md`](05-compose.md) | Symfony + PostgreSQL com Compose | config, health/readiness e persistência do volume |
| [`06-troubleshooting.md`](06-troubleshooting.md) | diagnóstico integrado | evidência → hipótese → correção mínima → validação |

O ficheiro [`../compose/compose.yaml`](../compose/compose.yaml) está comentado para explicar serviços, `HOST:CONTAINER`, variáveis, dependência por healthcheck, rede e named volume.

## Regra transversal

```text
não decorar comandos
        ↓
explicar o que cada comando pergunta ou altera
        ↓
interpretar flags relevantes
        ↓
observar o estado real
        ↓
registar evidência
```
