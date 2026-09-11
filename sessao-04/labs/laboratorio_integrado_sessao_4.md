# Laboratório Integrado — Sessão 4
## Kubernetes Admin I: instalar, operar e atualizar o cluster

**Sessão:** 4 de 10  
**Duração:** 4 horas / 240 minutos  
**Nível:** intermédio  
**Topologia:** `k8s-cp-01` + `k8s-wk-01`

Este documento é o **único laboratório da Sessão 4**. O manual do formando explica os conceitos com maior profundidade; aqui mantemos explicação suficiente para que cada formando saiba **o que está a fazer, por que o faz, o que deve observar e quando é seguro avançar**.

Em cada bloco usamos esta lógica:

```text
OBJETIVO
   ↓
O QUE ESTAMOS A FAZER E PORQUÊ
   ↓
ONDE EXECUTAR
   ↓
COMANDOS
   ↓
O QUE OBSERVAR
   ↓
CHECKPOINT
   ↓
EVIDÊNCIA
```

> Não avançar para o bloco seguinte enquanto o checkpoint atual não estiver validado.

---

# 0. Baseline validada

```text
Ubuntu:              26.04.1 LTS
Kernel:              7.0.0-31-generic
Control Plane:       k8s-cp-01 / 192.168.50.46
Worker:              k8s-wk-01 / 192.168.50.65
Kubernetes inicial:  1.35.8
Kubernetes final:    1.36.4
containerd:          2.2.6
runc:                 1.3.6
Calico:               3.32.2
Tigera Operator:      1.42.6
Pod CIDR:             10.244.0.0/16
Service CIDR:         10.96.0.0/12
Filesystem /:         40 GB no ambiente validado
```

A rede física é `192.168.50.0/24`. O Pod CIDR `10.244.0.0/16` foi escolhido para não sobrepor essa rede física.

---

# CP0 — Obter ou atualizar os recursos da formação

## Objetivo

Garantir que os manifests usados mais tarde existem localmente e correspondem à versão atual da branch `main` do repositório da formação.

**Executar em:** `k8s-cp-01`.

## O que estamos a fazer e porquê

O laboratório usa manifests que estão no GitHub da formação. Não assumimos que a pasta `~/formacao-kubernetes` já existe. Primeiro garantimos que `git` está instalado; depois fazemos `clone` se o repositório ainda não existir ou `pull` se já existir.

```bash
sudo apt-get update
sudo apt-get install -y git
```

Definir a localização local e o repositório remoto:

```bash
REPO_DIR="$HOME/formacao-kubernetes"
REPO_URL="https://github.com/Skullclamp/formacao-kubernetes.git"
```

Obter ou atualizar o repositório:

```bash
if [ -d "$REPO_DIR/.git" ]; then
  git -C "$REPO_DIR" switch main
  git -C "$REPO_DIR" pull --ff-only origin main
elif [ -e "$REPO_DIR" ]; then
  BACKUP_DIR="${REPO_DIR}.bak-$(date +%Y%m%d-%H%M%S)"
  mv "$REPO_DIR" "$BACKUP_DIR"
  echo "Diretoria anterior preservada em: $BACKUP_DIR"
  git clone --branch main --single-branch "$REPO_URL" "$REPO_DIR"
else
  git clone --branch main --single-branch "$REPO_URL" "$REPO_DIR"
fi
```

### Como interpretar

- `git -C "$REPO_DIR" ...` executa o comando dentro do repositório sem obrigar a mudar de diretoria;
- `switch main` garante que estamos na branch usada na formação;
- `pull --ff-only` atualiza sem criar merges locais inesperados;
- `clone --branch main --single-branch` obtém apenas a branch necessária;
- se já existir uma pasta com o mesmo nome que não seja um repositório Git, ela é preservada como `.bak-...` antes do clone.

Confirmar os recursos necessários:

```bash
test -d "$REPO_DIR/.git" \
  && echo 'OK: repositório Git disponível'

test -f "$REPO_DIR/sessao-04/manifests/calico_installation_sessao4.yaml" \
  && echo 'OK: manifesto Calico disponível'

test -f "$REPO_DIR/sessao-04/manifests/pod_cordon_test.yaml" \
  && echo 'OK: manifesto do Pod de teste disponível'
```

### CHECKPOINT CP0

```text
repositório clonado ou atualizado a partir de main
~/formacao-kubernetes/.git existe
calico_installation_sessao4.yaml existe
pod_cordon_test.yaml existe
```

**Não avançar se algum dos dois manifests não existir.**

**Evidência:** guardar o output dos três testes `OK`.

---

# CP1 — Preparar as duas VMs

## Objetivo

Validar que os dois hosts Linux têm identidade, recursos, kernel e parâmetros de rede adequados antes de instalar Kubernetes.

**Executar em:** `k8s-cp-01` e `k8s-wk-01`.

## 1.1. Confirmar identidade e recursos

Antes de alterar qualquer coisa queremos saber exatamente **em que VM estamos** e se o host tem condições para prosseguir.

```bash
hostname
ip -br address
free -h
swapon --show
lsblk -f
df -h /
stat -fc %T /sys/fs/cgroup
```

### O que observar

- `hostname` deve corresponder ao Node pretendido;
- `ip -br address` deve mostrar o IP correto da VM;
- `swapon --show` deve ficar sem entradas depois de desativarmos a swap;
- `df -h /` mostra o espaço realmente utilizável no filesystem raiz;
- `stat ... /sys/fs/cgroup` deve indicar `cgroup2fs`.

Se o disco virtual tiver espaço mas `/` continuar pequeno, **não assumir que o filesystem cresceu automaticamente**. Confirmar o layout LVM:

```bash
sudo pvs
sudo vgs
sudo lvs
```

Se houver falta de espaço, corrigir primeiro o volume/filesystem e voltar a validar `df -h /`.

## 1.2. Swap, módulos e sysctl

Desativamos a swap para manter a baseline deste laboratório e carregamos módulos necessários à rede e ao armazenamento em camadas dos containers.

```bash
sudo swapoff -a

cat <<'EOF' | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

Depois ativamos forwarding IPv4 e o processamento de tráfego bridged por netfilter:

```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
```

Validar:

```bash
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
```

### O que observar

```text
overlay carregado
br_netfilter carregado
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
```

Se algum módulo não aparecer ou algum `sysctl` não devolver `1`, parar e corrigir antes de instalar o runtime.

## 1.3. Resolução entre nós

Os dois Nodes precisam de conseguir resolver os nomes usados no laboratório.

Confirmar `/etc/hosts` nos dois nós:

```text
192.168.50.46  k8s-cp-01
192.168.50.65  k8s-wk-01
```

Se as entradas não existirem, adicioná-las:

```bash
grep -q 'k8s-cp-01' /etc/hosts \
  || echo '192.168.50.46  k8s-cp-01' | sudo tee -a /etc/hosts

grep -q 'k8s-wk-01' /etc/hosts \
  || echo '192.168.50.65  k8s-wk-01' | sudo tee -a /etc/hosts
```

Validar resolução e conectividade:

```bash
getent hosts k8s-cp-01
getent hosts k8s-wk-01
ping -c 2 k8s-cp-01
ping -c 2 k8s-wk-01
```

### CHECKPOINT CP1

```text
hostname correto
IPs corretos
swap desativada
cgroup v2
módulos overlay e br_netfilter carregados
ip_forward = 1
bridge-nf-call-iptables = 1
resolução e ping entre Nodes
filesystem / sem pressão de espaço
```

**Evidência:** guardar `hostname`, `df -h /`, resultado dos dois `sysctl` e um teste de resolução.

---

# CP2 — Instalar e validar containerd 2.2.6

## Objetivo

Instalar o runtime de containers que será utilizado pelo kubelet e garantir que a integração CRI e o cgroup driver estão configurados corretamente.

**Executar em:** ambos os nós.

## 2.1. Configurar o repositório Docker

A baseline validada usa o package `containerd.io` disponibilizado pelo repositório Docker. Primeiro instalamos os utilitários necessários, a chave de assinatura e a origem APT.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt-get update
apt-cache madison containerd.io | head
```

### O que estamos a verificar

`apt-cache madison` mostra as versões disponíveis. Não queremos instalar simplesmente “a última versão” sem controlo; queremos a série ensaiada no laboratório.

Selecionar `2.2.6`:

```bash
CONTAINERD_PKG_VERSION="$(
  apt-cache madison containerd.io |
  awk '$3 ~ /^2\.2\.6/ {print $3; exit}'
)"

test -n "$CONTAINERD_PKG_VERSION"
printf 'containerd.io: %s\n' "$CONTAINERD_PKG_VERSION"
```

Se a variável ficar vazia, **não avançar**: a versão esperada não está disponível na origem APT configurada.

Instalar e colocar em `hold`:

```bash
sudo apt-get install -y containerd.io="$CONTAINERD_PKG_VERSION"
sudo apt-mark hold containerd.io
```

O `hold` evita que um upgrade genérico do sistema altere o runtime a meio do laboratório.

## 2.2. Gerar e corrigir a configuração

Gerar uma configuração base:

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
```

Abrir o ficheiro:

```bash
sudo nano /etc/containerd/config.toml
```

Temos de garantir duas condições:

```text
CRI não está em disabled_plugins
SystemdCgroup = true
```

### Se o CRI estiver desativado

Confirmar:

```bash
grep -n 'disabled_plugins' /etc/containerd/config.toml
```

Se aparecer `cri` em `disabled_plugins`, remover `cri` dessa lista e guardar o ficheiro. O kubelet precisa do CRI para comunicar com o containerd.

### Se `SystemdCgroup` estiver a `false`

Localizar:

```bash
grep -n -A5 -B5 'SystemdCgroup' /etc/containerd/config.toml
```

Na secção do runtime `runc`, alterar para:

```text
SystemdCgroup = true
```

A baseline usa `systemd` com cgroup v2; queremos kubelet e runtime alinhados na gestão dos cgroups.

## 2.3. Reiniciar e validar o runtime

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
```

Confirmar serviço, versões, CRI e cgroup driver:

```bash
containerd --version
runc --version
sudo systemctl is-active containerd
sudo ctr plugins ls | grep -i cri
containerd config dump | grep -i -A5 -B5 SystemdCgroup
```

### O que observar

```text
containerd 2.2.6
runc 1.3.6
containerd.service = active
plugins CRI com estado ok
SystemdCgroup = true
```

Se `containerd` não estiver `active`:

```bash
sudo systemctl status containerd --no-pager
sudo journalctl -u containerd -n 50 --no-pager
```

**Não avançar** enquanto o runtime não estiver saudável.

### CHECKPOINT CP2

```text
containerd 2.2.6
runc 1.3.6
containerd ativo
CRI disponível
SystemdCgroup = true
containerd.io em hold
```

**Evidência:** guardar as versões, `is-active` e a linha de `SystemdCgroup`.

---

# CP3 — Instalar Kubernetes 1.35.8

## Objetivo

Instalar `kubeadm`, `kubelet` e `kubectl` numa versão explicitamente controlada, igual nos dois Nodes.

**Executar em:** ambos os nós.

## 3.1. Configurar o repositório da minor 1.35

O repositório já limita os packages à minor pretendida. Isto reduz o risco de instalar acidentalmente uma versão 1.36 ou 1.37.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
```

## 3.2. Fixar o patch validado

```bash
K8S_PKG_VERSION='1.35.8-1.1'

apt-cache madison kubeadm | grep -F "$K8S_PKG_VERSION"
```

Se esta pesquisa não devolver a versão, parar. Não substituir silenciosamente por outra minor.

Instalar:

```bash
sudo apt-get install -y \
  kubelet="$K8S_PKG_VERSION" \
  kubeadm="$K8S_PKG_VERSION" \
  kubectl="$K8S_PKG_VERSION"

sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
```

> Antes de `kubeadm init` ou `kubeadm join`, o kubelet pode reiniciar ou não conseguir estabilizar porque ainda não tem configuração de cluster. Nesta fase interessa sobretudo validar a versão instalada.

Validar:

```bash
kubeadm version -o short
kubelet --version
kubectl version --client
apt-mark showhold
```

### CHECKPOINT CP3

Esperado nos dois Nodes:

```text
kubeadm  v1.35.8
kubelet  v1.35.8
kubectl  v1.35.8
containerd.io, kubeadm, kubelet e kubectl em hold
```

**Evidência:** guardar as três versões nos dois Nodes.

---

# CP4 — Inicializar o Control Plane

## Objetivo

Criar o primeiro Control Plane Kubernetes, definir explicitamente a rede de Pods e ligar o kubeadm ao socket CRI do containerd.

**Executar apenas em:** `k8s-cp-01`.

Confirmar primeiro a identidade:

```bash
hostname
```

Esperado:

```text
k8s-cp-01
```

## 4.1. Executar `kubeadm init`

```bash
sudo kubeadm init \
  --kubernetes-version=v1.35.8 \
  --apiserver-advertise-address=192.168.50.46 \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///run/containerd/containerd.sock
```

### O que estamos a definir

- `--kubernetes-version` fixa a versão do bootstrap;
- `--apiserver-advertise-address` define o IP pelo qual o API Server é anunciado;
- `--pod-network-cidr` reserva `10.244.0.0/16` para a rede dos Pods;
- `--cri-socket` indica explicitamente o containerd.

Durante o `init`, o kubeadm executa preflight checks, cria certificados/kubeconfigs, static Pods do Control Plane e configura o kubelet.

## 4.2. Configurar o kubeconfig administrativo

O `admin.conf` criado pelo kubeadm é privilegiado. Copiamo-lo para o utilizador atual para que `kubectl` possa comunicar com a API.

```bash
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"
```

Validar:

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -n kube-system
```

### O que observar

Nesta fase é normal observar:

```text
Control Plane criado
Node ainda NotReady
CoreDNS Pending/NotReady
```

Isto acontece porque ainda **não instalámos o CNI**. Não repetir `kubeadm init` por causa deste estado intermédio.

### CHECKPOINT CP4

```text
kubeadm init terminou com sucesso
API Server acessível por kubectl
kubeconfig funcional
Control Plane criado em 1.35.8
Pod CIDR = 10.244.0.0/16
```

**Evidência:** guardar o resultado de `kubectl cluster-info` e `kubectl get nodes`.

---

# CP5 — Instalar Calico 3.32.2

## Objetivo

Instalar o CNI que fornece conectividade à rede de Pods e permitir que o Node/CoreDNS passem a convergir para um estado saudável.

**Executar em:** `k8s-cp-01`.

## 5.1. Criar CRDs e Tigera Operator

Primeiro instalamos as definições de recursos do Calico e o Operator que irá observar/configurar esses recursos.

```bash
export CALICO_VERSION=v3.32.2

kubectl create -f \
  https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/v1_crd_projectcalico_org.yaml

kubectl create -f \
  https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml
```

O primeiro comando introduz os CRDs necessários. O segundo instala o Tigera Operator. Ainda falta declarar **como queremos a instalação do Calico**.

## 5.2. Obter e validar o manifesto da formação

Garantir que o repositório continua presente e atualizado:

```bash
REPO_DIR="$HOME/formacao-kubernetes"
MANIFEST_DIR="$REPO_DIR/sessao-04/manifests"

git -C "$REPO_DIR" switch main
git -C "$REPO_DIR" pull --ff-only origin main

test -d "$MANIFEST_DIR"
test -f "$MANIFEST_DIR/calico_installation_sessao4.yaml"
```

Se algum `test` falhar, voltar ao CP0. Não executar um caminho inexistente.

Confirmar o CIDR antes de aplicar:

```bash
grep -n 'cidr:' \
  "$MANIFEST_DIR/calico_installation_sessao4.yaml"
```

Esperado:

```text
cidr: 10.244.0.0/16
```

Esta validação é importante porque o CNI tem de usar a mesma rede de Pods que foi declarada no `kubeadm init`.

Aplicar a configuração:

```bash
kubectl create -f \
  "$MANIFEST_DIR/calico_installation_sessao4.yaml"
```

## 5.3. Observar a convergência

```bash
kubectl get pods -n tigera-operator -o wide
kubectl get pods -n calico-system -o wide
kubectl get tigerastatus
kubectl get nodes -o wide
```

### O que observar

Queremos ver progressivamente:

```text
Tigera Operator Running
Pods de calico-system Running/Ready
calico Available=True
ippools Available=True
Control Plane Ready
CoreDNS Running/Ready
```

Na instalação mínima da sessão, `tiers` pode indicar `Waiting for Tigera API server`. Isso é esperado porque não criamos o recurso Tigera APIServer neste laboratório. O critério de rede é o core `calico`/`ippools` e a conectividade do cluster.

### CHECKPOINT CP5

```text
Calico core saudável
Control Plane Ready
CoreDNS Running/Ready
Pod CIDR do Calico = 10.244.0.0/16
```

**Evidência:** guardar `kubectl get tigerastatus` e `kubectl get nodes -o wide`.

---

# CP6 — Integrar o Worker

## Objetivo

Adicionar `k8s-wk-01` ao cluster usando bootstrap autenticado e validar que o kubelet do Worker passa a comunicar com o Control Plane.

## 6.1. Gerar o join

**Executar em:** `k8s-cp-01`.

```bash
sudo kubeadm token create --print-join-command \
  --kubeconfig=/etc/kubernetes/admin.conf
```

### O que está a acontecer

O Control Plane cria um token temporário de bootstrap e devolve um comando que contém:

```text
endpoint do API Server
+ token
+ hash da CA
```

O hash ajuda o Worker a validar que está a falar com o cluster esperado.

Copiar o comando real devolvido.

## 6.2. Executar o join

**Executar em:** `k8s-wk-01`.

Confirmar primeiro:

```bash
hostname
```

Depois executar o comando real, acrescentando o socket CRI se necessário:

```text
sudo kubeadm join 192.168.50.46:6443 \
  --token TOKEN_REAL \
  --discovery-token-ca-cert-hash sha256:HASH_REAL \
  --cri-socket=unix:///run/containerd/containerd.sock
```

Não executar `TOKEN_REAL` ou `HASH_REAL` literalmente. Devem ser substituídos pelos valores gerados no Control Plane.

## 6.3. Validar localmente e a partir do cluster

No Worker:

```bash
sudo systemctl is-active kubelet
sudo ls -l /etc/kubernetes/kubelet.conf
```

O ficheiro `kubelet.conf` prova que o kubelet recebeu configuração para comunicar com o cluster.

No Control Plane:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
```

### O que observar

Após a convergência:

```text
k8s-cp-01   Ready   ... v1.35.8
k8s-wk-01   Ready   ... v1.35.8
```

Os Pods de infraestrutura que devem existir por Node, como componentes de rede/kube-proxy, começam a aparecer também no Worker.

> Não copiar `admin.conf` para o Worker apenas para executar `kubectl`. A administração global continua a ser feita no Control Plane.

Opcionalmente, depois de confirmar o join:

```bash
sudo kubeadm token list --kubeconfig=/etc/kubernetes/admin.conf
```

### CHECKPOINT CP6

```text
kubelet ativo no Worker
kubelet.conf existe
Control Plane Ready v1.35.8
Worker Ready v1.35.8
Pods de infraestrutura estáveis
```

**Evidência:** guardar `kubectl get nodes -o wide` depois do join.

---

# CP7 — Cordon, drain e uncordon

## Objetivo

Simular uma operação normal de manutenção de um Node e distinguir claramente bloquear scheduling, evacuar workloads e reabrir o Node.

**Executar comandos `kubectl` em:** `k8s-cp-01`.

## O que estamos a fazer neste bloco?

Antes de reiniciar, atualizar ou retirar temporariamente um Worker de serviço, queremos impedir novos agendamentos e retirar de forma controlada os workloads que podem sair desse Node.

```text
Node em serviço
     ↓
cordon
     ↓
Node continua ativo, mas deixa de receber novos Pods
     ↓
drain
     ↓
workloads apropriados são evacuados/removidos de forma controlada
     ↓
manutenção
     ↓
uncordon
     ↓
Node volta a aceitar scheduling
```

Neste exercício usamos deliberadamente um **Pod criado diretamente**, sem Deployment ou ReplicaSet. Isto permite observar a proteção do `drain`: Kubernetes não quer remover silenciosamente um Pod sem controller capaz de o recriar.

Garantir novamente que o manifesto existe:

```bash
REPO_DIR="$HOME/formacao-kubernetes"
MANIFEST_DIR="$REPO_DIR/sessao-04/manifests"

git -C "$REPO_DIR" switch main
git -C "$REPO_DIR" pull --ff-only origin main

test -f "$MANIFEST_DIR/pod_cordon_test.yaml" \
  && echo 'OK: manifesto do Pod de teste disponível'
```

## 7.1. Criar o Pod de teste

```bash
kubectl apply -f "$MANIFEST_DIR/pod_cordon_test.yaml"
kubectl wait --for=condition=Ready pod/cordon-test --timeout=120s
kubectl get pod cordon-test -o wide
```

**O que estamos a fazer:** criamos um Pod direto com `nodeSelector` para o colocar no `k8s-wk-01`.

**O que observar:** na coluna `NODE`, o Pod deve aparecer em `k8s-wk-01`.

## 7.2. `cordon` — impedir novos agendamentos

```bash
kubectl cordon k8s-wk-01
kubectl get nodes
```

`cordon` marca o Worker como **não elegível para novos agendamentos normais**. Não desliga o Node, não para o kubelet e não remove os Pods que já lá estão.

Esperado:

```text
node/k8s-wk-01 cordoned
k8s-wk-01   Ready,SchedulingDisabled
```

`Ready` significa que o Node continua saudável; `SchedulingDisabled` significa que o scheduler deixou de o escolher para novos Pods normais.

## 7.3. `drain` — evacuar workloads antes da manutenção

Primeiro fazemos um drain seletivo, sem `--force`:

```bash
kubectl drain k8s-wk-01 \
  --ignore-daemonsets \
  --pod-selector=app=cordon-test
```

`drain` prepara o Node para manutenção e tenta remover/evacuar de forma controlada os Pods abrangidos.

- `--ignore-daemonsets` reconhece que Pods de DaemonSets não são evacuados desta forma;
- `--pod-selector=app=cordon-test` limita a operação ao Pod de teste.

**Esperado:** o primeiro `drain` deve recusar a remoção porque o Pod foi criado diretamente e não tem controller que o recrie.

Essa recusa é intencional: estamos a observar uma proteção contra perda acidental de um workload não gerido.

Agora, apenas neste exercício controlado:

```bash
kubectl drain k8s-wk-01 \
  --ignore-daemonsets \
  --pod-selector=app=cordon-test \
  --force
```

`--force` permite remover este Pod sem controller. Não deve ser acrescentado automaticamente a qualquer falha de `drain`.

Confirmar:

```bash
kubectl get pod cordon-test
kubectl get nodes
```

Esperado:

```text
Pod cordon-test já não existe
k8s-wk-01 continua Ready,SchedulingDisabled
```

Como não existe Deployment/ReplicaSet, o Pod **não é recriado automaticamente**.

## 7.4. `uncordon` — reabrir o Node ao scheduler

```bash
kubectl uncordon k8s-wk-01
kubectl get nodes
```

Esperado:

```text
node/k8s-wk-01 uncordoned
k8s-wk-01   Ready
```

`uncordon` apenas volta a permitir scheduling. Não recria Pods eliminados.

### CHECKPOINT CP7

O formando deve conseguir explicar:

```text
cordon   = impedir novos agendamentos no Node
drain    = preparar o Node para manutenção e evacuar/remover workloads apropriados
uncordon = voltar a permitir scheduling no Node
```

**Evidência:** guardar o Worker em `SchedulingDisabled`, a recusa do primeiro drain e o estado `Ready` depois do uncordon.

---

# CP8 — Health gate e ponto de recuperação

## Objetivo

Provar que o cluster 1.35.8 está saudável **antes** de iniciar o upgrade. O objetivo é separar problemas pré-existentes de problemas introduzidos pela atualização.

**Executar em:** `k8s-cp-01`, exceto os comandos locais indicados.

## 8.1. Observar o estado global

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl get events -A --sort-by=.lastTimestamp | tail -n 50
```

### O que estamos a verificar

- Nodes `Ready`;
- Pods críticos estáveis;
- CoreDNS e Calico saudáveis;
- ausência de eventos recentes que indiquem churn persistente.

Tabela compacta das condições mais importantes:

```bash
kubectl get nodes \
  -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,DISK:.status.conditions[?(@.type=="DiskPressure")].status,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion'
```

Esperado:

```text
NAME        READY   DISK    KUBELET   RUNTIME
k8s-cp-01   True    False   v1.35.8   containerd://2.2.6
k8s-wk-01   True    False   v1.35.8   containerd://2.2.6
```

## 8.2. Verificar o histórico recente do kubelet no Worker

No Worker:

```bash
sudo journalctl -u kubelet -n 100 --no-pager \
  | grep -Ei 'unable to signal init|permission denied|apparmor.*DENIED' || true
```

Neste comando, **não obter output é um bom resultado**: significa que essas mensagens não foram encontradas nas últimas linhas analisadas.

Se existirem erros recorrentes, não iniciar o upgrade sem os interpretar.

## 8.3. Criar um ponto de recuperação do laboratório

Só depois do health gate estar limpo, criar snapshots coordenados das duas VMs no hipervisor, por exemplo:

```text
S04-CP8-K8s-1.35.8-Healthy-Before-Upgrade
```

Os dois snapshots devem representar o mesmo momento lógico do cluster. No laboratório são um ponto de recuperação pedagógico; não representam uma estratégia completa de backup de produção.

### CHECKPOINT CP8

```text
Nodes Ready
DiskPressure=False
Pods críticos estáveis
Calico core saudável
sem churn persistente
sem erros AppArmor/runc recorrentes
ponto de recuperação criado antes do upgrade
```

**Evidência:** guardar a tabela compacta e `kubectl get tigerastatus`.

---

# CP9 — Upgrade do Control Plane para 1.36.4

## Objetivo

Atualizar primeiro o Control Plane, observar a fase temporária de versões mistas e só depois atualizar o kubelet do próprio Node.

**Executar em:** `k8s-cp-01`, salvo indicação contrária.

## 9.1. Mudar o repositório para Kubernetes 1.36

Estamos a mudar deliberadamente a minor disponível no APT. Não estamos ainda a atualizar todo o cluster.

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
```

Definir a versão validada:

```bash
K8S_136_PKG_VERSION='1.36.4-1.1'
```

## 9.2. Atualizar apenas o kubeadm

O kubeadm é atualizado primeiro porque é ele que conhece e conduz o workflow de upgrade do Control Plane.

Retirar temporariamente o hold e simular a operação:

```bash
sudo apt-mark unhold kubeadm
sudo apt-get -s install kubeadm="$K8S_136_PKG_VERSION"
```

`apt-get -s` **não instala nada**; permite verificar o que o APT pretende alterar.

Se a simulação mostrar apenas a alteração esperada:

```bash
sudo apt-get install -y kubeadm="$K8S_136_PKG_VERSION"
sudo apt-mark hold kubeadm
kubeadm version -o short
```

Esperado:

```text
v1.36.4
```

## 9.3. Analisar antes de aplicar

```bash
sudo kubeadm upgrade plan
```

`upgrade plan` analisa o estado e o caminho de atualização; não altera o cluster. Confirmar que o destino é `1.36.4`.

Aplicar:

```bash
sudo kubeadm upgrade apply v1.36.4
```

Aqui ocorre a alteração efetiva do Control Plane e dos addons geridos pelo kubeadm.

## 9.4. Observar a fase de versões mistas

```bash
kubectl version
kubectl get nodes -o wide
kubectl get pods -A -o wide
```

É normal observar temporariamente:

```text
API Server:       v1.36.4
kubelet CP:       v1.35.8
kubelet Worker:   v1.35.8
```

`kubectl get nodes` mostra a versão do **kubelet**, não a versão do API Server. Esta diferença temporária faz parte do upgrade sequencial.

## 9.5. Atualizar kubelet e kubectl do Control Plane

Antes de alterar o kubelet, colocamos o Node em manutenção:

```bash
kubectl drain k8s-cp-01 --ignore-daemonsets
```

O `drain` impede novos agendamentos e evacua os workloads apropriados. Os static Pods do Control Plane permanecem porque são geridos localmente pelo kubelet.

Retirar hold e simular:

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt-get -s install \
  kubelet="$K8S_136_PKG_VERSION" \
  kubectl="$K8S_136_PKG_VERSION"
```

Se a simulação estiver correta:

```bash
sudo apt-get install -y \
  kubelet="$K8S_136_PKG_VERSION" \
  kubectl="$K8S_136_PKG_VERSION"

sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

`daemon-reload` faz o systemd reler as units instaladas/alteradas antes do restart.

Observar:

```bash
kubectl get nodes -o wide
```

Pode existir um período curto de `NotReady,SchedulingDisabled`. Aguardar a convergência para:

```text
Ready,SchedulingDisabled
```

Só depois reabrir o Node:

```bash
kubectl uncordon k8s-cp-01
kubectl get nodes -o wide
```

### CHECKPOINT CP9

Esperado:

```text
Control Plane Ready v1.36.4
Worker        Ready v1.35.8
```

**Evidência:** guardar `kubectl version` e `kubectl get nodes -o wide` nesta fase mista.

---

# CP10 — Upgrade do Worker para 1.36.4

## Objetivo

Atualizar o Worker depois do Control Plane, primeiro preparando a configuração local com kubeadm e só depois alterando o kubelet em modo de manutenção.

## 10.1. Configurar o repositório 1.36 no Worker

**Executar em:** `k8s-wk-01`.

Não assumir que o Worker herdou a configuração APT do Control Plane. Configuramos explicitamente o repositório:

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update

K8S_136_PKG_VERSION='1.36.4-1.1'
```

## 10.2. Atualizar kubeadm e configuração local do Worker

Retirar o hold e simular:

```bash
sudo apt-mark unhold kubeadm
sudo apt-get -s install kubeadm="$K8S_136_PKG_VERSION"
```

Se a simulação estiver correta:

```bash
sudo apt-get install -y kubeadm="$K8S_136_PKG_VERSION"
sudo apt-mark hold kubeadm

kubeadm version -o short
sudo kubeadm upgrade node
```

`kubeadm upgrade node` atualiza a configuração local necessária para este Node. **Não atualiza o package kubelet.** Por isso é normal ficar temporariamente:

```text
kubeadm v1.36.4
kubelet v1.35.8
```

## 10.3. Preparar o Tigera Operator antes do drain integral

**Executar em:** `k8s-cp-01`.

Primeiro observar onde está o Operator:

```bash
kubectl get pod -n tigera-operator -o wide
```

Se o Pod do Tigera Operator estiver no Worker, fixá-lo temporariamente no Control Plane durante a manutenção:

```bash
kubectl patch deployment tigera-operator \
  -n tigera-operator \
  --type='merge' \
  -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/hostname":"k8s-cp-01"}}}}}'

kubectl rollout status deployment/tigera-operator \
  -n tigera-operator --timeout=120s

kubectl get pod -n tigera-operator -o wide
```

### O que estamos a fazer

Nesta topologia pedagógica só temos dois Nodes. Queremos evitar que o Operator seja um workload adicional a bloquear/complicar a manutenção do Worker. Esta é uma decisão específica deste laboratório, não uma regra universal de Kubernetes.

Se o Operator já estiver no Control Plane, este patch pode ser dispensado.

## 10.4. Drenar integralmente o Worker

**Executar em:** `k8s-cp-01`.

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets
```

### O que observar

Esperado:

```text
k8s-wk-01   Ready,SchedulingDisabled
```

No Worker devem permanecer essencialmente Pods de DaemonSets como `calico-node`, `csi-node-driver` e `kube-proxy`. Isso não significa que o drain falhou; esses Pods seguem um modelo diferente dos workloads normais.

## 10.5. Atualizar kubelet e kubectl no Worker

**Executar em:** `k8s-wk-01`.

Retirar hold e simular:

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt-get -s install \
  kubelet="$K8S_136_PKG_VERSION" \
  kubectl="$K8S_136_PKG_VERSION"
```

Se a simulação mostrar apenas as alterações esperadas:

```bash
sudo apt-get install -y \
  kubelet="$K8S_136_PKG_VERSION" \
  kubectl="$K8S_136_PKG_VERSION"

sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

Validar localmente:

```bash
sudo systemctl is-active kubelet
sudo systemctl is-active containerd
kubeadm version -o short
kubelet --version
kubectl version --client
```

No Control Plane:

```bash
kubectl get nodes -o wide
```

Esperado antes do uncordon:

```text
k8s-cp-01   Ready                      v1.36.4
k8s-wk-01   Ready,SchedulingDisabled   v1.36.4
```

Quando o Worker estiver `Ready`, voltar a permitir scheduling:

```bash
kubectl uncordon k8s-wk-01
```

## 10.6. Repor o Tigera Operator

Apenas se o `nodeSelector` temporário tiver sido aplicado no passo 10.3, removê-lo:

```bash
kubectl patch deployment tigera-operator \
  -n tigera-operator \
  --type='json' \
  -p='[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]'

kubectl rollout status deployment/tigera-operator \
  -n tigera-operator --timeout=120s
```

Confirmar:

```bash
kubectl get pod -n tigera-operator -o wide
```

### CHECKPOINT CP10

```text
Control Plane Ready v1.36.4
Worker Ready v1.36.4
kubelet e containerd ativos no Worker
Tigera Operator Running
Worker novamente schedulable
```

**Evidência:** guardar `kubectl get nodes -o wide` com ambos os Nodes em `v1.36.4`.

---

# CP11 — Health gate final

## Objetivo

Demonstrar que o cluster não só foi atualizado, mas também voltou a um estado operacional saudável e coerente.

**Executar em:** `k8s-cp-01`, salvo indicação contrária.

## 11.1. Validar Nodes, versões e runtime

```bash
kubectl get nodes \
  -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,DISK:.status.conditions[?(@.type=="DiskPressure")].status,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion'
```

Esperado:

```text
NAME        READY   DISK    KUBELET   RUNTIME
k8s-cp-01   True    False   v1.36.4   containerd://2.2.6
k8s-wk-01   True    False   v1.36.4   containerd://2.2.6
```

Aqui verificamos simultaneamente disponibilidade, pressão de disco, versão do kubelet e runtime reportado pelo Node.

## 11.2. Validar workloads e networking

```bash
kubectl get pods -A -o wide
kubectl get tigerastatus
```

Queremos Pods ativos `Running/Ready` e o core Calico saudável.

Filtrar Pods que não estejam nem `Running` nem `Succeeded`:

```bash
kubectl get pods -A \
  --field-selector=status.phase!=Running,status.phase!=Succeeded
```

Esperado:

```text
No resources found
```

> Este filtro não substitui a leitura da coluna `READY`. Um Pod pode estar `Running` e ainda não estar `Ready`.

## 11.3. Confirmar versões cliente/servidor

```bash
kubectl version
```

Esperado:

```text
Client Version: v1.36.4
Server Version: v1.36.4
```

## 11.4. Rever o problema antigo AppArmor/runc

No Worker:

```bash
sudo journalctl -k --since "-10 min" --no-pager \
  | grep -Ei 'apparmor="DENIED"|unable to signal init|permission denied' \
  || true
```

Não obter output para estes padrões é o resultado desejado.

Warnings isolados de arranque como:

```text
checkpoint is not found
no imagefs label for configured runtime
```

devem ser avaliados pela **recorrência e impacto**. No ensaio validado foram transitórios e o Node convergiu para `Ready=True` e `DiskPressure=False`.

Uma linha isolada no log não deve ser tratada automaticamente como falha persistente.

### CHECKPOINT CP11 — conclusão

```text
UPGRADE COMPLETO
Kubernetes 1.35.8 → 1.36.4
Control Plane Ready
Worker Ready
DiskPressure=False
containerd 2.2.6
Calico core saudável
sem Pods anómalos persistentes
Client e Server v1.36.4
sem recorrência do problema AppArmor/runc observado no ensaio anterior
```

**Evidência:** guardar a tabela final dos Nodes, `kubectl get tigerastatus`, filtro de Pods anómalos e `kubectl version`.

---

# Evidências mínimas a guardar

Durante a sessão, registar na [`../folha_evidencias.md`](../folha_evidencias.md):

1. baseline Linux/runtime depois de CP1 e CP2;
2. versões iniciais Kubernetes `1.35.8`;
3. Control Plane criado e Calico/CoreDNS saudáveis;
4. `kubectl get nodes -o wide` após o join do Worker;
5. evidência de `cordon` / `drain` / `uncordon`;
6. health gate antes do upgrade;
7. fase mista depois de atualizar o Control Plane;
8. ambos os Nodes em `v1.36.4`;
9. health gate final completo.

Para conceitos, flags e troubleshooting mais detalhado, consultar:

- [`../manual_formando.md`](../manual_formando.md)
- [`../cheat_sheet.md`](../cheat_sheet.md)
- [`../troubleshooting.md`](../troubleshooting.md)
- [`../compatibilidade.md`](../compatibilidade.md)
