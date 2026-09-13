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
├── app/
│   └── symfony-demo/
├── sessao-01/
├── sessao-02/
├── sessao-03/
├── sessao-04/
├── sessao-05/
└── sessao-06/
    ├── README.md
    ├── manual_formando.md
    ├── formando/
    │   └── labs/
    │       └── laboratorio_integrado_sessao_6.md
    └── manifests/
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
4. Para a Sessão 1, comece em [`sessao-01/README.md`](sessao-01/README.md).
5. Para a Sessão 2, comece em [`sessao-02/README.md`](sessao-02/README.md).
6. Para a Sessão 3, comece em [`sessao-03/README.md`](sessao-03/README.md).
7. Para a Sessão 4, comece em [`sessao-04/README.md`](sessao-04/README.md).
8. Para a Sessão 5, comece em [`sessao-05/README.md`](sessao-05/README.md).
9. Para a Sessão 6, comece em [`sessao-06/README.md`](sessao-06/README.md).

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
             Kubernetes 1.35.x
                    ↓
                  upgrade
                    ↓
             Kubernetes 1.36.x
        ↓
Sessão 5 — ADMINISTRAR WORKLOADS, REDE E DADOS
             Deployment / DaemonSet / StatefulSet
                    ↓
             PV / PVC / StorageClass
                    ↓
             Services / DNS / EndpointSlice
                    ↓
             Ingress / Gateway API
                    ↓
             Job / CronJob / Backup / Restore
        ↓
Sessão 6 — GOVERNAR O CLUSTER
             Requests / Limits
                    ↓
             ResourceQuota / LimitRange
                    ↓
             Scheduling / Affinity / Taints
                    ↓
             ServiceAccounts / RBAC
                    ↓
             SecurityContext / Secrets
                    ↓
             NetworkPolicy / Least privilege
```

Na Sessão 1, o foco está nos fundamentos comuns: virtualização, containers, imagens, runtimes, volumes, princípios de Kubernetes, arquitetura do cluster, `kubectl`, `kubeconfig`, YAML, Pods, Namespaces, labels e selectors.

Na Sessão 4, o laboratório é executado manualmente pelos formandos: preparar os nós, configurar `containerd`, instalar explicitamente Kubernetes 1.35.x, construir o cluster com `kubeadm`, instalar o CNI, integrar o Worker, praticar manutenção, preparar um ponto de recuperação e concluir com o upgrade controlado para Kubernetes 1.36.x.

Na Sessão 5, o laboratório parte do cluster 1.36.4 já construído e trabalha workloads, identidade estável, storage local com dynamic provisioning, Services e DNS, Ingress e Gateway API com Traefik, PostgreSQL 16, backup lógico, perda controlada de dados e restore.

Na Sessão 6, o foco passa para a governação: recursos, quotas, scheduling, ServiceAccounts, RBAC, SecurityContext, Secrets e NetworkPolicy com Calico, sempre com validação por evidência e aplicação do princípio de menor privilégio.

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
