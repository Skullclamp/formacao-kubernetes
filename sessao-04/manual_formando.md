# Manual do Formando — Kubernetes — Instalação, Administração e Upgrade do Cluster

---

# Índice

1. [Baseline técnica de referência](#1-baseline-técnica-de-referência)
2. [Modelo mental e arquitetura do cluster](#2-modelo-mental-e-arquitetura-do-cluster)
3. [`kubeadm`, `kubelet` e `kubectl`](#3-kubeadm-kubelet-e-kubectl)
4. [Topologia e planeamento de redes](#4-topologia-e-planeamento-de-redes)
5. [Preparação do Linux](#5-preparação-do-linux)
6. [CRI, containerd, runc e cgroups](#6-cri-containerd-runc-e-cgroups)
7. [Gestão explícita de versões Kubernetes](#7-gestão-explícita-de-versões-kubernetes)
8. [Bootstrap do Control Plane](#8-bootstrap-do-control-plane)
9. [`kubeconfig` e contextos](#9-kubeconfig-e-contextos)
10. [CNI, Calico e Tigera Operator](#10-cni-calico-e-tigera-operator)
11. [Integração do Worker](#11-integração-do-worker)
12. [Validação do cluster](#12-validação-do-cluster)
13. [Observação, Events e condições dos Nodes](#13-observação-events-e-condições-dos-nodes)
14. [Labels, selectors e `nodeSelector`](#14-labels-selectors-e-nodeselector)
15. [`cordon`, `drain` e `uncordon`](#15-cordon-drain-e-uncordon)
16. [Health gates antes de alterações de risco](#16-health-gates-antes-de-alterações-de-risco)
17. [Recuperação antes do upgrade](#17-recuperação-antes-do-upgrade)
18. [Princípios do upgrade Kubernetes](#18-princípios-do-upgrade-kubernetes)
19. [`kubeadm upgrade plan` e `kubeadm upgrade apply`](#19-kubeadm-upgrade-plan-e-kubeadm-upgrade-apply)
20. [Atualização do Control Plane](#20-atualização-do-control-plane)
21. [Atualização do Worker](#21-atualização-do-worker)
22. [Version skew durante o upgrade](#22-version-skew-durante-o-upgrade)
23. [Validação final](#23-validação-final)
24. [Troubleshooting orientado por evidências](#24-troubleshooting-orientado-por-evidências)
25. [Interpretação dos principais outputs](#25-interpretação-dos-principais-outputs)
26. [Caso operacional integrado](#26-caso-operacional-integrado)
27. [Guia rápido de administração](#27-guia-rápido-de-administração)
28. [Glossário](#28-glossário)
29. [Recursos e leituras complementares](#29-recursos-e-leituras-complementares)

---

# 1. Baseline técnica de referência

A construção e atualização do cluster descritas neste manual utilizam a seguinte baseline técnica:

```text
Sistema operativo:      Ubuntu 26.04.1 LTS
cgroups:                 v2

Control Plane:           k8s-cp-01
Worker:                  k8s-wk-01

Kubernetes inicial:      1.35.8
Kubernetes final:        1.36.4

containerd:              2.2.6
runc:                    1.3.6

Calico:                  3.32.2
Tigera Operator:         1.42.6

Rede física:             192.168.50.0/24
Pod CIDR:                10.244.0.0/16
Service CIDR:            10.96.0.0/12
```

O percurso técnico é:

```text
Ubuntu preparado
      ↓
containerd + CRI
      ↓
Kubernetes 1.35.8
      ↓
kubeadm init
      ↓
CNI / Calico
      ↓
join do Worker
      ↓
cluster 1.35.8 saudável
      ↓
manutenção do Node
      ↓
health gate
      ↓
ponto de recuperação
      ↓
upgrade Control Plane
      ↓
upgrade Worker
      ↓
cluster 1.36.4 saudável
```

> **Atualização de versões:** as versões patch devem ser confirmadas antes de cada utilização em formação. A regra pedagógica estável é realizar um upgrade minor suportado de `1.35.x` para `1.36.x`, sem saltar versões minor.

A escolha de Kubernetes 1.35 → 1.36 mantém o Calico 3.32 dentro das versões Kubernetes oficialmente testadas pelo projeto Calico.

---

# 2. Modelo mental e arquitetura do cluster

Kubernetes trabalha principalmente com **estado desejado** e **reconciliação**.

```text
Estado desejado
      ↓
Kubernetes API
      ↓
etcd
      ↓
controllers observam o estado
      ↓
comparam desejado com observado
      ↓
tomam ações de reconciliação
```

Exemplo:

```text
Desejado:   3 Pods
Observado:  2 Pods
Diferença:  falta 1 Pod
Ação:       controller cria outro Pod
```

A reconciliação não é uma ação única. É um processo contínuo.

## 2.1. Control Plane e Worker

A topologia de referência contém dois Nodes:

```text
                ┌───────────────────────────┐
                │        k8s-cp-01          │
                │       CONTROL PLANE       │
                │                           │
                │ kube-apiserver            │
                │ etcd                      │
                │ kube-scheduler            │
                │ kube-controller-manager   │
                └────────────┬─────────────┘
                              │
                              │ Kubernetes API
                              │
                ┌────────────▼─────────────┐
                │        k8s-wk-01          │
                │          WORKER           │
                │                           │
                │ kubelet                   │
                │ containerd                │
                │ runc                      │
                │ kube-proxy                │
                │ Calico                    │
                └───────────────────────────┘
```

Esta topologia é adequada para aprendizagem e testes, mas **não representa um cluster de Alta Disponibilidade**.

## 2.2. Componentes do Control Plane

| Componente | Função principal |
|---|---|
| `kube-apiserver` | expõe a API Kubernetes |
| `etcd` | persiste o estado do cluster |
| `kube-scheduler` | seleciona Nodes para Pods ainda não agendados |
| `kube-controller-manager` | executa ciclos de reconciliação |

### `kube-apiserver`

É a porta de entrada administrativa do cluster.

Quando executamos:

```bash
kubectl get nodes
```

o fluxo conceptual é:

```text
kubectl
   ↓ lê kubeconfig
HTTPS
   ↓
kube-apiserver
   ↓
autenticação
   ↓
autorização
   ↓
consulta do estado
   ↓
resposta
```

### `etcd`

`etcd` guarda o estado persistente do cluster.

Isto torna `etcd` um elemento fundamental de uma estratégia de recuperação. Guardar apenas manifests YAML não equivale a efetuar backup do estado do cluster.

### Scheduler

O Scheduler decide onde colocar Pods que ainda não têm Node atribuído.

A decisão pode considerar:

- recursos disponíveis;
- `nodeSelector`;
- affinity/anti-affinity;
- taints e tolerations;
- topology constraints;
- outras regras de scheduling.

### Controller Manager

Os controllers observam continuamente o cluster e tentam aproximar o estado observado do estado desejado.

## 2.3. Componentes dos Nodes

| Componente | Função principal |
|---|---|
| `kubelet` | agente local que garante a execução dos Pods atribuídos |
| `containerd` | runtime responsável pelo ciclo de vida dos containers |
| `runc` | runtime OCI de baixo nível |
| `kube-proxy` | implementa parte do comportamento de Services nesta arquitetura |
| CNI / Calico | fornece conectividade de rede aos Pods |

---

# 3. `kubeadm`, `kubelet` e `kubectl`

Os nomes são semelhantes, mas representam funções diferentes.

| Ferramenta | Função |
|---|---|
| `kubeadm` | inicializar, juntar e atualizar Nodes de um cluster |
| `kubelet` | agente local do Node |
| `kubectl` | cliente administrativo da Kubernetes API |

## 3.1. `kubeadm`

Operações importantes:

```text
kubeadm init
└── inicializa o primeiro Control Plane

kubeadm token create
└── cria token de bootstrap

kubeadm join
└── integra um Node

kubeadm upgrade plan
└── analisa possibilidade de upgrade

kubeadm upgrade apply
└── aplica upgrade ao primeiro Control Plane

kubeadm upgrade node
└── atualiza configuração local de outro Node
```

## 3.2. `kubelet`

É um serviço local:

```bash
systemctl status kubelet --no-pager
```

ou:

```bash
systemctl is-active kubelet
```

O kubelet comunica:

```text
kubelet
   ├── Kubernetes API
   └── CRI
         ↓
      containerd
```

## 3.3. `kubectl`

`kubectl` é um cliente.

```text
kubectl
   +
kubeconfig
   ↓
HTTPS
   ↓
kube-apiserver
```

Estrutura típica:

```text
kubectl <verbo> <recurso> [flags]
```

Exemplos:

```bash
kubectl get nodes
kubectl get pods -A
kubectl describe node k8s-wk-01
kubectl get pods -n kube-system -o wide
```

Flags frequentes:

| Flag | Função |
|---|---|
| `-n <namespace>` | selecionar namespace |
| `-A` | todos os namespaces |
| `-o wide` | mostrar colunas adicionais |
| `-o yaml` | mostrar representação YAML |
| `-w` | observar alterações continuamente |
| `-l chave=valor` | filtrar por label |
| `--help` | ajuda contextual |

---

# 4. Topologia e planeamento de redes

Existem diferentes espaços de endereçamento:

```text
Rede física
192.168.50.0/24

Pod CIDR
10.244.0.0/16

Service CIDR
10.96.0.0/12
```

## 4.1. Rede física

É a rede utilizada pelas VMs para comunicar entre si.

Exemplo:

```text
k8s-cp-01 → 192.168.50.x
k8s-wk-01 → 192.168.50.y
```

Os valores concretos podem variar por ambiente.

## 4.2. Pod CIDR

O Pod CIDR define o espaço de endereçamento usado pela rede de Pods.

A baseline usa:

```text
10.244.0.0/16
```

## 4.3. Evitar sobreposição

Não devemos usar:

```text
192.168.0.0/16
```

nesta topologia, porque esse bloco contém:

```text
192.168.50.0/24
```

A sobreposição pode provocar ambiguidades de routing entre a rede física e a rede virtual dos Pods.

## 4.4. Service CIDR

A baseline utiliza:

```text
10.96.0.0/12
```

Este espaço é usado para IPs virtuais de Services.

Não deve ser confundido com:

- IPs das VMs;
- IPs dos Pods;
- endereços externos.

---

# 5. Preparação do Linux

Antes do bootstrap, validar cada host.

```bash
hostname
ip -br address
free -h
swapon --show
lsblk -f
df -h /
stat -fc %T /sys/fs/cgroup
```

## 5.1. O que verificar

| Comando | Evidência |
|---|---|
| `hostname` | identidade do Node |
| `ip -br address` | interfaces e IPs |
| `free -h` | memória e swap |
| `swapon --show` | swap ativa |
| `lsblk -f` | discos, partições e filesystems |
| `df -h /` | espaço efetivamente utilizável em `/` |
| `stat -fc %T /sys/fs/cgroup` | versão do modelo de cgroups |

## 5.2. Confirmar sempre o Node

Antes de operações sensíveis:

```bash
hostname
```

Regra operacional:

```text
k8s-cp-01
├── kubeadm init
├── kubeadm token create
├── kubectl administrativo
└── kubeadm upgrade apply

k8s-wk-01
├── kubeadm join
└── kubeadm upgrade node
```

Executar o comando correto no Node errado é uma causa frequente de falhas operacionais.

## 5.3. Disco virtual não é filesystem utilizável

É possível ter:

```text
disco virtual grande
        ↓
partição menor
        ↓
LVM
        ↓
logical volume menor
        ↓
filesystem /
```

Diagnóstico:

```bash
lsblk
sudo pvs
sudo vgs
sudo lvs
df -h /
```

Um incidente real do ambiente de referência mostrou que um filesystem raiz demasiado pequeno pode originar:

```text
DiskPressure=True
       ↓
evictions
       ↓
instabilidade dos Pods
```

## 5.4. Swap

A baseline utiliza swap desativada:

```bash
sudo swapoff -a
```

Isto é uma escolha operacional deste ambiente.

Não deve ser transformado na afirmação genérica “Kubernetes nunca suporta swap”, porque o suporte e a configuração de swap evoluíram nas versões modernas.

## 5.5. Módulos do kernel

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

Validar:

```bash
lsmod | grep -E 'overlay|br_netfilter'
```

## 5.6. Sysctl

Valores relevantes:

```text
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
```

Exemplo de configuração:

```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo sysctl --system
```

Validar:

```bash
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
```

---

# 6. CRI, containerd, runc e cgroups

A cadeia de execução é:

```text
kubelet
   ↓ CRI
containerd
   ↓
runc
   ↓
kernel Linux
```

## 6.1. CRI

O **Container Runtime Interface** define a interface usada pelo kubelet para comunicar com runtimes compatíveis.

O socket de containerd em Linux é normalmente:

```text
/run/containerd/containerd.sock
```

## 6.2. containerd

`containerd` gere operações de alto nível do ciclo de vida de containers.

A baseline utiliza a série:

```text
2.2.x
```

com versão validada:

```text
2.2.6
```

Ver versões disponíveis:

```bash
apt-cache madison containerd.io
```

## 6.3. Configuração

Criar configuração base:

```bash
sudo mkdir -p /etc/containerd

containerd config default \
  | sudo tee /etc/containerd/config.toml >/dev/null
```

Para containerd 2.x, a configuração do runtime `runc` deve utilizar:

```toml
[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
  SystemdCgroup = true
```

Depois:

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
```

## 6.4. Porque `SystemdCgroup = true`?

A baseline usa:

```text
systemd
+
cgroup v2
```

É recomendado que kubelet e runtime utilizem uma estratégia coerente para gestão de cgroups.

## 6.5. Validar

```bash
containerd --version
runc --version
systemctl is-active containerd
sudo ctr plugins ls | grep -i cri
```

O objetivo é provar:

```text
runtime instalado
+
serviço ativo
+
CRI disponível
+
cgroup driver coerente
```


# 7. Gestão explícita de versões Kubernetes

Uma instalação reproduzível não deve depender de:

```bash
sudo apt install kubeadm kubelet kubectl
```

sem controlar o repositório e a versão.

## 7.1. Repositórios por versão minor

Para Kubernetes 1.35:

```text
https://pkgs.k8s.io/core:/stable:/v1.35/deb/
```

No upgrade, passar para:

```text
https://pkgs.k8s.io/core:/stable:/v1.36/deb/
```

Isto restringe a origem APT à minor pretendida.

## 7.2. Descobrir a versão disponível

```bash
apt-cache madison kubeadm
```

Exemplo de seleção:

```bash
K8S_PKG_VERSION="$(
  apt-cache madison kubeadm |
  awk '$3 ~ /^1\.35\./ {print $3; exit}'
)"
```

Confirmar:

```bash
echo "$K8S_PKG_VERSION"
```

Na baseline validada:

```text
1.35.8-1.1
```

## 7.3. Instalar versão exata

```bash
sudo apt-get install -y \
  kubelet="$K8S_PKG_VERSION" \
  kubeadm="$K8S_PKG_VERSION" \
  kubectl="$K8S_PKG_VERSION"
```

Validar:

```bash
kubeadm version -o short
kubelet --version
kubectl version --client
```

Resultado esperado:

```text
v1.35.8
Kubernetes v1.35.8
Client Version: v1.35.8
```

## 7.4. Proteger contra upgrades involuntários

```bash
sudo apt-mark hold kubelet kubeadm kubectl
```

Durante um upgrade controlado:

```text
unhold
  ↓
instalar versão exata
  ↓
validar
  ↓
hold
```

---

# 8. Bootstrap do Control Plane

Esta operação deve ser executada apenas no Node escolhido como Control Plane.

Antes:

```bash
hostname
```

Depois:

```bash
sudo kubeadm init \
  --kubernetes-version=v1.35.8 \
  --apiserver-advertise-address=<IP_CONTROL_PLANE> \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///run/containerd/containerd.sock
```

## 8.1. Flags

| Flag | Função |
|---|---|
| `--kubernetes-version` | fixa a versão de bootstrap |
| `--apiserver-advertise-address` | endereço anunciado pelo API Server |
| `--pod-network-cidr` | rede atribuída aos Pods |
| `--cri-socket` | runtime CRI a utilizar |

Substitua:

```text
<IP_CONTROL_PLANE>
```

pelo endereço real da VM.

## 8.2. O que `kubeadm init` prepara

```text
preflight checks
      ↓
certificados
      ↓
kubeconfigs
      ↓
static Pod manifests
      ↓
etcd
      ↓
API Server
      ↓
scheduler
      ↓
controller-manager
      ↓
configuração do kubelet
```

Os principais componentes do Control Plane são geridos como static Pods a partir de:

```text
/etc/kubernetes/manifests/
```

## 8.3. Estado imediatamente após `init`

Pode observar:

```text
NotReady
```

e CoreDNS pode ainda não ficar pronto.

Isso é esperado enquanto não existir uma CNI funcional.

```text
Control Plane criado
       ↓
CNI ainda ausente
       ↓
rede de Pods incompleta
       ↓
Node pode ficar NotReady
```

Não repita `kubeadm init` para tentar resolver este estado.

---

# 9. `kubeconfig` e contextos

O `kubeadm` cria:

```text
/etc/kubernetes/admin.conf
```

Este ficheiro fornece acesso administrativo ao cluster.

Para o utilizador atual:

```bash
mkdir -p "$HOME/.kube"

sudo cp \
  /etc/kubernetes/admin.conf \
  "$HOME/.kube/config"

sudo chown \
  "$(id -u):$(id -g)" \
  "$HOME/.kube/config"

chmod 600 "$HOME/.kube/config"
```

## 9.1. Estrutura conceptual

```text
clusters
└── endpoint + CA

users
└── credenciais

contexts
└── cluster + user + namespace opcional

current-context
└── contexto atualmente selecionado
```

Consultar:

```bash
kubectl config current-context
kubectl config get-contexts
kubectl config view
```

## 9.2. Segurança

`admin.conf` é altamente privilegiado.

Não deve ser copiado indiscriminadamente para o Worker apenas para facilitar o uso de `kubectl`.

Uma administração correta separa:

```text
acesso administrativo
```

de:

```text
função operacional do Node
```

---

# 10. CNI, Calico e Tigera Operator

Kubernetes define o modelo de networking, mas necessita de uma implementação CNI para concretizar a rede dos Pods.

A baseline usa:

```text
Calico 3.32.2
Tigera Operator 1.42.6
```

## 10.1. Papel do CNI

Sem CNI:

```text
Control Plane criado
      ↓
Pods de infraestrutura arrancam
      ↓
rede de Pods incompleta
      ↓
Nodes podem permanecer NotReady
```

Com CNI funcional:

```text
interface dos Pods
      ↓
routing / encapsulamento
      ↓
conectividade Pod-to-Pod
      ↓
Node converge para Ready
```

## 10.2. Operator

Um Operator observa recursos Kubernetes e executa lógica operacional.

```text
Custom Resource
Installation
      ↓
Tigera Operator observa
      ↓
cria e configura componentes Calico
      ↓
rede converge
```

## 10.3. Recurso `Installation`

Exemplo utilizado:

```yaml
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
      - name: default-ipv4-ippool
        blockSize: 26
        cidr: 10.244.0.0/16
        encapsulation: VXLANCrossSubnet
        natOutgoing: Enabled
        nodeSelector: all()
```

Campos principais:

| Campo | Significado |
|---|---|
| `cidr` | rede usada pelos Pods |
| `blockSize` | blocos IPAM distribuídos aos Nodes |
| `encapsulation` | estratégia de encapsulamento |
| `natOutgoing` | NAT para tráfego de saída |
| `nodeSelector` | Nodes elegíveis para o pool |

## 10.4. Validar Calico

```bash
kubectl get tigerastatus
kubectl get pods -n calico-system -o wide
kubectl get nodes -o wide
```

Estados desejáveis:

```text
AVAILABLE=True
PROGRESSING=False
DEGRADED=False
```

Uma instalação mínima pode não ativar componentes opcionais do ecossistema Tigera. A análise deve concentrar-se nos componentes efetivamente instalados.

---

# 11. Integração do Worker

O Worker entra no cluster através de bootstrap.

## 11.1. Gerar comando de join

No Control Plane:

```bash
sudo kubeadm token create \
  --print-join-command \
  --kubeconfig=/etc/kubernetes/admin.conf
```

Estrutura esperada:

```text
kubeadm join <IP_CP>:6443 \
  --token abcdef.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:...
```

## 11.2. Executar no Worker

Antes:

```bash
hostname
```

Depois:

```bash
sudo kubeadm join ...
```

Se for necessário indicar explicitamente o runtime:

```text
--cri-socket=unix:///run/containerd/containerd.sock
```

## 11.3. Elementos do join

| Elemento | Função |
|---|---|
| endpoint `:6443` | API Server |
| `--token` | credencial temporária de bootstrap |
| `--discovery-token-ca-cert-hash` | validação da CA |
| `--cri-socket` | runtime local |

## 11.4. Validar localmente o Worker

```bash
sudo systemctl is-active kubelet
sudo ls -l /etc/kubernetes/kubelet.conf
```

## 11.5. Validar a partir do Control Plane

```bash
kubectl get nodes -o wide
```

Após convergência:

```text
k8s-cp-01   Ready   control-plane   ...   v1.35.8
k8s-wk-01   Ready   <none>          ...   v1.35.8
```

## 11.6. `kubectl` no Worker

Se o utilizador no Worker não tiver um kubeconfig, pode surgir:

```text
The connection to the server localhost:8080 was refused
```

Isto não significa automaticamente que o Worker tenha falhado.

A validação administrativa do cluster é feita a partir de um posto com kubeconfig válido.

---

# 12. Validação do cluster

Depois de integrar o Worker, não basta ver dois nomes em `kubectl get nodes`.

É necessário confirmar vários níveis.

## 12.1. Nodes

```bash
kubectl get nodes -o wide
```

## 12.2. Pods do sistema

```bash
kubectl get pods -A -o wide
```

## 12.3. CoreDNS

```bash
kubectl get pods -n kube-system \
  -l k8s-app=kube-dns \
  -o wide
```

## 12.4. Calico

```bash
kubectl get tigerastatus
kubectl get pods -n calico-system -o wide
```

## 12.5. API

```bash
kubectl cluster-info
```

## 12.6. Runtime reportado pelos Nodes

```bash
kubectl get nodes \
  -o custom-columns='NAME:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion'
```

O resultado deve ser coerente com a baseline.

---

# 13. Observação, Events e condições dos Nodes

Uma regra de administração é:

```text
observar
   ↓
alterar
   ↓
validar novamente
```

Comandos fundamentais:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
kubectl describe node k8s-wk-01
kubectl get tigerastatus
```

## 13.1. `get` e `describe`

```text
kubectl get
└── visão resumida

kubectl describe
└── detalhe, condições e Events
```

## 13.2. Condições importantes

Exemplos:

```text
Ready=True
DiskPressure=False
MemoryPressure=False
PIDPressure=False
```

Um Node pode estar:

```text
Ready=True
DiskPressure=True
```

Nesse caso não se deve concluir simplesmente “está tudo bem porque está Ready”.

## 13.3. Events

```bash
kubectl get events -A \
  --sort-by=.lastTimestamp
```

Events ajudam a identificar:

- scheduling;
- pulls de imagens;
- mounts;
- evictions;
- problemas de runtime;
- problemas de CNI;
- falhas de readiness.

Events são evidência temporal, não logs permanentes.

---

# 14. Labels, selectors e `nodeSelector`

Uma label é metadata chave/valor:

```yaml
metadata:
  labels:
    app: maintenance-test
```

Consultar:

```bash
kubectl get pods \
  -l app=maintenance-test
```

## 14.1. Label vs. selector

```text
label
└── metadata atribuída ao objeto

selector
└── expressão usada para selecionar objetos
```

## 14.2. `nodeSelector`

Exemplo:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: maintenance-test
  labels:
    app: maintenance-test
spec:
  nodeSelector:
    kubernetes.io/hostname: k8s-wk-01
  containers:
    - name: web
      image: nginx:1.28.0-alpine
      ports:
        - containerPort: 80
  restartPolicy: Always
```

Aqui:

```text
metadata.labels
```

descreve o Pod.

Já:

```text
spec.nodeSelector
```

restringe o scheduling a Nodes com a label correspondente.

O Pod é criado diretamente e não é gerido por Deployment ou ReplicaSet. Isso é relevante quando executarmos `drain`.

---

# 15. `cordon`, `drain` e `uncordon`

São operações distintas de manutenção de Nodes.

```text
Node em serviço
     ↓
cordon
     ↓
não aceitar novos agendamentos
     ↓
drain
     ↓
evacuar workloads apropriados
     ↓
manutenção
     ↓
uncordon
     ↓
aceitar scheduling novamente
```

## 15.1. `cordon`

```bash
kubectl cordon k8s-wk-01
```

Marca o Node como `unschedulable`.

Depois:

```bash
kubectl get nodes
```

pode mostrar:

```text
Ready,SchedulingDisabled
```

Isto significa:

```text
Ready
└── Node saudável

SchedulingDisabled
└── novos Pods não devem ser agendados normalmente
```

Os Pods existentes permanecem.

## 15.2. `drain`

Exemplo:

```bash
kubectl drain k8s-wk-01 \
  --ignore-daemonsets
```

`drain` tenta evacuar ou remover workloads antes de uma intervenção.

Quando possível, usa a API de eviction.

Isso permite considerar mecanismos como PodDisruptionBudget.

## 15.3. DaemonSets

Pods de DaemonSets não são tratados como workloads normais a deslocar.

Exemplos:

```text
calico-node
kube-proxy
```

Por isso usamos frequentemente:

```text
--ignore-daemonsets
```

## 15.4. Pods sem controller

Se o Pod tiver sido criado diretamente:

```yaml
kind: Pod
```

não existe um controller que o recrie.

Um `drain` pode recusar a sua remoção sem confirmação adicional.

Não acrescente:

```text
--force
```

automaticamente.

Primeiro interprete a razão da recusa.

## 15.5. `uncordon`

Depois da manutenção:

```bash
kubectl uncordon k8s-wk-01
```

O Node volta a aceitar scheduling.

`uncordon` não recria Pods eliminados manualmente. Apenas altera a elegibilidade do Node para novos agendamentos.

---

# 16. Health gates antes de alterações de risco

Antes de um upgrade devemos responder:

> O cluster está suficientemente saudável para avançar?

Critérios úteis:

```text
Nodes Ready
DiskPressure=False
Pods críticos estáveis
CoreDNS Ready
Calico saudável
containerd ativo
kubelet ativo
sem churn persistente
sem Events graves recorrentes
```

Comando de resumo:

```bash
kubectl get nodes \
  -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,DISK:.status.conditions[?(@.type=="DiskPressure")].status,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion'
```

Antes do upgrade esperamos algo equivalente a:

```text
NAME        READY   DISK    KUBELET   RUNTIME
k8s-cp-01   True    False   v1.35.8   containerd://2.2.6
k8s-wk-01   True    False   v1.35.8   containerd://2.2.6
```

O health gate não é um único comando. É uma decisão baseada em várias evidências.

---

# 17. Recuperação antes do upgrade

Depois de confirmar a saúde do cluster, deve existir um ponto de recuperação adequado ao ambiente.

Num ambiente de VMs pode ser criado um snapshot coordenado:

```text
cluster saudável
      ↓
snapshot Control Plane
      ↓
snapshot Worker
      ↓
upgrade
```

Isto é útil como mecanismo pedagógico de recuperação do ambiente.

Não deve ser confundido com uma estratégia de backup Kubernetes de produção.

Em produção é necessário considerar:

- backup de `etcd`;
- certificados;
- configuração do cluster;
- volumes persistentes;
- aplicações stateful;
- restore testado;
- RPO;
- RTO.

Também não se deve assumir que rollback Kubernetes é simplesmente:

```text
apt downgrade
```

---

# 18. Princípios do upgrade Kubernetes

O percurso validado é:

```text
1.35.8
   ↓
1.36.4
```

Upgrades minor são sequenciais.

Não saltamos:

```text
1.35 → 1.37
```

num único passo.

## 18.1. Ordem de alto nível

```text
1. atualizar kubeadm do Control Plane
2. kubeadm upgrade plan
3. kubeadm upgrade apply
4. drain do Control Plane
5. atualizar kubelet e kubectl do Control Plane
6. validar e uncordon
7. atualizar kubeadm do Worker
8. kubeadm upgrade node
9. drain do Worker
10. atualizar kubelet do Worker
11. validar e uncordon
12. health gate final
```

## 18.2. Porque atualizar `kubeadm` primeiro?

`kubeadm` conhece o workflow e as validações do upgrade para a versão destino.

O binário deve ser atualizado antes de pedir ao cluster para aplicar o upgrade.


# 19. `kubeadm upgrade plan` e `kubeadm upgrade apply`

Depois de mudar o repositório Kubernetes para a minor 1.36 e atualizar apenas `kubeadm` no Control Plane, confirmar:

```bash
kubeadm version
```

## 19.1. `kubeadm upgrade plan`

```bash
sudo kubeadm upgrade plan
```

Este comando:

- verifica o estado do cluster;
- identifica a versão atual;
- mostra versões de destino suportadas;
- valida pré-condições;
- apresenta componentes afetados.

Não aplica alterações ao cluster.

Deve distinguir-se:

```text
plan
└── observar e validar

apply
└── alterar estado
```

## 19.2. Aplicar o upgrade

No primeiro Control Plane:

```bash
sudo kubeadm upgrade apply v1.36.4
```

A operação atualiza os componentes geridos por `kubeadm`, incluindo os static Pods do Control Plane e addons suportados.

É normal observar reinícios transitórios dos componentes.

O importante é o resultado final da operação e a validação subsequente.

---

# 20. Atualização do Control Plane

Depois de `kubeadm upgrade apply`, o Control Plane pode apresentar temporariamente versões diferentes entre componentes.

Antes de atualizar o kubelet:

```bash
kubectl drain k8s-cp-01 \
  --ignore-daemonsets
```

## 20.1. Atualizar packages

Libertar os packages:

```bash
sudo apt-mark unhold kubelet kubectl
```

Instalar a versão destino:

```bash
sudo apt-get update

sudo apt-get install -y \
  kubelet='1.36.4-1.1' \
  kubectl='1.36.4-1.1'
```

Voltar a proteger:

```bash
sudo apt-mark hold kubelet kubectl
```

> A versão exata do package deve ser descoberta com `apt-cache madison` antes de executar o procedimento. Não copie um patch desatualizado cegamente.

## 20.2. Reiniciar kubelet

```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

Depois:

```bash
systemctl is-active kubelet
```

## 20.3. Observar convergência

Pode ocorrer:

```text
NotReady,SchedulingDisabled
```

e depois:

```text
Ready,SchedulingDisabled
```

Só quando o Node estiver saudável:

```bash
kubectl uncordon k8s-cp-01
```

Confirmar:

```bash
kubectl get nodes
```

---

# 21. Atualização do Worker

O Worker não executa:

```text
kubeadm upgrade apply
```

## 21.1. Atualizar `kubeadm`

No Worker:

```bash
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm='1.36.4-1.1'
sudo apt-mark hold kubeadm
```

Validar:

```bash
kubeadm version
```

## 21.2. Atualizar configuração local

```bash
sudo kubeadm upgrade node
```

Este comando atualiza a configuração local relevante para o Node.

Não atualiza automaticamente o package `kubelet`.

## 21.3. Drenar o Worker

A partir do posto administrativo:

```bash
kubectl drain k8s-wk-01 \
  --ignore-daemonsets
```

Resolver conscientemente qualquer Pod que bloqueie a operação.

## 21.4. Atualizar kubelet

No Worker:

```bash
sudo apt-mark unhold kubelet

sudo apt-get install -y \
  kubelet='1.36.4-1.1'

sudo apt-mark hold kubelet
```

Reiniciar:

```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

Confirmar:

```bash
systemctl is-active kubelet
```

## 21.5. Reabrir o Node

Quando estiver `Ready`:

```bash
kubectl uncordon k8s-wk-01
```

---

# 22. Version skew durante o upgrade

Durante um upgrade Kubernetes é normal existir temporariamente **version skew**.

Por exemplo:

```text
API Server:      v1.36.4
kubelet CP:      v1.35.8
kubelet Worker:  v1.35.8
kubectl client:  v1.35.8
```

Isto não significa, por si só, que o cluster esteja corrompido.

## 22.1. `kubectl version`

```bash
kubectl version
```

pode mostrar:

```text
Client Version: v1.35.8
Server Version: v1.36.4
```

## 22.2. `kubectl get nodes`

A coluna:

```text
VERSION
```

representa a versão do **kubelet** reportada por cada Node.

Por isso é possível observar:

```text
Server Version: v1.36.4
```

e simultaneamente:

```text
k8s-cp-01   ...   v1.35.8
```

A informação refere-se a componentes diferentes.

---

# 23. Validação final

O upgrade só termina depois de validar o cluster.

## 23.1. Nodes

```bash
kubectl get nodes -o wide
```

Esperado:

```text
k8s-cp-01   Ready   control-plane   ...   v1.36.4
k8s-wk-01   Ready   <none>          ...   v1.36.4
```

## 23.2. Cliente e servidor

```bash
kubectl version
```

Esperado:

```text
Client Version: v1.36.4
Server Version: v1.36.4
```

## 23.3. Pods de sistema

```bash
kubectl get pods -A -o wide
```

## 23.4. CoreDNS

```bash
kubectl get pods -n kube-system \
  -l k8s-app=kube-dns
```

## 23.5. Calico

```bash
kubectl get tigerastatus
kubectl get pods -n calico-system -o wide
```

## 23.6. Condições dos Nodes

```bash
kubectl get nodes \
  -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,DISK:.status.conditions[?(@.type=="DiskPressure")].status,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion'
```

Resultado esperado:

```text
NAME        READY   DISK    KUBELET   RUNTIME
k8s-cp-01   True    False   v1.36.4   containerd://2.2.6
k8s-wk-01   True    False   v1.36.4   containerd://2.2.6
```

## 23.7. Events

```bash
kubectl get events -A \
  --sort-by=.lastTimestamp
```

Procure erros recentes e repetitivos, não apenas mensagens antigas sem impacto atual.

---

# 24. Troubleshooting orientado por evidências

A metodologia recomendada é:

```text
SINTOMA
   ↓
RECOLHER EVIDÊNCIA
   ↓
FORMULAR HIPÓTESE
   ↓
VALIDAR HIPÓTESE
   ↓
CORRIGIR
   ↓
VALIDAR NOVAMENTE
```

Evite:

```text
erro
  ↓
acrescentar flags aleatórias
  ↓
esconder sintoma
```

## 24.1. Node `NotReady`

Começar por:

```bash
kubectl describe node <NODE>
kubectl get events -A --sort-by=.lastTimestamp
```

No Node:

```bash
systemctl status kubelet --no-pager
journalctl -u kubelet --since "-10 min" --no-pager
systemctl status containerd --no-pager
```

Perguntas:

```text
kubelet está ativo?
containerd está ativo?
CRI responde?
CNI está saudável?
há DiskPressure?
há erro de certificados?
há problema de routing?
```

## 24.2. `DiskPressure=True`

Evidência:

```bash
kubectl describe node <NODE>
df -h /
lsblk
sudo pvs
sudo vgs
sudo lvs
```

Um disco virtual grande não significa que o filesystem raiz tenha o mesmo tamanho.

## 24.3. `kubectl` tenta `localhost:8080`

Sintoma:

```text
The connection to the server localhost:8080 was refused
```

Uma causa frequente é a ausência de kubeconfig válido para esse utilizador.

Confirmar:

```bash
echo "$KUBECONFIG"
ls -l "$HOME/.kube/config"
kubectl config current-context
```

## 24.4. `kubeadm token create` falha no Worker

Pergunta essencial:

```bash
hostname
```

`kubeadm token create` requer acesso administrativo à API e deve ser executado a partir do contexto apropriado, normalmente no Control Plane deste ambiente.

## 24.5. `kubeadm join` falha

Recolher:

```bash
sudo journalctl -u kubelet --since "-10 min" --no-pager
sudo systemctl status containerd --no-pager
```

Confirmar:

- endpoint do API Server;
- token ainda válido;
- CA hash;
- conectividade TCP 6443;
- relógio do sistema;
- runtime;
- estado anterior do Node.

Se o Node tiver resíduos de um cluster anterior, não tente mascarar o erro com:

```text
--ignore-preflight-errors=all
```

sem compreender a causa.

## 24.6. CoreDNS `Pending`

Verificar primeiro:

```bash
kubectl get nodes
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
```

Antes da instalação da CNI, `Pending` ou falta de readiness pode ser esperado.

Depois da CNI, passa a ser evidência a investigar.

## 24.7. Calico não converge

Consultar:

```bash
kubectl get tigerastatus
kubectl get pods -n tigera-operator -o wide
kubectl get pods -n calico-system -o wide
kubectl describe pod -n calico-system <POD>
kubectl get events -A --sort-by=.lastTimestamp
```

Confirmar também:

```bash
df -h /
```

porque pressão de disco pode causar churn de Pods.

## 24.8. `drain` recusa Pods sem controller

A recusa protege workloads que não têm mecanismo de reposição.

Antes de usar:

```text
--force
```

responda:

```text
Que Pod é?
Quem o recria?
É aceitável perdê-lo?
Existe outro Node elegível?
```

## 24.9. Erro de assinatura APT

Se `apt update` apresentar erros de chave GPG, não continue como se todos os índices tivessem sido atualizados.

Corrigir primeiro:

- keyring;
- URL;
- ficheiro `.sources`;
- `Signed-By`.

Só depois repetir:

```bash
sudo apt update
```

## 24.10. Warnings transitórios

Uma linha isolada num journal não equivale automaticamente a falha.

Verificar:

```text
repete?
tem impacto?
Node continua Ready?
Pods estabilizam?
condições degradam?
```

A persistência e o impacto distinguem warning transitório de problema operacional.

---

# 25. Interpretação dos principais outputs

## 25.1. `kubectl get nodes`

```text
NAME        STATUS   ROLES           VERSION
k8s-cp-01   Ready    control-plane   v1.36.4
k8s-wk-01   Ready    <none>          v1.36.4
```

| Coluna | Significado |
|---|---|
| `NAME` | nome do Node |
| `STATUS` | condição resumida |
| `ROLES` | papel identificado por labels |
| `VERSION` | versão do kubelet |

## 25.2. `kubectl get pods -A -o wide`

Colunas frequentes:

| Coluna | Significado |
|---|---|
| `NAMESPACE` | namespace |
| `NAME` | Pod |
| `READY` | containers prontos / total |
| `STATUS` | estado resumido |
| `RESTARTS` | reinícios |
| `AGE` | idade |
| `IP` | IP do Pod |
| `NODE` | Node onde corre |

Exemplo:

```text
READY   STATUS
0/1     Running
```

significa que o processo/Pod está em execução, mas ainda não existe um container considerado Ready.

## 25.3. `kubectl get tigerastatus`

Exemplo:

```text
AVAILABLE   PROGRESSING   DEGRADED
True        False         False
```

Interpretação:

```text
AVAILABLE=True
└── disponível

PROGRESSING=False
└── não está numa convergência pendente

DEGRADED=False
└── não reporta degradação
```

## 25.4. `kubectl describe node`

Secções úteis:

- Labels;
- Taints;
- Conditions;
- Addresses;
- Capacity;
- Allocatable;
- System Info;
- Events.

Não procure apenas uma linha. Relacione condições com Events e estado dos Pods.

---

# 26. Caso operacional integrado

Este percurso reúne construção, manutenção e upgrade do cluster.

## 26.1. Estado inicial

Duas VMs Ubuntu:

```text
k8s-cp-01
k8s-wk-01
```

Validar em ambas:

```bash
hostname
ip -br address
free -h
swapon --show
df -h /
stat -fc %T /sys/fs/cgroup
```

## 26.2. Preparar runtime

Em ambas:

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

Configurar sysctl e containerd.

Validar:

```bash
systemctl is-active containerd
containerd --version
runc --version
sudo ctr plugins ls | grep -i cri
```

## 26.3. Instalar Kubernetes 1.35.x

Configurar o repositório 1.35.

Descobrir:

```bash
apt-cache madison kubeadm
```

Instalar explicitamente:

```text
kubeadm 1.35.x
kubelet 1.35.x
kubectl 1.35.x
```

Aplicar:

```bash
sudo apt-mark hold kubeadm kubelet kubectl
```

## 26.4. Inicializar Control Plane

No `k8s-cp-01`:

```bash
hostname
```

Depois:

```bash
sudo kubeadm init \
  --kubernetes-version=v1.35.8 \
  --apiserver-advertise-address=<IP_CONTROL_PLANE> \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///run/containerd/containerd.sock
```

Configurar kubeconfig.

## 26.5. Observar estado antes do CNI

```bash
kubectl get nodes
kubectl get pods -A
```

Interpretar `NotReady` como estado intermédio possível.

## 26.6. Instalar Calico

Aplicar o Tigera Operator e o recurso `Installation` correspondente à versão adotada.

Depois:

```bash
kubectl get tigerastatus
kubectl get pods -n calico-system -o wide
kubectl get nodes -o wide
```

Aguardar convergência.

## 26.7. Integrar Worker

No Control Plane:

```bash
sudo kubeadm token create \
  --print-join-command \
  --kubeconfig=/etc/kubernetes/admin.conf
```

No Worker:

```bash
hostname
sudo kubeadm join ...
```

Validar a partir do Control Plane:

```bash
kubectl get nodes -o wide
```

## 26.8. Validar estado 1.35.x

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl get events -A --sort-by=.lastTimestamp
```

## 26.9. Manutenção do Worker

```bash
kubectl cordon k8s-wk-01
kubectl get nodes
```

Executar `drain` com opções adequadas ao workload.

Depois:

```bash
kubectl uncordon k8s-wk-01
```

Confirmar que voltou a:

```text
Ready
```

## 26.10. Health gate

Antes de atualizar:

```bash
kubectl get nodes \
  -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,DISK:.status.conditions[?(@.type=="DiskPressure")].status,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion'
```

Confirmar também Pods, CoreDNS, Calico, kubelet e containerd.

## 26.11. Ponto de recuperação

Criar o mecanismo de recuperação definido para o ambiente.

Numa infraestrutura de VMs pode incluir snapshots coordenados.

## 26.12. Upgrade do Control Plane

1. mudar repositório para 1.36;
2. atualizar `kubeadm`;
3. executar:

```bash
sudo kubeadm upgrade plan
```

4. validar versão destino;
5. executar:

```bash
sudo kubeadm upgrade apply v1.36.4
```

6. drenar o Control Plane;
7. atualizar kubelet/kubectl;
8. reiniciar kubelet;
9. aguardar `Ready`;
10. executar `uncordon`.

## 26.13. Observar version skew

```bash
kubectl version
kubectl get nodes
```

Explicar por que API Server e kubelet podem mostrar minors diferentes durante o processo.

## 26.14. Upgrade do Worker

No Worker:

```bash
sudo kubeadm upgrade node
```

Depois, a partir do Control Plane:

```bash
kubectl drain k8s-wk-01 \
  --ignore-daemonsets
```

Atualizar kubelet no Worker, reiniciar e aguardar `Ready`.

Depois:

```bash
kubectl uncordon k8s-wk-01
```

## 26.15. Validação final

```bash
kubectl get nodes -o wide
kubectl version
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl get events -A --sort-by=.lastTimestamp
```

Resultado pretendido:

```text
Control Plane  v1.36.4
Worker         v1.36.4
Nodes          Ready
DiskPressure   False
CoreDNS        Ready
Calico         saudável
```

---

# 27. Guia rápido de administração

## Identidade e estado local

```bash
hostname
ip -br address
df -h /
free -h
swapon --show
```

## Serviços

```bash
systemctl is-active containerd
systemctl is-active kubelet
systemctl status containerd --no-pager
systemctl status kubelet --no-pager
```

## Logs

```bash
journalctl -u kubelet --since "-10 min" --no-pager
journalctl -u containerd --since "-10 min" --no-pager
journalctl -k --since "-10 min" --no-pager
```

## Cluster

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
kubectl cluster-info
```

## Detalhe

```bash
kubectl describe node <NODE>
kubectl describe pod -n <NAMESPACE> <POD>
```

## Configuração

```bash
kubectl config current-context
kubectl config get-contexts
kubectl config view
```

## Calico

```bash
kubectl get tigerastatus
kubectl get pods -n calico-system -o wide
```

## Maintenance

```bash
kubectl cordon <NODE>
kubectl drain <NODE> --ignore-daemonsets
kubectl uncordon <NODE>
```

## Bootstrap

```bash
sudo kubeadm init ...
sudo kubeadm token create --print-join-command
sudo kubeadm join ...
```

## Upgrade

```bash
kubeadm version
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.36.4
sudo kubeadm upgrade node
```

---

# 28. Glossário

| Termo | Definição |
|---|---|
| **API Server** | componente que expõe a Kubernetes API |
| **Calico** | solução CNI e de network policy |
| **CNI** | Container Network Interface; modelo/plugin de integração de rede dos Pods |
| **Control Plane** | conjunto de componentes que gere o estado e decisões do cluster |
| **cordon** | marca um Node como não elegível para novos agendamentos normais |
| **CRI** | Container Runtime Interface entre kubelet e runtime |
| **cgroup** | mecanismo Linux de controlo e contabilização de recursos |
| **containerd** | runtime de containers de alto nível compatível com CRI |
| **context** | combinação de cluster, user e namespace usada pelo `kubectl` |
| **CoreDNS** | DNS de cluster normalmente instalado como add-on |
| **drain** | prepara um Node para manutenção evacuando/removendo workloads apropriados |
| **etcd** | datastore chave/valor usado para persistir o estado Kubernetes |
| **Event** | registo Kubernetes de acontecimentos associados a objetos |
| **health gate** | conjunto de critérios que decide se é seguro avançar com uma alteração |
| **kubeadm** | ferramenta de bootstrap e upgrade de clusters Kubernetes |
| **kubeconfig** | ficheiro de configuração de acesso à Kubernetes API |
| **kubelet** | agente que corre em cada Node |
| **kubectl** | cliente CLI da Kubernetes API |
| **Node** | máquina registada no cluster capaz de executar Pods |
| **Pod CIDR** | espaço IP reservado à rede dos Pods |
| **runc** | runtime OCI de baixo nível |
| **Service CIDR** | espaço IP virtual usado por Services |
| **static Pod** | Pod gerido diretamente pelo kubelet a partir de um manifesto local |
| **Tigera Operator** | Operator utilizado para instalar e gerir Calico |
| **uncordon** | volta a tornar um Node elegível para scheduling |
| **version skew** | coexistência temporária/suportada de versões diferentes entre componentes |

---

# 29. Recursos e leituras complementares

## Livros de referência

### The Kubernetes Book

Temas relevantes:

- arquitetura;
- Control Plane;
- Nodes;
- estado desejado;
- reconciliação;
- CRI;
- Pods;
- networking.

### Kubernetes in Action

Temas relevantes:

- arquitetura;
- scheduling;
- kubelet;
- Services;
- operação de Nodes;
- administração.

### Kubernetes: Up & Running

Temas relevantes:

- componentes;
- API;
- cluster operations;
- scheduling;
- administração.

## Documentação oficial Kubernetes

Releases:

```text
https://kubernetes.io/releases/
```

Patch releases:

```text
https://kubernetes.io/releases/patch-releases/
```

Creating a cluster with kubeadm:

```text
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
```

Installing kubeadm:

```text
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
```

Container runtimes:

```text
https://kubernetes.io/docs/setup/production-environment/container-runtimes/
```

Upgrading kubeadm clusters:

```text
https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
```

Version skew policy:

```text
https://kubernetes.io/releases/version-skew-policy/
```

Operating etcd clusters:

```text
https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/
```

## Calico

System requirements:

```text
https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements
```

Component versions:

```text
https://docs.tigera.io/calico/latest/reference/component-versions
```

Operator installation:

```text
https://docs.tigera.io/calico/latest/getting-started/kubernetes/
```

> Conceitos e modelos mentais permanecem relativamente estáveis. Versões patch, URLs de repositórios, matrizes de compatibilidade e procedimentos de upgrade devem ser sempre confirmados na documentação oficial antes de uma execução real.
