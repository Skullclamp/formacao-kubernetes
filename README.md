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
├── sessao-03/
│   ├── README.md
│   ├── plano_sessao_3.md
│   ├── checklist.md
│   ├── cheat_sheet.md
│   ├── referencias.md
│   ├── comum/
│   └── formando/
└── sessao-04/
    ├── README.md
    ├── plano_sessao_4.md
    ├── manual_formando.md
    ├── checklist.md
    ├── checklist_operacional.md
    ├── folha_evidencias.md
    ├── cheat_sheet.md
    ├── troubleshooting.md
    ├── labs/
    ├── manifests/
    └── exercicios/
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
6. Para a Sessão 4, comece em [`sessao-04/README.md`](sessao-04/README.md).

## Progressão das sessões publicadas

```text
Sessão 2 — OPERAR CONTAINERS
        ↓
Sessão 3 — CONSTRUIR E PROMOVER IMAGENS
        ↓
Sessão 4 — CONSTRUIR E EVOLUIR O CLUSTER
             Kubernetes 1.36.x
                    ↓
             upgrade 1.37.x
```

Na Sessão 4, o laboratório é executado manualmente pelos formandos: preparar os nós, configurar `containerd`, construir o cluster com `kubeadm`, instalar o CNI, integrar o Worker, praticar manutenção e concluir com o upgrade controlado para Kubernetes 1.37.x.

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
