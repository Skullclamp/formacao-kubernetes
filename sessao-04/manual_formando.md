# Manual do Formando
## Sessão 4 — Kubernetes Admin I: Instalação, Administração e Upgrade do Cluster

## Identificação

| Elemento | Definição |
|---|---|
| **Formação** | Mini MBA em Orquestração de Containers com Kubernetes |
| **Sessão** | 4 de 10 |
| **Duração** | 4 horas / 240 minutos |
| **Nível** | Intermédio |
| **Módulo** | M7 |
| **Foco pedagógico** | Construir, observar, manter e atualizar um cluster Kubernetes |
| **Topologia** | 1 Control Plane + 1 Worker |
| **Ambiente validado** | Ubuntu 26.04.1 LTS on-premises |
| **Laboratório** | `formando/labs/laboratorio_integrado_sessao_4.md` |

---

# 1. Como utilizar este manual

Este manual foi concebido para funcionar como **guia de acompanhamento, estudo autónomo e consulta futura**. Não é uma cópia da apresentação e não é apenas uma sequência de comandos.

Tal como no Manual da Sessão 3, cada operação importante é apresentada segundo uma lógica pedagógica:

```text
CONCEITO
   ↓
PORQUE É NECESSÁRIO
   ↓
COMANDO / MANIFESTO
   ↓
FLAGS / ARGUMENTOS / CAMPOS
   ↓
OUTPUT ESPERADO
   ↓
O QUE OBSERVAR
   ↓
ERRO FREQUENTE
   ↓
BOA PRÁTICA
```

O laboratório integrado apresenta o percurso operacional completo. Este manual explica **o que está a acontecer e porquê**.

Durante a sessão seguimos sempre:

```text
COMPREENDER
    ↓
EXECUTAR MANUALMENTE
    ↓
OBSERVAR
    ↓
REGISTAR EVIDÊNCIA
    ↓
EXPLICAR
    ↓
AVANÇAR
```

O objetivo não é memorizar comandos. É conseguir explicar o estado do sistema **antes**, a alteração provocada pelo comando e a evidência que demonstra o resultado **depois**.

---

# 2. Objetivos da sessão

No final da sessão deverás ser capaz de:

- explicar a arquitetura básica de um cluster Kubernetes;
- distinguir Control Plane de Worker Node;
- explicar as funções de `kubeadm`, `kubelet` e `kubectl`;
- preparar Linux para Kubernetes;
- explicar a relação `kubelet → CRI → containerd → runc → kernel`;
- instalar explicitamente uma versão Kubernetes sem deixar a escolha ao APT;
- inicializar um Control Plane com `kubeadm`;
- compreender o papel do kubeconfig e dos contextos;
- instalar e validar uma rede CNI com Calico;
- adicionar um Worker ao cluster;
- observar Nodes, Pods, eventos e condições;
- compreender labels e selectors;
- aplicar `cordon`, `drain` e `uncordon`;
- construir um health gate antes de uma alteração de risco;
- executar um upgrade minor de forma sequencial;
- interpretar estados transitórios durante um upgrade;
- distinguir warnings transitórios de falhas persistentes;
- recolher evidência antes de formular uma hipótese de troubleshooting.

---

# 3. Baseline técnica validada

O laboratório foi validado de ponta a ponta com:

```text
Sistema operativo:      Ubuntu 26.04.1 LTS
Kernel:                  7.0.0-31-generic
cgroups:                 v2

Control Plane:           k8s-cp-01 / 192.168.50.46
Worker:                  k8s-wk-01 / 192.168.50.65

Kubernetes inicial:      1.35.8
Kubernetes final:        1.36.4
Pacote APT inicial:      1.35.8-1.1
Pacote APT final:        1.36.4-1.1

containerd:              2.2.6
runc:                    1.3.6
Calico:                  3.32.2
Tigera Operator:         1.42.6

Pod CIDR:                10.244.0.0/16
Service CIDR:            10.96.0.0/12
Filesystem /:            40 GB no ambiente validado
```

> Os 40 GB não são um requisito universal do Kubernetes. São a baseline deste laboratório. O incidente observado ocorreu porque o filesystem `/` tinha cerca de 10 GB apesar de o disco virtual ter mais capacidade, originando `DiskPressure` durante a instalação do Calico.

As versões patch devem ser reconfirmadas antes de cada nova edição. O objetivo pedagógico é manter um upgrade **1.35.x → 1.36.x** sem saltar versões minor.

---

# 4. Modelo mental do Kubernetes

Kubernetes trabalha principalmente através de um **modelo declarativo**. Em vez de indicarmos todos os passos necessários para atingir um resultado, descrevemos o estado pretendido.

```text
ESTADO DESEJADO
      ↓
API Server
      ↓
etcd guarda o estado
      ↓
controllers observam diferenças
      ↓
reconciliação
      ↓
ESTADO OBSERVADO aproxima-se do DESEJADO
```

Exemplo:

```text
Desejado:   3 Pods
Observado:  2 Pods
Diferença:  falta 1 Pod
Ação:       o controller cria outro Pod
```

A reconciliação é contínua. Os controllers continuam a observar o cluster e tentam manter o estado real alinhado com o que foi declarado.

## 4.1. Imperativo versus declarativo

Exemplo imperativo:

```bash
kubectl run exemplo --image=nginx
```

Pedimos uma ação imediata.

Exemplo declarativo:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: exemplo
spec:
  containers:
    - name: web
      image: nginx:1.28.0-alpine
```

Aqui descrevemos um objeto que queremos que exista.

```text
Imperativo  → executa esta ação
Declarativo → mantém este estado
```

O modelo declarativo facilita versionamento, revisão, repetibilidade e automação.

---

# 5. Arquitetura do cluster

No laboratório usamos dois Nodes:

```text
                ┌───────────────────────┐
                │      k8s-cp-01        │
                │     CONTROL PLANE     │
                │                       │
                │ kube-apiserver        │
                │ etcd                  │
                │ scheduler             │
                │ controller-manager    │
                └───────────┬───────────┘
                            │ API
                            │
                ┌───────────▼───────────┐
                │      k8s-wk-01        │
                │        WORKER         │
                │                       │
                │ kubelet               │
                │ containerd            │
                │ kube-proxy            │
                │ Calico                │
                └───────────────────────┘
```

Esta topologia é adequada à formação, mas **não representa alta disponibilidade**.

## 5.1. Componentes do Control Plane

| Componente | Função principal |
|---|---|
| `kube-apiserver` | expõe a API Kubernetes |
| `etcd` | guarda o estado persistente do cluster |
| `kube-scheduler` | escolhe um Node para Pods ainda não agendados |
| `kube-controller-manager` | executa os ciclos de reconciliação |

### API Server

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
autenticação / autorização
   ↓
consulta do estado
   ↓
resposta ao cliente
```

### etcd

`etcd` guarda o estado do cluster. Isto explica por que motivo uma estratégia real de recuperação não se resume a guardar manifests YAML ou reinstalar packages.

### Scheduler

O Scheduler procura Nodes adequados para Pods sem Node atribuído. A decisão pode considerar recursos, afinidade, taints, selectors e outras restrições.

### Controller Manager

Os controllers executam ciclos contínuos de reconciliação: observam o estado atual, comparam-no com o desejado e tomam ações quando existe diferença.

## 5.2. Componentes dos Nodes

| Componente | Função principal |
|---|---|
| `kubelet` | agente do Node; garante a execução dos Pods atribuídos |
| `containerd` | runtime responsável pelo ciclo de vida dos containers |
| `runc` | runtime OCI de baixo nível que cria processos isolados |
| `kube-proxy` | implementa comportamento de rede de Services nesta instalação |
| Calico/CNI | fornece conectividade aos Pods e networking/policy |

---

# 6. `kubeadm`, `kubelet` e `kubectl`

Os nomes são semelhantes, mas os papéis são diferentes.

| Ferramenta | Pergunta a que responde |
|---|---|
| `kubeadm` | Como inicializo, junto ou atualizo este cluster? |
| `kubelet` | Como mantenho os Pods deste Node em execução? |
| `kubectl` | Como comunico administrativamente com a API? |

## 6.1. `kubeadm`

Nesta sessão usamos:

```text
kubeadm init          → cria o primeiro Control Plane
kubeadm token create  → gera credenciais temporárias de bootstrap
kubeadm join          → integra um Node
kubeadm upgrade plan  → analisa um upgrade possível
kubeadm upgrade apply → aplica o upgrade ao primeiro Control Plane
kubeadm upgrade node  → atualiza a configuração local de outro Node
```

## 6.2. `kubelet`

É um serviço local:

```bash
systemctl status kubelet --no-pager
```

### Flags

- `--no-pager` — mostra a saída diretamente no terminal sem abrir `less` ou outro paginador.

### O que observar

```text
Active: active (running)
```

O kubelet comunica com o API Server e com o runtime local.

## 6.3. `kubectl`

`kubectl` é um cliente, não um daemon.

```text
kubectl + kubeconfig
        ↓
      HTTPS
        ↓
   kube-apiserver
```

No Worker, sem kubeconfig administrativo, pode surgir:

```text
The connection to the server localhost:8080 was refused
```

Neste laboratório isto não significa que o cluster esteja em baixo; significa que esse utilizador não tem contexto administrativo configurado nesse Node.

**Boa prática:** administrar o cluster a partir do Control Plane e usar no Worker apenas comandos locais de sistema quando necessário.

---

# 7. Preparar Linux antes do bootstrap

Antes de instalar Kubernetes temos de validar o host.

```bash
hostname
ip -br address
free -h
swapon --show
lsblk -f
df -h /
stat -fc %T /sys/fs/cgroup
```

## 7.1. O que faz cada comando

| Comando | O que mostra |
|---|---|
| `hostname` | nome do host |
| `ip -br address` | interfaces e endereços IP em formato resumido |
| `free -h` | memória RAM e swap em unidades legíveis |
| `swapon --show` | dispositivos/ficheiros de swap ativos |
| `lsblk -f` | discos, partições, filesystems e mounts |
| `df -h /` | espaço realmente utilizável no filesystem raiz |
| `stat -fc %T /sys/fs/cgroup` | tipo de filesystem usado pelos cgroups |

### Flags relevantes

- `ip -br` — `brief`, formato resumido;
- `-h` — valores legíveis para humanos;
- `lsblk -f` — acrescenta informação de filesystem;
- `stat -f` — mostra informação do filesystem;
- `-c %T` — imprime apenas o tipo de filesystem.

### Output esperado no laboratório

```text
k8s-cp-01 / k8s-wk-01
swap: sem entradas
cgroups: cgroup2fs
filesystem /: com espaço suficiente
```

## 7.2. Porque verificar sempre o hostname?

Algumas operações só fazem sentido num determinado Node.

```text
k8s-cp-01 → kubeadm init, token create, kubectl administrativo
k8s-wk-01 → kubeadm join, upgrade node
```

Um erro de terminal pode levar a executar a operação certa no Node errado.

## 7.3. Disco virtual não é filesystem utilizável

No laboratório observámos:

```text
Disco virtual ≈ 48 GB
filesystem /  ≈ 10 GB inicialmente
```

O encadeamento era:

```text
Disco virtual
   ↓
partição
   ↓
Physical Volume LVM
   ↓
Volume Group
   ↓
Logical Volume
   ↓
filesystem /
```

Por isso não basta olhar para o tamanho do disco da VM.

Comandos de diagnóstico:

```bash
lsblk
sudo pvs
sudo vgs
sudo lvs
df -h /
```

### O que significam

- `pvs` — Physical Volumes;
- `vgs` — Volume Groups;
- `lvs` — Logical Volumes;
- `df` — espaço do filesystem montado.

### Incidente real observado

A falta de espaço em `/` levou a:

```text
DiskPressure=True
      ↓
eviction de Pods
      ↓
churn de componentes Calico/Tigera
```

Depois de expandir o LV e o filesystem, o Node convergiu para:

```text
DiskPressure=False
```

**Boa prática:** diagnosticar a camada correta. Aumentar o disco virtual não aumenta automaticamente o filesystem.

## 7.4. Swap

No laboratório usamos:

```bash
sudo swapoff -a
```

- `swapoff` — desativa swap ativa;
- `-a` — aplica a todas as áreas de swap configuradas/ativas.

A baseline da sessão usa swap desativada. Isto é uma decisão do laboratório e não deve ser convertido na afirmação genérica “Kubernetes nunca suporta swap”.

## 7.5. Módulos do kernel

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

- `overlay` — suporta filesystem em camadas usado por containers;
- `br_netfilter` — permite integrar tráfego bridged com netfilter.

Validar:

```bash
lsmod | grep -E 'overlay|br_netfilter'
```

### Flags e operadores

- `grep -E` — ativa expressões regulares estendidas;
- `|` — encaminha a saída do comando anterior para o seguinte.

## 7.6. Sysctl de rede

```text
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
```

O primeiro permite encaminhamento IPv4. O segundo permite que tráfego bridged seja processado pela infraestrutura netfilter usada pela solução de rede.

---

# 8. Runtime: CRI, containerd e runc

O kubelet comunica com o runtime através do **Container Runtime Interface (CRI)**.

```text
kubelet
   ↓ CRI
containerd
   ↓
runc
   ↓
Linux kernel
```

## 8.1. Porque existe o CRI?

O kubelet não deve depender das particularidades internas de cada runtime. O CRI define a interface de integração.

No laboratório, o socket é:

```text
/run/containerd/containerd.sock
```

## 8.2. Instalação do containerd

A baseline usa `containerd.io 2.2.6`.

Para observar versões disponíveis:

```bash
apt-cache madison containerd.io
```

### O que faz

Consulta as versões publicadas nos repositórios APT configurados.

A seleção do laboratório filtra a série 2.2:

```bash
apt-cache madison containerd.io \
  | awk '$3 ~ /^2\.2\./ {print $3; exit}'
```

### Como ler a expressão `awk`

| Fragmento | Significado |
|---|---|
| `$3` | terceira coluna |
| `~` | corresponde a expressão regular |
| `/^2\.2\./` | começa por `2.2.` |
| `print $3` | imprime a versão |
| `exit` | termina após a primeira correspondência |

No ambiente validado o package escolhido foi:

```text
2.2.6-1~ubuntu.26.04~resolute
```

## 8.3. Configuração

Geramos uma configuração base:

```bash
sudo mkdir -p /etc/containerd
containerd config default \
  | sudo tee /etc/containerd/config.toml >/dev/null
```

### Elementos importantes

- `mkdir -p` — cria a diretoria e não falha se já existir;
- `containerd config default` — escreve a configuração predefinida no stdout;
- `|` — encaminha essa configuração;
- `tee` — grava-a no ficheiro indicado;
- `>/dev/null` — evita duplicar o conteúdo no terminal.

Depois confirmamos:

```text
CRI não desativado
SystemdCgroup = true
```

## 8.4. Porque `SystemdCgroup = true`?

A baseline usa `systemd` e cgroup v2. O runtime e o kubelet devem utilizar uma estratégia coerente para gerir cgroups.

## 8.5. Validar o runtime

```bash
containerd --version
runc --version
systemctl is-active containerd
sudo ctr plugins ls | grep -i cri
```

### Output esperado

```text
containerd 2.2.6
runc 1.3.6
active
CRI plugin ... ok
```

### O que observar

Não basta `containerd` estar instalado. Queremos provar:

```text
serviço ativo
+ CRI disponível
+ versão esperada
+ runtime consistente nos dois Nodes
```

---

# 9. Gestão explícita de versões Kubernetes

Uma instalação reproduzível não deve depender de:

```bash
sudo apt install kubeadm kubelet kubectl
```

sem controlar versão e repositório.

## 9.1. Repositórios por minor

Primeiro usamos:

```text
https://pkgs.k8s.io/core:/stable:/v1.35/deb/
```

No upgrade mudamos para:

```text
https://pkgs.k8s.io/core:/stable:/v1.36/deb/
```

Assim a própria origem APT já restringe a minor pretendida.

## 9.2. Descobrir e fixar o patch

```bash
apt-cache madison kubeadm
```

No laboratório o filtro foi:

```bash
K8S_PKG_VERSION="$(
  apt-cache madison kubeadm |
  awk '$3 ~ /^1\.35\./ {print $3; exit}'
)"
```

### O que está a acontecer

- `$(...)` — command substitution: guarda a saída de um comando numa variável;
- `awk` — seleciona apenas versões `1.35.*`;
- `exit` — usa a primeira correspondência devolvida pelo APT.

### Output esperado

```text
K8S_PKG_VERSION=1.35.8-1.1
```

## 9.3. Instalação exata

```bash
sudo apt-get install -y \
  kubelet="$K8S_PKG_VERSION" \
  kubeadm="$K8S_PKG_VERSION" \
  kubectl="$K8S_PKG_VERSION"
```

- `-y` — aceita a confirmação APT;
- `pacote=versão` — exige exatamente aquela versão.

Validar:

```bash
kubeadm version -o short
kubelet --version
kubectl version --client
```

### Output esperado

```text
v1.35.8
Kubernetes v1.35.8
Client Version: v1.35.8
```

**Erro frequente:** aparecer `1.36` ou `1.37` porque o repositório ou a versão não foram fixados.

## 9.4. `apt-mark hold`

```bash
sudo apt-mark hold kubelet kubeadm kubectl
```

Impede que um upgrade genérico do sistema altere estes packages sem intenção.

Durante o upgrade controlado usamos:

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

# 10. Inicializar o Control Plane com `kubeadm`

Esta operação é executada **apenas em `k8s-cp-01`**.

```bash
sudo kubeadm init \
  --kubernetes-version=v1.35.8 \
  --apiserver-advertise-address=192.168.50.46 \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///run/containerd/containerd.sock
```

## 10.1. Flags

| Argumento | Função |
|---|---|
| `--kubernetes-version=v1.35.8` | fixa a versão usada no bootstrap |
| `--apiserver-advertise-address=192.168.50.46` | define o endereço anunciado pelo API Server |
| `--pod-network-cidr=10.244.0.0/16` | define a rede reservada aos Pods |
| `--cri-socket=unix:///run/containerd/containerd.sock` | seleciona explicitamente o runtime CRI |

## 10.2. O que o comando faz

De forma simplificada:

```text
preflight checks
      ↓
certificados
      ↓
kubeconfigs
      ↓
static Pod manifests
      ↓
etcd + API Server + controllers + scheduler
      ↓
configuração kubelet
      ↓
bootstrap concluído
```

Os principais componentes do Control Plane são static Pods geridos pelo kubelet a partir de:

```text
/etc/kubernetes/manifests/
```

## 10.3. Output esperado

No final, `kubeadm` apresenta uma mensagem equivalente a:

```text
Your Kubernetes control-plane has initialized successfully!
```

Também fornece instruções para configurar o kubeconfig e um exemplo de `kubeadm join`.

## 10.4. Porque o Node pode ficar `NotReady`?

Logo após o `init` ainda não existe CNI funcional.

```text
Control Plane criado
       ↓
rede de Pods ainda ausente
       ↓
Node pode estar NotReady
CoreDNS pode não ficar Ready
```

Isto é um estado intermédio esperado. Não se repete `kubeadm init` para “corrigir” este estado.

---

# 11. kubeconfig e contextos

O ficheiro administrativo criado pelo `kubeadm` é:

```text
/etc/kubernetes/admin.conf
```

No laboratório copiamos para:

```text
$HOME/.kube/config
```

## 11.1. Comandos

```bash
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"
```

### O que fazem

- `mkdir -p` — cria a diretoria `.kube`;
- `cp` — copia o kubeconfig administrativo;
- `chown` — atribui o ficheiro ao utilizador atual;
- `chmod 600` — leitura/escrita apenas para o proprietário.

### Porque usamos `$(id -u):$(id -g)`?

Obtém dinamicamente UID e GID do utilizador atual, evitando escrever números fixos.

## 11.2. Conteúdo conceptual

```text
clusters → endpoint e confiança na CA
users    → credenciais
contexts → cluster + user + namespace opcional
```

Comandos úteis:

```bash
kubectl config current-context
kubectl config get-contexts
kubectl config view
```

**Boa prática:** `admin.conf` é privilegiado. Não deve ser copiado para o Worker apenas para facilitar a administração.

---

# 12. Redes do cluster

No laboratório coexistem três espaços de endereçamento:

```text
Rede física   192.168.50.0/24
Pod CIDR      10.244.0.0/16
Service CIDR  10.96.0.0/12
```

## 12.1. Porque não usar `192.168.0.0/16` para Pods?

Porque inclui a rede física `192.168.50.0/24`.

```text
192.168.0.0/16
└── contém 192.168.50.0/24
```

Uma sobreposição pode criar ambiguidades de routing entre a rede física e a rede virtual dos Pods.

## 12.2. Service CIDR

O Service CIDR é usado para IPs virtuais de Services. No laboratório fica no valor predefinido do `kubeadm`:

```text
10.96.0.0/12
```

Não deve ser confundido com endereços dos Nodes nem dos Pods.

---

# 13. CNI, Calico e Tigera Operator

Kubernetes define o modelo de networking, mas precisa de uma implementação CNI para fornecer conectividade aos Pods.

Na sessão usamos:

```text
Calico 3.32.2
Tigera Operator 1.42.6
```

## 13.1. O que é um Operator?

Um Operator observa recursos Kubernetes e automatiza tarefas operacionais de um produto.

```text
Recurso Installation
        ↓
Tigera Operator observa
        ↓
cria/configura componentes Calico
        ↓
rede de Pods converge
```

## 13.2. Manifesto mínimo utilizado

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

### Campos principais

| Campo | Significado |
|---|---|
| `apiVersion` | API group e versão do recurso |
| `kind: Installation` | tipo de recurso observado pelo Operator |
| `metadata.name` | nome do objeto |
| `cidr` | rede atribuída aos Pods |
| `blockSize: 26` | tamanho dos blocos IPAM distribuídos aos Nodes |
| `encapsulation` | política de encapsulamento VXLAN |
| `natOutgoing` | NAT de saída do pool |
| `nodeSelector: all()` | torna o pool aplicável aos Nodes elegíveis |

## 13.3. Validar o Calico

```bash
kubectl get tigerastatus
kubectl get pods -n calico-system -o wide
kubectl get nodes -o wide
```

### Flags

- `-n calico-system` — restringe ao namespace indicado;
- `-o wide` — mostra informação adicional, incluindo Node e IP.

### Output esperado

Para o core Calico:

```text
calico   AVAILABLE=True   PROGRESSING=False   DEGRADED=False
ippools  AVAILABLE=True   PROGRESSING=False   DEGRADED=False
```

A instalação mínima não cria o Tigera `APIServer`, pelo que `tiers` pode apresentar:

```text
Waiting for Tigera API server to be ready
```

No âmbito desta sessão, isso não representa falha do core networking quando `calico` e `ippools` estão saudáveis.

---

# 14. Integrar o Worker

O Worker entra no cluster através de bootstrap controlado.

## 14.1. Gerar o comando de join — Control Plane

```bash
sudo kubeadm token create --print-join-command \
  --kubeconfig=/etc/kubernetes/admin.conf
```

### Flags

| Opção | Função |
|---|---|
| `--print-join-command` | gera um comando de join pronto a usar |
| `--kubeconfig=...` | indica as credenciais administrativas para aceder à API |

### Output esperado

Estrutura semelhante a:

```text
kubeadm join 192.168.50.46:6443 \
  --token abcdef.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:...
```

Os valores reais variam.

## 14.2. Elementos do join

| Elemento | Função |
|---|---|
| `192.168.50.46:6443` | endpoint do API Server |
| `--token` | credencial temporária de bootstrap |
| `--discovery-token-ca-cert-hash` | ajuda o Worker a validar a identidade da CA do cluster |
| `--cri-socket` quando usado | escolhe explicitamente o socket CRI local |

No Worker o comando exige privilégios:

```text
sudo kubeadm join ...
```

### Erro frequente 1 — sem `sudo`

```text
[ERROR IsPrivilegedUser]: user is not running as root
```

Correção: usar os privilégios necessários; não ignorar o preflight.

### Erro frequente 2 — placeholders literais

Isto é documentação:

```text
<IP_CONTROL_PLANE>
<TOKEN>
<HASH>
```

Não se executam os símbolos `< >`. Em Bash têm significado de redirecionamento.

## 14.3. Validar o join

No Worker:

```bash
sudo systemctl is-active kubelet
sudo ls -l /etc/kubernetes/kubelet.conf
```

### Output esperado

```text
active
/etc/kubernetes/kubelet.conf existe
```

No Control Plane:

```bash
kubectl get nodes -o wide
```

Esperado após convergência:

```text
k8s-cp-01   Ready   control-plane   ... v1.35.8
k8s-wk-01   Ready   <none>          ... v1.35.8
```

### Erro frequente 3 — `kubectl` no Worker

Sem kubeconfig administrativo:

```text
The connection to the server localhost:8080 was refused
```

Isto não invalida um join bem-sucedido. A validação global é feita a partir do Control Plane.

---

# 15. Observar antes de alterar

Comandos fundamentais:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
kubectl describe node k8s-wk-01
kubectl get tigerastatus
```

## 15.1. Flags e subcomandos

| Elemento | Função |
|---|---|
| `get` | fotografia resumida do estado |
| `describe` | detalhes, condições e eventos de um objeto |
| `-A` | todos os namespaces |
| `-o wide` | colunas adicionais |
| `--sort-by=.lastTimestamp` | ordena eventos pelo timestamp indicado |

## 15.2. Condições dos Nodes

Nesta sessão observamos especialmente:

```text
Ready=True
DiskPressure=False
```

`Ready=True` indica que o Node está disponível para o cluster. `DiskPressure=True` significa pressão de armazenamento suficiente para o kubelet considerar medidas de eviction.

**Boa prática:** não tirar uma conclusão com base num único comando. Cruzar Nodes, Pods, eventos, serviços locais e logs.

---

# 16. Labels e selectors

Uma label é metadata chave/valor.

```yaml
metadata:
  labels:
    app: cordon-test
```

Pode ser usada para selecionar:

```bash
kubectl get pods -l app=cordon-test
```

- `-l` — label selector.

## 16.1. Label não é `nodeSelector`

```text
label        → descreve um objeto
nodeSelector → restringe scheduling com base em labels de Nodes
```

No Pod de teste:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cordon-test
  labels:
    app: cordon-test
spec:
  nodeSelector:
    kubernetes.io/hostname: k8s-wk-01
  containers:
    - name: web
      image: nginx:1.28.0-alpine
      imagePullPolicy: IfNotPresent
      ports:
        - containerPort: 80
  restartPolicy: Always
```

### Campos

| Campo | Função |
|---|---|
| `kind: Pod` | cria diretamente um Pod |
| `metadata.name` | nome do objeto |
| `labels.app` | label usada na seleção do exercício |
| `nodeSelector` | obriga o Pod a um Node com aquela label |
| `image` | imagem do container |
| `imagePullPolicy: IfNotPresent` | faz pull apenas se a imagem não existir localmente |
| `containerPort: 80` | documenta a porta usada pelo container |
| `restartPolicy: Always` | reinicia o container enquanto o Pod existir |

Este Pod não é controlado por Deployment/ReplicaSet. Isso torna-se importante no `drain`.

---

# 17. `cordon`, `drain` e `uncordon`

Estas três operações fazem parte do ciclo normal de **manutenção de um Node**, mas têm efeitos diferentes. Devem ser entendidas como etapas, não como sinónimos.

```text
Node em serviço
     ↓
cordon
     ↓
impedir novos agendamentos
     ↓
drain
     ↓
evacuar/remover workloads apropriados
     ↓
manutenção
     ↓
uncordon
     ↓
voltar a aceitar scheduling
```

Um cenário típico é atualizar o sistema operativo, reiniciar o host ou atualizar o kubelet. Antes de mexer no Node, reduzimos o risco de novos workloads serem colocados nele e tentamos retirar os workloads que podem ser deslocados.

| Operação | Objetivo | Novos Pods | Pods já existentes |
|---|---|---|---|
| `cordon` | fechar o Node ao scheduling normal | deixam de ser agendados normalmente no Node | permanecem |
| `drain` | preparar o Node para manutenção | Node fica sem novos agendamentos | tenta evacuar/remover os Pods apropriados |
| `uncordon` | reabrir o Node ao scheduler | podem voltar a ser agendados | não recria Pods que tenham sido eliminados |

## 17.1. `cordon`

```bash
kubectl cordon k8s-wk-01
```

### O que faz

`cordon` marca o Node como **unschedulable**, isto é, não elegível para novos agendamentos normais. O Node continua ligado, o kubelet continua a correr e os Pods já existentes continuam onde estavam.

Conceptualmente:

```text
antes
k8s-wk-01 = Ready + aceita novos Pods

cordon
   ↓

depois
k8s-wk-01 = Ready + não aceita novos Pods pelo scheduling normal
```

### Porque é útil?

Imagina que vais reiniciar o Worker. Sem `cordon`, o scheduler poderia colocar um novo Pod nesse Node segundos antes da manutenção. O `cordon` estabiliza o alvo: deixamos de adicionar workloads enquanto preparamos a intervenção.

### Output esperado

```text
node/k8s-wk-01 cordoned
```

Depois:

```bash
kubectl get nodes
```

mostra:

```text
Ready,SchedulingDisabled
```

É importante interpretar corretamente:

```text
Ready               → Node continua saudável e contactável
SchedulingDisabled  → novos agendamentos normais estão bloqueados
```

Os Pods existentes **não são removidos** apenas por causa do `cordon`.

## 17.2. `drain`

Exemplo do laboratório:

```bash
kubectl drain k8s-wk-01 \
  --ignore-daemonsets \
  --pod-selector=app=cordon-test
```

### O que faz

`drain` prepara efetivamente o Node para manutenção. O comando garante que o Node fica sem novos agendamentos e tenta **evacuar ou remover de forma controlada** os Pods abrangidos.

Quando possível, `kubectl drain` utiliza o mecanismo de eviction da API. Isto permite que políticas como PodDisruptionBudget sejam consideradas. Se um Pod pertence a um Deployment, ReplicaSet ou StatefulSet, o respetivo controller pode criar uma substituição noutro Node elegível, desde que o cluster tenha condições para isso.

```text
Pod gerido por controller
        ↓
drain / eviction
        ↓
Pod sai do Node
        ↓
controller observa falta
        ↓
pode criar substituição noutro Node elegível
```

O `drain` também marca o Node como unschedulable. No laboratório executamos `cordon` explicitamente primeiro **para observar e compreender a diferença entre bloquear scheduling e evacuar workloads**.

### Flags

| Flag | Significado |
|---|---|
| `--ignore-daemonsets` | permite continuar sabendo que Pods de DaemonSets não são evacuados desta forma |
| `--pod-selector=...` | limita a operação aos Pods correspondentes à label |
| `--force` | permite continuar com determinados Pods sem controller; exige decisão consciente |

### Porque usamos `--ignore-daemonsets`?

DaemonSets existem precisamente para manter um Pod em cada Node elegível. Componentes como `calico-node`, `csi-node-driver` e `kube-proxy` são exemplos desta sessão. Esses Pods não são tratados como workloads normais a deslocar pelo `drain`.

### Porque o primeiro `drain` do laboratório falha?

O Pod `cordon-test` foi criado diretamente:

```yaml
kind: Pod
```

Não existe Deployment, ReplicaSet ou outro controller que o recrie.

Por isso, o primeiro `drain` deve recusar a remoção. Esta recusa é útil: evita eliminar silenciosamente um workload que não tem mecanismo de reposição.

No exercício controlado acrescentamos:

```text
--force
```

Isto autoriza conscientemente a remoção desse Pod sem controller.

Depois da remoção:

```text
cordon-test deixa de existir
```

Como não existe controller, o Pod **não reaparece automaticamente** noutro Node.

**Boa prática:** não acrescentar `--force` automaticamente sempre que um drain falha. Ler primeiro a razão da recusa e perceber que workload está em risco.

## 17.3. DaemonSets durante o `drain`

Componentes como:

```text
calico-node
csi-node-driver
kube-proxy
```

podem permanecer no Node porque são geridos por DaemonSets.

Isto não significa que o `drain` tenha falhado. Significa que estamos a distinguir workloads normais de componentes cujo modelo é “um Pod por Node elegível”.

## 17.4. `uncordon`

```bash
kubectl uncordon k8s-wk-01
```

### O que faz

`uncordon` remove a marca de unschedulable e volta a tornar o Node elegível para scheduling normal.

### Output esperado

```text
node/k8s-wk-01 uncordoned
```

Depois:

```bash
kubectl get nodes
```

volta a mostrar o Node simplesmente como:

```text
Ready
```

### O que `uncordon` não faz

Não reinicia o Node, não restaura automaticamente Pods eliminados e não “desfaz” o `drain`. Apenas reabre o Node ao scheduler.

Se um Pod direto foi removido com `--force`, continua removido. Se existirem controllers, estes mantêm o seu próprio estado desejado independentemente do `uncordon`.

## 17.5. Resumo operacional

```text
cordon
→ fecha a entrada de novos workloads


drain
→ prepara a manutenção e evacua/remove workloads apropriados


manutenção
→ atualizar, reiniciar ou intervir no Node


uncordon
→ volta a permitir scheduling
```

Pergunta de controlo: se um Node estiver `Ready,SchedulingDisabled`, isso não quer dizer que esteja avariado. Pode simplesmente estar corretamente colocado em manutenção.

---

# 18. Health gates

Um health gate responde à pergunta:

> O cluster está suficientemente saudável para avançarmos para uma alteração de risco?

Antes do upgrade queremos:

```text
Nodes Ready
DiskPressure=False
Pods críticos estáveis
CoreDNS Ready
Calico core saudável
containerd ativo
kubelet ativo
sem churn persistente
sem erros graves recorrentes do runtime
```

Um comando útil:

```bash
kubectl get nodes \
  -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,DISK:.status.conditions[?(@.type=="DiskPressure")].status,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion'
```

## 18.1. Como ler `-o custom-columns`

- `-o` — escolhe formato de output;
- `custom-columns=...` — define as colunas pretendidas;
- `.metadata.name` — nome do Node;
- `.status.conditions[...]` — procura uma condição específica;
- `.status.nodeInfo.kubeletVersion` — versão do kubelet;
- `.status.nodeInfo.containerRuntimeVersion` — runtime reportado pelo Node.

### Output esperado antes do upgrade

```text
NAME        READY   DISK    KUBELET   RUNTIME
k8s-cp-01   True    False   v1.35.8   containerd://2.2.6
k8s-wk-01   True    False   v1.35.8   containerd://2.2.6
```

---

# 19. Recuperação antes do upgrade

Depois de o health gate estar limpo, criamos snapshots coordenados das duas VMs.

```text
cluster saudável
      ↓
snapshot Control Plane
snapshot Worker
      ↓
upgrade
```

Os snapshots são um ponto de retorno do **ambiente pedagógico**.

> Em produção, snapshots de VMs não substituem uma estratégia de backup e recuperação do cluster. É necessário considerar `etcd`, certificados, configuração e workloads com dados.

Também não tratamos rollback Kubernetes como simples downgrade de packages APT.

---

# 20. Upgrade Kubernetes: princípios

O percurso validado é:

```text
1.35.8
  ↓
1.36.4
```

A ordem é deliberada:

```text
1. atualizar kubeadm do Control Plane
2. kubeadm upgrade plan
3. kubeadm upgrade apply
4. drain do Control Plane
5. atualizar kubelet/kubectl do Control Plane
6. validar e uncordon
7. atualizar kubeadm do Worker
8. kubeadm upgrade node
9. drain do Worker
10. atualizar kubelet/kubectl do Worker
11. validar e uncordon
12. health gate final
```

## 20.1. Porque `kubeadm` primeiro?

`kubeadm` conhece o workflow e as validações do upgrade para a versão destino. O binário é atualizado antes de aplicar o upgrade ao cluster.

---

# 21. `kubeadm upgrade plan`

```bash
sudo kubeadm upgrade plan
```

## O que faz

Analisa o estado atual e indica o upgrade possível.

## O que não faz

Não altera o cluster.

### Output relevante observado

```text
Cluster: 1.35.8
Target:  1.36.4
```

O plano também mostra componentes e addons afetados.

**Boa prática:** distinguir sempre uma operação de análise de uma operação que altera estado.

---

# 22. `kubeadm upgrade apply`

No primeiro Control Plane:

```bash
sudo kubeadm upgrade apply v1.36.4
```

## 22.1. Significado

- `upgrade` — entra no workflow de atualização;
- `apply` — aplica efetivamente o upgrade;
- `v1.36.4` — versão Kubernetes destino.

## 22.2. O que aconteceu no ensaio

Foram atualizados:

```text
kube-apiserver            1.35.8 → 1.36.4
kube-controller-manager   1.35.8 → 1.36.4
kube-scheduler            1.35.8 → 1.36.4
kube-proxy                1.35.8 → 1.36.4
CoreDNS                   1.13.1 → 1.14.2
etcd                      3.6.6-0 → 3.6.8-0
```

Durante a reinicialização de `etcd` surgiram timeouts transitórios, mas o próprio `kubeadm` recuperou a operação e terminou com:

```text
[upgrade] SUCCESS!
```

### Aprendizagem

Uma linha intermédia de erro não significa automaticamente que toda a operação falhou. É necessário interpretar o resultado completo e voltar a validar o estado.

---

# 23. Versões mistas durante o upgrade

Depois de `kubeadm upgrade apply`, é normal observar temporariamente:

```text
API Server:      1.36.4
kubelet CP:      1.35.8
kubelet Worker:  1.35.8
kubectl client:  1.35.8
```

## Porque acontece?

Porque `kubeadm upgrade apply` atualiza o Control Plane e addons, mas o package do kubelet ainda não foi atualizado.

`kubectl get nodes` mostra a versão do **kubelet**, não a do API Server.

Exemplo:

```text
kubectl version
Client Version: v1.35.8
Server Version: v1.36.4

kubectl get nodes
k8s-cp-01 ... v1.35.8
```

Não existe contradição. Estamos a consultar componentes diferentes.

---

# 24. Atualizar o kubelet do Control Plane

Antes de mudar a minor do kubelet, drenamos o Node:

```bash
kubectl drain k8s-cp-01 --ignore-daemonsets
```

### Output esperado

```text
node/k8s-cp-01 cordoned
...
node/k8s-cp-01 drained
```

Os static Pods do Control Plane permanecem porque são geridos localmente pelo kubelet e não como workloads normais a evacuar.

Atualizamos depois:

```text
kubelet 1.35.8 → 1.36.4
kubectl 1.35.8 → 1.36.4
```

Reiniciamos:

```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

### Porque `daemon-reload`?

Faz o `systemd` reler as definições das units antes de reiniciar o serviço.

### Estado transitório observado

Imediatamente após o restart vimos:

```text
NotReady,SchedulingDisabled
```

Pouco depois:

```text
Ready,SchedulingDisabled
```

Só então executámos:

```bash
kubectl uncordon k8s-cp-01
```

**Boa prática:** não confundir um estado transitório curto com uma falha persistente; observar a convergência.

---

# 25. Atualizar o Worker

O Worker não usa `kubeadm upgrade apply`.

Primeiro atualizamos o binário `kubeadm`, depois:

```bash
sudo kubeadm upgrade node
```

## 25.1. O que faz

Atualiza a configuração local do kubelet para a nova versão de configuração.

## 25.2. O que não faz

Não atualiza automaticamente o package `kubelet`.

É normal ficar temporariamente:

```text
kubeadm  v1.36.4
kubelet  v1.35.8
```

Depois o Worker é drenado a partir do Control Plane e o kubelet é atualizado localmente.

## 25.3. Tigera Operator e o drain

No cluster pedagógico de dois Nodes, o Tigera Operator estava no Worker antes do drain integral.

Para tornar o comportamento previsível durante a manutenção, foi aplicado temporariamente:

```yaml
nodeSelector:
  kubernetes.io/hostname: k8s-cp-01
```

Depois do upgrade e `uncordon`, esse `nodeSelector` foi removido.

Esta é uma decisão específica da topologia pedagógica. Não é uma regra universal de Kubernetes.

---

# 26. Resultado final validado

O health gate final apresentou:

```text
NAME        READY   DISK    KUBELET   RUNTIME
k8s-cp-01   True    False   v1.36.4   containerd://2.2.6
k8s-wk-01   True    False   v1.36.4   containerd://2.2.6
```

`kubectl version` apresentou:

```text
Client Version: v1.36.4
Server Version: v1.36.4
```

Todos os Pods ativos estavam `Running`, não existiam recursos anómalos no filtro final e o core Calico permanecia saudável.

```text
1.35.8 saudável
      ↓
Control Plane → 1.36.4
      ↓
Worker ainda 1.35.8
      ↓
Worker → 1.36.4
      ↓
cluster convergido
      ↓
1.36.4 saudável
```

---

# 27. Troubleshooting orientado por evidências

A metodologia é:

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

Não usamos:

```text
erro → acrescentar flags aleatórias → esconder o erro
```

## 27.1. `DiskPressure`

### Sintoma

```text
DiskPressure=True
Pods Evicted
```

### Evidência

```bash
kubectl describe node <NODE>
df -h /
lsblk
sudo pvs
sudo vgs
sudo lvs
```

### Causa observada

O disco virtual tinha capacidade, mas o Logical Volume do filesystem raiz não tinha sido expandido.

### Aprendizagem

```text
tamanho do disco virtual ≠ capacidade disponível em /
```

## 27.2. `kubectl` no Worker tenta `localhost:8080`

### Sintoma

```text
The connection to the server localhost:8080 was refused
```

### Interpretação

O utilizador não tem kubeconfig administrativo configurado naquele Node.

### Ação correta no laboratório

Administrar a partir do Control Plane; no Worker, validar serviços e configuração local.

## 27.3. `kubeadm token create` no Worker

### Sintoma

Falha a carregar kubeconfig administrativo.

### Causa

O comando está a ser executado no Node errado.

```text
Control Plane → cria token
Worker        → executa join
```

## 27.4. Erro de chave GPG do repositório Docker

Foi observado:

```text
NO_PUBKEY 7EA0A9C3F273FCD8
```

A correção consistiu em recriar a configuração atual do repositório Docker com `docker.asc` e `docker.sources`, e só depois repetir `apt-get update`.

### Aprendizagem

Se o APT reutilizar índices antigos devido a erro de assinatura, não devemos assumir que todos os repositórios foram atualizados corretamente.

## 27.5. AppArmor / runc

Num ensaio anterior surgiram:

```text
unable to signal init: permission denied
apparmor="DENIED"
```

Na baseline limpa com `containerd 2.2.6` e `runc 1.3.6`, o problema **não se reproduziu** após criação/remoção de Pods, drains e upgrade.

A conclusão suportada pela evidência é apenas:

```text
problema anterior não reproduzido na baseline validada
```

Não concluímos que AppArmor estava “avariado” nem que uma versão específica é, por si só, causa ou cura.

Não se desativa AppArmor globalmente como primeira tentativa.

## 27.6. Warnings de arranque do kubelet

Foram observadas de forma transitória mensagens como:

```text
checkpoint is not found
no imagefs label for configured runtime
```

O Node convergiu para:

```text
Ready=True
DiskPressure=False
```

As mensagens não persistiram como falha operacional.

```text
uma linha isolada no log
        ≠
falha persistente
```

Devemos verificar recorrência, impacto, condições do Node e estado dos Pods.

---

# 28. Como interpretar os principais outputs

## 28.1. `kubectl get nodes`

```text
NAME        STATUS   ROLES           VERSION
k8s-cp-01   Ready    control-plane   v1.36.4
k8s-wk-01   Ready    <none>          v1.36.4
```

- `NAME` — nome registado do Node;
- `STATUS` — condição de disponibilidade resumida;
- `ROLES` — papel identificado por labels;
- `VERSION` — versão do **kubelet**.

## 28.2. `kubectl get pods -A -o wide`

Colunas frequentes:

| Coluna | Significado |
|---|---|
| `NAMESPACE` | namespace do Pod |
| `NAME` | nome do Pod |
| `READY` | containers prontos / total |
| `STATUS` | fase/estado resumido |
| `RESTARTS` | reinícios observados |
| `AGE` | idade do objeto |
| `IP` | IP do Pod ou host-network |
| `NODE` | Node onde está agendado |

Um Pod `Running` com `READY 0/1` ainda não está pronto.

## 28.3. `kubectl get tigerastatus`

```text
AVAILABLE   PROGRESSING   DEGRADED
True        False         False
```

- `AVAILABLE=True` — componente disponível;
- `PROGRESSING=True` — ainda a convergir;
- `DEGRADED=True` — existe condição degradada.

Nesta instalação mínima, interpretar `tiers` separadamente devido à ausência deliberada do Tigera API Server.

---

# 29. Comandos de observação que deves dominar

| Objetivo | Comando |
|---|---|
| Nodes | `kubectl get nodes -o wide` |
| Pods de todos os namespaces | `kubectl get pods -A -o wide` |
| Estado Calico | `kubectl get tigerastatus` |
| Eventos | `kubectl get events -A --sort-by=.lastTimestamp` |
| Detalhes de Node | `kubectl describe node <NODE>` |
| Versões cliente/servidor | `kubectl version` |
| Versão kubelet local | `kubelet --version` |
| Serviço kubelet | `systemctl is-active kubelet` |
| Serviço containerd | `systemctl is-active containerd` |
| Logs kubelet | `journalctl -u kubelet --since "-10 min" --no-pager` |
| Logs kernel | `journalctl -k --since "-10 min" --no-pager` |

## Flags frequentes do `kubectl`

| Flag | Função |
|---|---|
| `-n <namespace>` | restringe a um namespace |
| `-A` | todos os namespaces |
| `-o wide` | acrescenta informação |
| `-o yaml` | mostra representação YAML |
| `-l chave=valor` | label selector |
| `--field-selector` | filtra por campos do objeto |
| `--sort-by` | ordena pelo campo indicado |
| `--no-headers` | omite cabeçalhos |
| `--help` | ajuda contextual do comando |

---

# 30. Pontos-chave da sessão

```text
Kubernetes trabalha por estado desejado e reconciliação.

Control Plane gere o cluster.
Worker executa workloads.

kubeadm ≠ kubelet ≠ kubectl.

kubelet comunica com containerd através do CRI.

Hosts, Pods e Services usam redes distintas.

CNI é necessário para a rede de Pods.

Ready=True não elimina a necessidade de observar outras condições.

DiskPressure é uma condição operacional importante.

label ≠ nodeSelector.

cordon ≠ drain ≠ uncordon.

upgrade plan observa; upgrade apply altera.

A VERSION de `kubectl get nodes` é a versão do kubelet.

Control Plane e Worker não são atualizados da mesma forma.

Upgrades minor são sequenciais.

Antes de alterar: observar.
Depois de alterar: validar novamente.
```

---

# 31. Exercícios de consolidação

## Exercício 1 — Da CLI à API

Explica o percurso desde:

```bash
kubectl get nodes
```

até à resposta apresentada no terminal. Inclui kubeconfig, API Server e autenticação/autorização.

## Exercício 2 — Runtime

Ordena:

```text
runc
kubelet
kernel
containerd
CRI
```

Depois explica a função de cada elemento.

## Exercício 3 — Redes

Dada a rede física:

```text
192.168.50.0/24
```

explica por que `192.168.0.0/16` entra em conflito com o laboratório e por que `10.244.0.0/16` evita a sobreposição.

## Exercício 4 — Estado intermédio do upgrade

Observas:

```text
kubectl version    → Server v1.36.4
kubectl get nodes  → k8s-cp-01 v1.35.8
```

Existe contradição? Justifica.

## Exercício 5 — Manutenção

Explica a diferença entre:

```text
cordon
drain
uncordon
```

E explica por que `--force` não deve ser acrescentado automaticamente quando um `drain` falha.

## Exercício 6 — `DiskPressure`

Um Node apresenta:

```text
Ready=True
DiskPressure=True
```

Que evidências recolherias antes de tentar corrigir?

## Exercício 7 — Upgrade

Ordena corretamente:

```text
kubeadm upgrade plan
upgrade kubeadm no Worker
health gate final
kubeadm upgrade node
upgrade kubelet Control Plane
kubeadm upgrade apply
upgrade kubeadm Control Plane
upgrade kubelet Worker
```

## Exercício 8 — Interpretação de Pod

Tens:

```text
READY   STATUS    RESTARTS
0/1     Running   0
```

O Pod está pronto para servir tráfego? Explica a diferença entre `STATUS=Running` e `READY=1/1`.

---

# 32. Autoavaliação

No final da sessão, confirma se consegues afirmar:

- [ ] Sei explicar estado desejado, estado observado e reconciliação.
- [ ] Sei identificar os principais componentes do Control Plane e dos Nodes.
- [ ] Sei distinguir `kubeadm`, `kubelet` e `kubectl`.
- [ ] Sei explicar CRI, containerd, runc e cgroups.
- [ ] Sei interpretar os comandos básicos de preparação Linux.
- [ ] Sei verificar o espaço real do filesystem e interpretar `DiskPressure`.
- [ ] Sei explicar por que o Pod CIDR não pode sobrepor-se à rede das VMs.
- [ ] Sei explicar o papel do CNI e do Calico.
- [ ] Sei explicar kubeconfig e contextos.
- [ ] Sei gerar o join no Control Plane e executá-lo no Worker.
- [ ] Sei interpretar labels e `nodeSelector`.
- [ ] Sei aplicar e interpretar `cordon`, `drain` e `uncordon`.
- [ ] Sei construir um health gate antes de um upgrade.
- [ ] Sei explicar a sequência `1.35.x → 1.36.x`.
- [ ] Sei explicar `upgrade plan`, `upgrade apply` e `upgrade node`.
- [ ] Sei interpretar um cluster temporariamente com versões diferentes.
- [ ] Sei ler os principais campos de `kubectl get nodes` e `kubectl get pods`.
- [ ] Sei distinguir um warning transitório de uma falha persistente através de evidências.

---

# 33. Laboratório e recursos de apoio

O procedimento operacional completo encontra-se em:

```text
sessao-04/formando/labs/laboratorio_integrado_sessao_4.md
```

Recursos complementares:

- [`README.md`](README.md) — enquadramento da sessão;
- [`compatibilidade.md`](compatibilidade.md) — matriz de versões;
- [`checklist.md`](checklist.md) — preparação das VMs;
- [`checklist_operacional.md`](checklist_operacional.md) — checkpoints;
- [`folha_evidencias.md`](folha_evidencias.md) — registo de evidências;
- [`cheat_sheet.md`](cheat_sheet.md) — referência rápida;
- [`troubleshooting.md`](troubleshooting.md) — diagnóstico por evidências;
- [`manifests/`](manifests/) — manifests usados na sessão;
- [`referencias.md`](referencias.md) — bibliografia e documentação.

---

# 34. Fontes e leituras recomendadas

A preparação conceptual deste manual é coerente com a bibliografia disponibilizada na formação, nomeadamente:

- *The Kubernetes Book* — modelo declarativo, estado desejado, reconciliação, Control Plane, CNI e CRI;
- *Kubernetes in Action* — arquitetura, Pods, Nodes, scheduling e operação;
- *Kubernetes: Up & Running* — arquitetura e administração de clusters Kubernetes.

Para procedimentos dependentes da versão deve prevalecer a documentação oficial da versão utilizada:

- Kubernetes v1.36 — Cluster Architecture;
- Kubernetes — Container Runtimes / CRI e cgroup drivers;
- Kubernetes v1.36 — Upgrading kubeadm clusters 1.35.x → 1.36.x;
- Calico — System requirements e versões Kubernetes testadas;
- containerd — Kubernetes support matrix.

> Os livros são especialmente úteis para conceitos e modelos mentais. Para versões suportadas, compatibilidade, flags e procedimentos de upgrade, deve ser consultada a documentação oficial correspondente à versão em utilização.
