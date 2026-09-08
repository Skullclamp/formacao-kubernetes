# Formação — Orquestração de Containers com Kubernetes

Repositório de apoio aos **formandos** da formação *Orquestração de Containers com Kubernetes*.

## Objetivo

Este repositório reúne os guiões de laboratório, ficheiros de configuração e recursos técnicos utilizados ao longo das sessões práticas.

Os conteúdos são disponibilizados progressivamente, acompanhando a evolução da formação.

## Estrutura atual

```text
formacao-kubernetes/
├── README.md
├── docs/
│   ├── pre-requisitos.md
│   ├── como-usar-repositorio.md
│   ├── ambiente-laboratorio.md
│   └── comandos-rapidos.md
├── app/
│   └── symfony-demo/
│       └── README.md
└── sessao-02/
    ├── README.md
    ├── labs/
    │   ├── 01-containers.md
    │   ├── 02-diagnostico.md
    │   ├── 03-networking.md
    │   ├── 04-storage.md
    │   ├── 05-compose.md
    │   └── 06-troubleshooting.md
    ├── compose/
    │   ├── compose.yaml
    │   └── .env.example
    ├── desafios/
    │   └── troubleshooting.md
    └── checklist.md
```

## Aplicação transversal

Ao longo da formação será utilizada a **Symfony Demo Application**, numa variante pedagógica preparada para os laboratórios.

Stack de referência:

- Symfony Demo `v3.1.0`;
- Symfony 8.1;
- PHP 8.4 + Apache;
- PostgreSQL 16.

A variante de laboratório disponibiliza os endpoints pedagógicos:

```text
/info
/health
/ready
```

## Como começar

1. Consulte [`docs/pre-requisitos.md`](docs/pre-requisitos.md).
2. Leia [`docs/como-usar-repositorio.md`](docs/como-usar-repositorio.md).
3. Confirme o contexto em [`docs/ambiente-laboratorio.md`](docs/ambiente-laboratorio.md).
4. Para a Sessão 2, comece em [`sessao-02/README.md`](sessao-02/README.md).

## Método de troubleshooting

Durante os laboratórios, sempre que surgir uma falha:

```text
Sintoma
   ↓
Evidência
   ↓
Hipótese
   ↓
Causa
   ↓
Correção
   ↓
Validação
```

> Antes de alterar configuração, recolha evidências.
