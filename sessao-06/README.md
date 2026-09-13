# Sessão 6 — Kubernetes Admin III
## Recursos, Scheduling e Segurança

**Duração:** 4 horas  
**Nível:** intermédio  
**Módulo:** M9 — Recursos, Scheduling e Segurança  
**Foco pedagógico:** **GOVERNAR O CLUSTER**

A Sessão 6 dá continuidade direta às Sessões 4 e 5. Depois de construir o cluster e de administrar workloads, networking e storage, o foco passa para a governação do ambiente Kubernetes: recursos, placement, identidade, autorização, hardening e segmentação de rede.

## Ambiente de referência

```text
Control Plane:  k8s-cp-01 / 192.168.50.46
Worker 1:       k8s-wk-01 / 192.168.50.65
Worker 2:       k8s-wk-03 / 192.168.50.102
Kubernetes:     1.36.4
Runtime:        containerd 2.2.6
CNI:            Calico 3.32.2
Namespace lab:  s6-governance
```

O Control Plane deve permanecer fora dos workloads normais da formação. Os exercícios de scheduling serão executados sobre os dois Worker Nodes.

## Continuidade da topologia

`k8s-wk-03` não surge pela primeira vez nesta sessão. O Node foi preparado pelo formador **antes da Sessão 5**, fora do tempo de aula, reutilizando o procedimento de `kubeadm join` já praticado na Sessão 4. A Sessão 6 herda, portanto, a baseline operacional da Sessão 5:

```text
k8s-cp-01
+
k8s-wk-01
+
k8s-wk-03
```

A designação `wk-03` é a do inventário real das VMs e não representa uma etapa pedagógica omitida. O preflight da Sessão 6 volta a validar ambos os Workers e inclui um smoke-test do CNI em cada um antes de depender da topologia para Anti-Affinity e placement.

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

[**Laboratório Integrado — Sessão 6**](labs/laboratorio_integrado_sessao_6.md)

A prática segue a regra:

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

Cada `CPx` é um gate de validação. O padrão comum dos laboratórios Kubernetes — incluindo teste negativo quando fizer sentido, health gates, autoavaliação e evidências — está documentado em [`../docs/padrao-laboratorios-kubernetes.md`](../docs/padrao-laboratorios-kubernetes.md).

## Estrutura

```text
sessao-06/
├── README.md
├── manual_formando.md
├── folha_evidencias.md
├── labs/
│   └── laboratorio_integrado_sessao_6.md
└── manifests/
    └── README.md
```

## Conteúdos

A sessão trabalha de forma integrada:

- CPU e memória: `requests` e `limits`;
- `ResourceQuota` e `LimitRange`;
- Scheduler, labels de Nodes e `nodeSelector`;
- Node Affinity e Pod Anti-Affinity;
- taints e tolerations;
- Authentication vs. Authorization;
- `Role`, `ClusterRole`, `RoleBinding` e `ClusterRoleBinding`;
- ServiceAccounts e `kubectl auth can-i`;
- `SecurityContext` e princípio de menor privilégio;
- proteção e utilização prudente de Secrets;
- `NetworkPolicy` com enforcement através do Calico;
- validação objetiva através de estado, Events, permissões e testes de conectividade.

## Evidência

A [`folha_evidencias.md`](folha_evidencias.md) centraliza:

- baseline dos três Nodes;
- checkpoints CP1–CP12;
- testes negativos obrigatórios;
- matriz final de NetworkPolicy;
- regra de evidência da sessão.

## Regra crítica

Uma configuração aplicada com sucesso não é, por si só, evidência de que a política está a produzir o efeito pretendido. Cada exercício deverá incluir um teste positivo e, quando aplicável, um teste negativo.

## Convenção de Namespace

A Sessão 6 usa a convenção adotada para novos laboratórios:

```text
s<sessão>-<slug>
```

Neste caso:

```text
s6-governance
```

A Sessão 5 mantém `sessao5` como exceção documentada porque esse laboratório foi validado de ponta a ponta com FQDNs e evidências dependentes desse nome.

## Estado

O manual e o laboratório integrado estão desenvolvidos, e o laboratório foi validado de ponta a ponta no cluster real de referência com Kubernetes `1.36.4`, containerd `2.2.6` e Calico `3.32.2`. As correções descobertas durante o ensaio prático foram incorporadas no laboratório.
