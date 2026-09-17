# Labs — Sessão 2

Os laboratórios da Sessão 2 seguem o mesmo princípio pedagógico usado na Sessão 4: **executar não chega; é necessário compreender e provar o efeito**.

A estrutura comum é:

```text
OBJETIVO
   ↓
O QUE ESTAMOS A FAZER E PORQUÊ
   ↓
CONCEITOS ABORDADOS NESTE CP
   ↓
COMANDO
   ↓
FLAGS / ARGUMENTOS
   ↓
OUTPUT / ESTADO ESPERADO
   ↓
O QUE OBSERVAR
   ↓
TESTE NEGATIVO, quando acrescenta valor
   ↓
CHECKPOINT
   ↓
EVIDÊNCIA
```

## Sequência e conceitos principais

| Lab | Tema | Conceitos principais | Evidência principal |
|---|---|---|---|
| [`01-containers.md`](01-containers.md) | imagens, containers, portas e ciclo de vida | imagem vs. container, `HOST:CONTAINER`, stop/start/rm, instâncias independentes | `run/stop/start/rm`, duas publicações e conflito de porta |
| [`02-diagnostico.md`](02-diagnostico.md) | logs, exec, inspect e stats | stdout/stderr, inspeção, processo de diagnóstico, recursos | estado, logs, IP, porta, configuração e recursos |
| [`03-networking.md`](03-networking.md) | redes Docker e DNS interno | bridge definida pelo utilizador, DNS interno, isolamento de rede | comunicação por nome + teste negativo entre redes |
| [`04-storage.md`](04-storage.md) | filesystem, bind mounts e named volumes | dados efémeros, mount, persistência, volume ≠ backup | persistência provada por outro container |
| [`05-compose.md`](05-compose.md) | Symfony + PostgreSQL com Compose | definição declarativa multi-container, health/readiness, rede e volume | config, health/readiness e persistência do volume |
| [`06-troubleshooting.md`](06-troubleshooting.md) | diagnóstico integrado | sintoma, evidência, hipótese, teste, causa, correção e validação | evidência → hipótese → correção mínima → validação |

O ficheiro [`../compose/compose.yaml`](../compose/compose.yaml) está comentado para explicar serviços, `HOST:CONTAINER`, variáveis, dependência por healthcheck, rede e named volume.

## Regra transversal

```text
não decorar comandos
        ↓
explicar o conceito e o problema que está a ser resolvido
        ↓
explicar o que cada comando pergunta ou altera
        ↓
interpretar flags relevantes
        ↓
observar o estado real
        ↓
registar evidência
```

Quando uma flag já foi explicada num CP anterior, não é necessário repetir a definição integral; deve voltar a ser explicada quando o contexto lhe dá um significado operacional diferente.
