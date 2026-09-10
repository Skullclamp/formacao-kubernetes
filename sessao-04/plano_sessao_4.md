# Plano de Formação — Sessão 4
## Kubernetes Admin I — Instalação e Administração do Cluster

## 1. Identificação

| Elemento | Definição |
|---|---|
| Formação | Mini MBA em Orquestração de Containers com Kubernetes |
| Sessão | 4 |
| Módulo | M7 |
| Duração | 4 horas / 240 minutos |
| Nível | Intermédio |
| Formandos | Até 5 |
| Ambiente | 2 VMs Ubuntu 26.04 LTS por formando |
| Kubernetes | 1.37 |
| Runtime | containerd |
| CNI | Calico via Tigera Operator |
| Foco | **CONSTRUIR O CLUSTER** |

Cada formando trabalha com um cluster independente composto por `k8s-cp-01` e `k8s-wk-01`. Com cinco formandos, a sala pode necessitar de até dez VMs.

## 2. Objetivos específicos

No final da sessão, o formando deverá ser capaz de:

1. distinguir o papel do Control Plane e do Worker;
2. validar pré-requisitos Linux antes do bootstrap;
3. explicar a cadeia `kubelet → CRI → containerd → runc → kernel`;
4. instalar e configurar `containerd` com CRI ativo e `SystemdCgroup = true`;
5. instalar `kubelet`, `kubeadm` e `kubectl` na série 1.37 e aplicar `apt hold`;
6. inicializar o Control Plane com `kubeadm init`;
7. configurar e interpretar o `kubeconfig` administrativo;
8. instalar Calico através do Tigera Operator;
9. interpretar o estado `NotReady` antes do CNI e estados `Pending` por falta de nó schedulable;
10. integrar o Worker através de `kubeadm join`;
11. validar Nodes, CoreDNS, Calico/Tigera e API Server;
12. utilizar `kubectl config` para consultar contextos;
13. executar e explicar `cordon`, `drain` e `uncordon`;
14. interpretar `kubeadm upgrade plan`;
15. diagnosticar falhas comuns com base em evidências.

## 3. Ambiente de referência

```text
Control Plane:   k8s-cp-01
Worker:          k8s-wk-01
SO:              Ubuntu 26.04 LTS
Kubernetes:      1.37
Runtime:         containerd
CNI:             Calico via Tigera Operator
Pod CIDR:        192.168.0.0/16
Service CIDR:    10.96.0.0/12
```

## 4. Metodologia

A sessão segue uma metodologia ativa e orientada por evidências:

```text
CONCEITO
   ↓
PRÉ-CONDIÇÃO
   ↓
EXECUÇÃO MANUAL
   ↓
OBSERVAÇÃO
   ↓
EVIDÊNCIA
   ↓
EXPLICAÇÃO
```

Os formandos executam os passos manualmente. Scripts de ensaio e validação usados pelo formador não fazem parte do percurso normal do formando.

## 5. Conteúdos e atividades

### Bloco 1 — Enquadramento e arquitetura

- transição das Sessões 2–3 para Kubernetes;
- Control Plane vs Worker;
- API Server, etcd, scheduler, controller manager, kubelet e kube-proxy;
- topologia de duas VMs.

### Bloco 2 — Pré-requisitos Linux

- hostname e resolução entre nós;
- memória e CPU;
- swap;
- módulos `overlay` e `br_netfilter`;
- `ip_forward` e bridge netfilter;
- cgroup v2;
- sincronização horária;
- ausência de MicroK8s, k3s, Minikube ou Kubernetes residual;
- portas de Control Plane e kubelet.

### Bloco 3 — containerd / CRI

- runtime vs CRI;
- configuração do containerd 2.x;
- CRI não desativado;
- `SystemdCgroup = true`;
- socket `/run/containerd/containerd.sock`.

### Bloco 4 — ferramentas Kubernetes

- repositório `pkgs.k8s.io` da série 1.37;
- instalação de `kubelet`, `kubeadm`, `kubectl`;
- `apt-mark hold`;
- comportamento do kubelet antes de `init`/`join`.

### Bloco 5 — bootstrap do Control Plane

- preflight checks;
- `kubeadm init --pod-network-cidr=192.168.0.0/16`;
- certificados e static Pods;
- configuração de `$HOME/.kube/config`;
- observação de `NotReady` antes do CNI.

### Bloco 6 — CNI / Calico

- CNI e rede de Pods;
- CRDs, Tigera Operator e Custom Resources;
- validação de Pod CIDR;
- namespaces `tigera-operator` e `calico-system`;
- taint `control-plane:NoSchedule`;
- interpretação de Pods `Pending` antes do Worker.

### Bloco 7 — Worker join e convergência

- `kubeadm token create --print-join-command`;
- `kubeadm join` executado apenas no Worker;
- diferença entre placeholders e credenciais reais;
- convergência de Calico/Tigera e CoreDNS;
- validação dos dois Nodes em `Ready`.

### Bloco 8 — kubeconfig e manutenção

- contextos e `current-context`;
- segurança de `admin.conf`;
- Pod direto fixado ao Worker;
- `cordon`;
- `drain` sem e com `--force`;
- `uncordon`;
- distinção entre manutenção planeada e falha.

### Bloco 9 — upgrades e troubleshooting

- `kubeadm upgrade plan`;
- ordem conceptual de upgrade;
- diagnóstico por `get`, `describe`, Events e logs do host;
- casos: memória insuficiente, portas ocupadas, MicroK8s residual, token inválido, CNI/CoreDNS `Pending`.

## 6. Distribuição do tempo

| Tempo | Atividade | Tipo |
|---:|---|---|
| 10 min | Enquadramento e ligação à Sessão 3 | Síntese |
| 15 min | Arquitetura e topologia | Conceito |
| 25 min | Pré-requisitos Linux | Prática guiada |
| 20 min | containerd e CRI | Conceito + prática |
| 20 min | kubelet, kubeadm e kubectl | Prática |
| 15 min | Intervalo | — |
| 40 min | `kubeadm init` e kubeconfig | Prática guiada |
| 20 min | Calico / Tigera Operator | Prática |
| 20 min | Worker join e convergência | Prática |
| 15 min | kubeconfig e contextos | Prática guiada |
| 25 min | cordon, drain, uncordon e upgrade plan | Prática |
| 15 min | Síntese, evidências e avaliação formativa | Consolidação |
| **240 min** | **Total** | |

## 7. Evidências de aprendizagem

O formando regista, ao longo dos checkpoints CP1–CP8:

- estado dos pré-requisitos Linux;
- runtime e CRI;
- versões e `apt hold`;
- estado do Control Plane antes do CNI;
- estado do Calico/Tigera;
- Worker integrado;
- CoreDNS operacional;
- comportamento de `cordon` e `drain`;
- estado final do cluster.

## 8. Critérios de conclusão

A sessão está tecnicamente concluída quando:

```text
[ ] k8s-cp-01 Ready
[ ] k8s-wk-01 Ready
[ ] Worker schedulable
[ ] Calico/Tigera operacional
[ ] CoreDNS Running
[ ] API Server acessível
[ ] kubeconfig/contexto conhecido
[ ] Pod de manutenção removido
```

A sessão está pedagogicamente concluída quando o formando consegue explicar por que razão cada transição ocorreu e que evidência a confirma.
