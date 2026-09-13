# Sessão 6 — Kubernetes Admin III
## Recursos, Scheduling e Segurança

**Duração:** 4 horas  
**Nível:** intermédio  
**Módulo:** M9 — Recursos, Scheduling e Segurança  
**Foco pedagógico:** **GOVERNAR O CLUSTER**

A Sessão 6 dá continuidade direta às Sessões 4 e 5. Depois de construir o cluster e de administrar workloads, networking e storage, o foco passa para a governação do ambiente Kubernetes: recursos, placement, identidade, autorização, hardening e segmentação de rede.

## Ambiente de referência

```text
Control Plane:  1
Worker Nodes:   2
Runtime:        containerd
CNI:            Calico
Namespace lab:  s6-governance
```

O Control Plane deve permanecer fora dos workloads normais da formação. Os exercícios de scheduling serão executados sobre os dois Worker Nodes.

## Percurso da sessão

```text
Requests / Limits
        ↓
ResourceQuota / LimitRange
        ↓
Scheduler
        ↓
nodeSelector / Affinity / Anti-Affinity
        ↓
Taints / Tolerations
        ↓
Authentication / Authorization
        ↓
ServiceAccount + RBAC
        ↓
SecurityContext + Secrets
        ↓
NetworkPolicy
        ↓
Least privilege
        ↓
Evidência e validação
```

## Questão orientadora

> Como imponho regras, controlo a utilização dos recursos e provo objetivamente o que cada workload e cada identidade podem ou não fazer?

## Laboratório integrado

Existe um único laboratório para a Sessão 6:

[**Laboratório Integrado — Sessão 6**](formando/labs/laboratorio_integrado_sessao_6.md)

A prática seguirá a regra:

```text
CONFIGURAR
   ↓
PROVOCAR / TESTAR
   ↓
OBSERVAR
   ↓
RECOLHER EVIDÊNCIA
   ↓
EXPLICAR
```

## Estrutura

```text
sessao-06/
├── README.md
├── manual_formando.md
├── formando/
│   └── labs/
│       └── laboratorio_integrado_sessao_6.md
└── manifests/
    └── README.md
```

## Conteúdos a materializar

Os recursos da sessão serão desenvolvidos progressivamente em torno de:

- CPU e memória: `requests` e `limits`;
- `ResourceQuota` e `LimitRange`;
- Scheduler, labels de Nodes e `nodeSelector`;
- Node Affinity e enquadramento de Pod Affinity/Anti-Affinity;
- taints e tolerations;
- Authentication vs. Authorization;
- `Role`, `ClusterRole`, `RoleBinding` e `ClusterRoleBinding`;
- ServiceAccounts e `kubectl auth can-i`;
- `SecurityContext` e princípio de menor privilégio;
- proteção e utilização prudente de Secrets;
- `NetworkPolicy` com enforcement através do Calico;
- validação objetiva através de estado, Events, permissões e testes de conectividade.

## Regra crítica

Uma configuração aplicada com sucesso não é, por si só, evidência de que a política está a produzir o efeito pretendido. Cada exercício deverá incluir um teste positivo e, quando aplicável, um teste negativo.

## Estado

A estrutura base da Sessão 6 está criada. O manual, o laboratório integrado e os manifests serão preenchidos nas próximas etapas de desenvolvimento da formação.
