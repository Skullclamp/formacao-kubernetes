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
├── sessao-02/
│   ├── README.md
│   ├── plano_sessao_2.md
│   ├── labs/
│   ├── compose/
│   ├── desafios/
│   └── checklist.md
└── sessao-03/
    ├── README.md
    ├── plano_sessao_3.md
    ├── checklist.md
    ├── cheat_sheet.md
    ├── referencias.md
    ├── comum/
    └── formando/
        ├── guia_formando.md
        ├── docker/
        ├── compose/
        ├── labs/
        ├── scripts/
        └── exemplos/
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
5. Para a Sessão 3, comece em [`sessao-03/README.md`](sessao-03/README.md).

## Progressão Docker das Sessões 2 e 3

```text
Sessão 2 — OPERAR
imagem existente
→ container
→ observação
→ networking
→ storage
→ Compose
→ troubleshooting

Sessão 3 — CONSTRUIR / PREPARAR / PROMOVER
código
→ Dockerfile
→ imagem otimizada
→ scan
→ tag / digest
→ registry
→ deployment
→ update
→ falha
→ rollback
```

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
