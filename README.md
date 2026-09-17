# Formação — Orquestração de Containers com Kubernetes

Repositório de apoio aos **formandos** da formação *Orquestração de Containers com Kubernetes*.

## Objetivo

Este repositório reúne os guiões de laboratório, ficheiros de configuração e recursos técnicos utilizados ao longo das sessões práticas.

## Padrão pedagógico dos laboratórios

Os laboratórios seguem o padrão comum documentado em [`docs/padrao-laboratorios-kubernetes.md`](docs/padrao-laboratorios-kubernetes.md), tomando a Sessão 4 como referência de estrutura.

Em cada checkpoint (`CP`) deve ficar claro:

```text
O que estamos a fazer
        ↓
Porque é necessário
        ↓
Que conceitos estão a ser trabalhados
        ↓
Como interpretar comandos / flags / campos
        ↓
Que estado esperamos
        ↓
Que evidência prova o resultado
```

O objetivo é evitar execução mecânica de comandos: **compreender → executar → observar → validar → explicar**.

## Estrutura atual

```text
formacao-kubernetes/
├── README.md
├── docs/
├── app/
│   └── symfony-demo/
├── sessao-01/
├── sessao-02/
├── sessao-03/
├── sessao-04/
├── sessao-05/
├── sessao-05-06/
├── sessao-06/
├── sessao-07/
└── sessao-07-08/
```

`sessao-07/` contém o laboratório de 4 horas que integra os **Módulos 10 e 11**. `sessao-07-08/` fica reservada para materiais conjuntos das duas sessões quando necessário.

## Aplicação transversal

Ao longo da formação é utilizada a **Symfony Demo Application**, numa variante pedagógica preparada para os laboratórios.

Stack de referência:

- Symfony Demo `v3.1.0`;
- Symfony 8.1;
- PHP 8.4 + Apache;
- PostgreSQL 16.

Endpoints pedagógicos:

```text
/info
/health
/ready
```

## Como começar

1. Consulte [`docs/pre-requisitos.md`](docs/pre-requisitos.md).
2. Leia [`docs/como-usar-repositorio.md`](docs/como-usar-repositorio.md).
3. Confirme o contexto em [`docs/ambiente-laboratorio.md`](docs/ambiente-laboratorio.md).
4. Leia o [`padrão canónico dos laboratórios`](docs/padrao-laboratorios-kubernetes.md).
5. Sessão 1: [`sessao-01/README.md`](sessao-01/README.md).
6. Sessão 2: [`sessao-02/README.md`](sessao-02/README.md).
7. Sessão 3: [`sessao-03/README.md`](sessao-03/README.md).
8. Sessão 4: [`sessao-04/README.md`](sessao-04/README.md).
9. Sessão 5: [`sessao-05/README.md`](sessao-05/README.md).
10. Sessão 6: [`sessao-06/README.md`](sessao-06/README.md).
11. Sessão 7: [`sessao-07/README.md`](sessao-07/README.md).

## Progressão das sessões publicadas

```text
Sessão 1 — COMPREENDER FUNDAMENTOS
             VMs / Containers / Kubernetes
             kubectl / YAML / Pod / Namespace
        ↓
Sessão 2 — OPERAR CONTAINERS
        ↓
Sessão 3 — CONSTRUIR E PROMOVER IMAGENS
        ↓
Sessão 4 — CONSTRUIR E EVOLUIR O CLUSTER
        ↓
Sessão 5 — ADMINISTRAR WORKLOADS, REDE E DADOS
        ↓
Sessão 6 — GOVERNAR O CLUSTER
             Requests / Limits
             Scheduling / Affinity / Taints
             ServiceAccounts / RBAC
             SecurityContext / NetworkPolicy
        ↓
Sessão 7 — DIAGNOSTICAR, RECUPERAR E OPERAR
             M10 + M11
             Troubleshooting / Resiliência
             HA vs Backup / etcd
             Helm / Kustomize
             CRD / Operator / Reconciliação
```

## Sessão 7 — M10 + M11

A Sessão 7 condensa os dois módulos numa narrativa operacional única:

```text
Observar
   ↓
Diagnosticar
   ↓
Recuperar
   ↓
Gerir releases e configuração
   ↓
Reconciliar
   ↓
Validar
```

O laboratório trabalha readiness, Services/EndpointSlices, falha controlada de Worker, Control Plane/`etcd`, upgrade e rollback Helm, composição Kustomize e reconciliação através do Prometheus Operator.

## Método de troubleshooting

Durante os laboratórios, perante uma falha:

```text
Sintoma
   ↓
Evidência
   ↓
Hipótese
   ↓
Teste
   ↓
Causa raiz
   ↓
Correção
   ↓
Validação
```

> Antes de alterar configuração, recolha evidências.
