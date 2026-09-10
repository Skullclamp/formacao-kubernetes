# A) Plano de Formação — Sessão 4
## Kubernetes Admin I — Instalação, Administração e Upgrade do Cluster

## 1. Identificação

| Elemento | Definição |
|---|---|
| Formação | Mini MBA em Orquestração de Containers com Kubernetes |
| Sessão | 4 |
| Módulo | M7 |
| Duração | 4 horas / 240 minutos |
| Nível | Intermédio |
| Formandos | Até 5 |
| Metodologia | Expositiva e ativa, com forte componente prática |
| Topologia | 1 Control Plane + 1 Worker por formando |
| SO | Ubuntu 26.04 LTS |
| Kubernetes inicial | 1.36.x (Haru) |
| Kubernetes final | 1.37.x (Garhwal) |
| Baseline ensaiada | 1.36.4 → 1.37.0 |
| Runtime | containerd |
| CNI | Calico via Tigera Operator |
| Pod CIDR | 192.168.0.0/16 |
| Service CIDR | 10.96.0.0/12 |

A Sessão 4 deixa de abordar apenas o bootstrap. O formando constrói um cluster 1.36.x, valida-o, pratica manutenção e executa depois um upgrade real para 1.37.x.

## 2. Objetivos específicos

No final da sessão, o formando deverá ser capaz de:

1. explicar a arquitetura mínima Control Plane / Worker;
2. rever os conceitos Kubernetes essenciais, incluindo ferramentas, comandos e flags mais frequentes;
3. validar pré-requisitos Linux antes do bootstrap;
4. explicar `Kubernetes → CRI → containerd → runc → Kernel`;
5. configurar `containerd` com CRI operacional e `SystemdCgroup = true`;
6. instalar `kubelet`, `kubeadm` e `kubectl` inicialmente na série 1.36.x;
7. executar `kubeadm init` apenas no Control Plane e interpretar o resultado;
8. configurar `kubeconfig`;
9. instalar e validar Calico/Tigera Operator;
10. adicionar o Worker com `kubeadm join`;
11. validar Nodes, Pods, CoreDNS e CNI;
12. usar `cordon`, `drain` e `uncordon`;
13. interpretar `kubeadm upgrade plan`;
14. executar o upgrade do Control Plane 1.36.x → 1.37.x;
15. executar o upgrade do Worker 1.36.x → 1.37.x;
16. observar e explicar version skew temporário;
17. validar novamente o cluster e os add-ons após o upgrade;
18. distinguir manutenção planeada de falha e diagnosticar problemas por evidências.

## 3. Fluxo da sessão

```text
refresh Kubernetes
      ↓
pré-requisitos Linux
      ↓
containerd / CRI
      ↓
Kubernetes 1.36.x
      ↓
kubeadm init — k8s-cp-01
      ↓
kubeconfig
      ↓
Calico / CNI
      ↓
kubeadm join — k8s-wk-01
      ↓
convergência Calico + CoreDNS
      ↓
cluster 1.36.x validado
      ↓
cordon / drain / uncordon
      ↓
upgrade Control Plane para 1.37.x
      ↓
upgrade Worker para 1.37.x
      ↓
cluster 1.37.x validado
```

## 4. Conteúdos

### 4.1. Refresh Kubernetes

- Kubernetes como orquestrador declarativo;
- Control Plane vs Worker;
- API Server, Scheduler, Controller Manager e etcd;
- kubelet, containerd, kube-proxy e CNI;
- diferença entre `kubeadm`, `kubelet` e `kubectl`;
- leitura de um comando `kubectl`;
- flags frequentes: `-n`, `-A`, `-o wide`, `-o yaml`, `-w`, `--help`.

### 4.2. Pré-requisitos Linux

- CPU/RAM e topologia;
- ausência de MicroK8s, k3s, Minikube ou cluster residual;
- swap;
- `overlay` e `br_netfilter`;
- `net.ipv4.ip_forward` e bridge netfilter;
- cgroup v2;
- resolução de nomes, relógio e portas.

### 4.3. containerd / CRI

- instalação do runtime;
- CRI ativo;
- socket `/run/containerd/containerd.sock`;
- `SystemdCgroup = true` na configuração efetiva.

### 4.4. Instalação Kubernetes 1.36.x

- repositório `pkgs.k8s.io/core:/stable:/v1.36/deb/`;
- instalação e `apt-mark hold`;
- verificação das versões.

### 4.5. Bootstrap

- `kubeadm init --pod-network-cidr=192.168.0.0/16`;
- certificados e static Pods;
- `admin.conf` e kubeconfig do utilizador;
- observação de `NotReady` antes do CNI.

### 4.6. CNI e Worker

- Calico via Tigera Operator;
- `tigera-operator`, `calico-system`, `tigerastatus`;
- comportamento de Pods `Pending` quando só existe o Control Plane com `NoSchedule`;
- `kubeadm token create --print-join-command`;
- `kubeadm join` apenas no Worker;
- convergência Calico/CoreDNS.

### 4.7. Manutenção

- Pod direto de observação;
- `cordon`;
- `drain` sem `--force` e interpretação da recusa;
- uso deliberado de `--force` apenas no exercício do Pod sem controller;
- `uncordon`.

### 4.8. Upgrade 1.36.x → 1.37.x

- repositório `pkgs.k8s.io` por minor release;
- mudança do repositório APT para 1.37;
- Control Plane: atualizar `kubeadm` → `upgrade plan` → `upgrade apply`;
- drain antes do upgrade minor do kubelet;
- atualizar `kubelet`/`kubectl`, restart e uncordon;
- Worker: atualizar `kubeadm` → `kubeadm upgrade node` → drain → `kubelet`/`kubectl` → uncordon;
- version skew temporário;
- validação final.

## 5. Distribuição temporal

| Tempo | Conteúdo / atividade | Tipo |
|---:|---|---|
| 10 min | Enquadramento + refresh Kubernetes | Síntese + conceito |
| 10 min | Topologia e requisitos | Conceito |
| 20 min | Pré-requisitos Linux | Conceito + prática |
| 15 min | containerd / CRI | Prática guiada |
| 15 min | Instalação Kubernetes 1.36.x | Prática |
| 15 min | Intervalo | — |
| 30 min | `kubeadm init` + kubeconfig + `NotReady` | Prática |
| 20 min | Calico/Tigera | Prática |
| 20 min | Worker join + convergência + validação | Prática |
| 10 min | kubeconfig e contextos | Prática |
| 60 min | Manutenção + upgrade 1.36.x → 1.37.x | Prática orientada |
| 15 min | Validação final + síntese | Consolidação |
| **240 min** | **Total** | |

## 6. Metodologia

```text
CONCEITO
   ↓
PRÉ-CONDIÇÃO
   ↓
COMANDO MANUAL
   ↓
OBSERVAR
   ↓
REGISTAR EVIDÊNCIA
   ↓
EXPLICAR
   ↓
AVANÇAR
```

Os scripts usados pelo formador em ensaios técnicos não fazem parte do percurso do formando.

## 7. Sequência de upgrade a ensinar

### Control Plane

```text
repo 1.37
   ↓
kubeadm 1.37
   ↓
kubeadm upgrade plan
   ↓
kubeadm upgrade apply v1.37.x
   ↓
drain
   ↓
kubelet + kubectl 1.37
   ↓
restart
   ↓
uncordon
   ↓
validar
```

### Worker

```text
repo 1.37
   ↓
kubeadm 1.37
   ↓
kubeadm upgrade node
   ↓
drain a partir do Control Plane
   ↓
kubelet + kubectl 1.37
   ↓
restart
   ↓
uncordon
   ↓
validar
```

Não se utiliza `--force` num `drain` de upgrade como comportamento automático.

## 8. Compatibilidade do CNI

Calico 3.32 é oficialmente testado com Kubernetes 1.34–1.36. A baseline da formação foi ensaiada com Calico 3.32.2 após a passagem para 1.37, mas isso não equivale a suporte/teste oficial da combinação.

Antes de cada edição, o formador deve:

1. consultar a matriz Calico atual;
2. preferir uma release oficialmente testada com Kubernetes 1.37, se disponível;
3. pré-validar o percurso completo 1.36 → 1.37;
4. confirmar CoreDNS, `tigerastatus` e Pods Calico depois do upgrade.

## 9. Avaliação formativa

O formando demonstra que consegue:

- explicar o papel dos componentes;
- justificar a ordem do bootstrap;
- construir o cluster 1.36;
- interpretar estados intermédios;
- executar manutenção controlada;
- executar o upgrade 1.36 → 1.37;
- explicar version skew;
- validar o cluster final.

## 10. Delimitação

Incluído: bootstrap, runtime, CNI, join, kubeconfig, manutenção e upgrade real de dois nós.

Fora do âmbito: HA multi-Control-Plane, rollback avançado, backup/restore de etcd, cloud-managed Kubernetes e políticas de rede avançadas.

## 11. Continuidade

A Sessão 4 termina com um cluster de dois nós **em Kubernetes 1.37.x**, pronto para a Sessão 5, onde o foco passa para workloads, networking e storage.
