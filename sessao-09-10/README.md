# Sessões 9–10 — Laboratório Integrado Kubernetes para Developers

Este diretório contém **um único laboratório contínuo** para as Sessões 9 e 10.

O percurso principal foi consolidado para **120 minutos** e reduzido a três checkpoints pedagógicos. Os manifests, scripts, Chart Helm e overlays Kustomize usados nesta versão resultam dos recursos já validados no cluster de formação.

## Estrutura

~~~text
sessao-09-10/
├── README.md
└── lab-integrado/
    ├── README.md
    ├── VALIDACAO.md
    ├── baseline/
    ├── preflight/
    ├── 01_fiabilidade_escala/
    ├── 02_ambientes_releases/
    ├── 03_troubleshooting_rollback/
    ├── optional/
    ├── cleanup/
    └── formador/
~~~

O guião principal é:

~~~text
lab-integrado/README.md
~~~

## Percurso principal

~~~text
PREFLIGHT — baseline saudável
        ↓
CP1 — FIABILIDADE + ESCALA
        ↓
CP2 — AMBIENTES + RELEASES
        ↓
CP3 — FALHA + DIAGNÓSTICO + RECUPERAÇÃO
~~~

A NetworkPolicy e o cenário isolado de readiness continuam disponíveis em **optional/**. Não fazem parte do percurso obrigatório de 120 minutos.

## Regra pedagógica

Em cada comando o formando deve conseguir responder:

~~~text
Onde olho?
Que valor procuro?
Com o que comparo?
O que espero?
O que significa?
Que conclusão consigo sustentar?
~~~

Consultar **lab-integrado/VALIDACAO.md** para o histórico de validação técnica e **lab-integrado/formador/** para a preparação e condução da sessão.
