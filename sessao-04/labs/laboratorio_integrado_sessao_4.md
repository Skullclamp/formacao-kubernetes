# Laboratório Integrado — Sessão 4
## Kubernetes Admin I: instalar, operar e atualizar o cluster

**Sessão:** 4 de 10  
**Duração:** 4 horas / 240 minutos  
**Nível:** intermédio  
**Topologia:** `k8s-cp-01` + `k8s-wk-01`

Este documento é o **único laboratório da Sessão 4**. As explicações conceptuais detalhadas estão em [`../manual_formando.md`](../manual_formando.md); aqui fica apenas o percurso prático, os outputs essenciais e os checkpoints que determinam se é seguro avançar.

```text
OBJETIVO DO BLOCO
      ↓
ONDE EXECUTAR
      ↓
COMANDOS
      ↓
OUTPUT / ESTADO ESPERADO
      ↓
CHECKPOINT
      ↓
EVIDÊNCIA A REGISTAR
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
runc:                1.3.6
Calico:              3.32.2
Tigera Operator:     1.42.6
Pod CIDR:            10.244.0.0/16
Service CIDR:        10.96.0.0/12
Filesystem /:        40 GB no ambiente validado
```

A rede física é `192.168.50.0/24`; por isso usamos `10.244.0.0/16` para Pods, evitando sobreposição.

---

# CP1 — Preparar as duas VMs

**Executar em:** `k8s-cp-01` e `k8s-wk-01`.

## 1.1. Confirmar identidade e recursos

```bash
hostname
ip -br address
free -h
swapon --show
lsblk -f
df -h /
stat -fc %T /sys/fs/cgroup
```

**Esperado:** hostname correto, swap vazia, `cgroup2fs` e espaço suficiente em `/`.

Se o disco virtual tiver espaço mas o filesystem `/` continuar pequeno, parar e confirmar o layout LVM antes de qualquer expansão:

```bash
sudo pvs
sudo vgs
sudo lvs
```

## 1.2. Módulos e sysctl

```bash
sudo swapoff -a

cat <<'EOF' | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

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

## 1.3. Resolução entre nós

Confirmar `/etc/hosts` nos dois nós:

```text
192.168.50.46  k8s-cp-01
192.168.50.65  k8s-wk-01
```

```bash
getent hosts k8s-cp-01
getent hosts k8s-wk-01
ping -c 2 k8s-cp-01
ping -c 2 k8s-wk-01
```

### CHECKPOINT CP1

```text
hostname correto
swap desativada
cgroup v2
módulos carregados
ip_forward = 1
bridge-nf-call-iptables = 1
resolução entre os dois nós
filesystem / sem pressão de espaço
```

---

# CP2 — Instalar e validar containerd 2.2.6

**Executar em:** ambos os nós.

## 2.1. Repositório Docker

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

Selecionar a versão validada:

```bash
CONTAINERD_PKG_VERSION="$(
  apt-cache madison containerd.io |
  awk '$3 ~ /^2\.2\.6/ {print $3; exit}'
)"

test -n "$CONTAINERD_PKG_VERSION"
printf 'containerd.io: %s\n' "$CONTAINERD_PKG_VERSION"

sudo apt-get install -y containerd.io="$CONTAINERD_PKG_VERSION"
sudo apt-mark hold containerd.io
```

## 2.2. Configuração

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo nano /etc/containerd/config.toml
```

Confirmar no ficheiro:

```text
CRI não está em disabled_plugins
SystemdCgroup = true
```

Depois:

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd

containerd --version
runc --version
sudo systemctl is-active containerd
sudo ctr plugins ls | grep -i cri
containerd config dump | grep -i -A5 -B5 SystemdCgroup
```

### CHECKPOINT CP2

```text
containerd 2.2.6
runc 1.3.6
containerd.service = active
CRI disponível
SystemdCgroup = true
```

---

# CP3 — Instalar Kubernetes 1.35.8

**Executar em:** ambos os nós.

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

Fixar a versão:

```bash
K8S_PKG_VERSION='1.35.8-1.1'

apt-cache madison kubeadm | grep -F "$K8S_PKG_VERSION"

sudo apt-get install -y \
  kubelet="$K8S_PKG_VERSION" \
  kubeadm="$K8S_PKG_VERSION" \
  kubectl="$K8S_PKG_VERSION"

sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
```

Validar:

```bash
kubeadm version -o short
kubelet --version
kubectl version --client
apt-mark showhold
```

### CHECKPOINT CP3

Esperado nos dois nós:

```text
kubeadm  v1.35.8
kubelet  v1.35.8
kubectl  v1.35.8
containerd.io, kubeadm, kubelet e kubectl em hold
```

**Não avançar se surgir outra minor.**

---

# CP4 — Inicializar o Control Plane

**Executar apenas em:** `k8s-cp-01`.

```bash
hostname
```

```bash
sudo kubeadm init \
  --kubernetes-version=v1.35.8 \
  --apiserver-advertise-address=192.168.50.46 \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///run/containerd/containerd.sock
```

Configurar o kubeconfig:

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

**Esperado nesta fase:** o Control Plane pode estar `NotReady` e CoreDNS pode ainda não estar pronto porque o CNI ainda não foi instalado.

### CHECKPOINT CP4

```text
API Server acessível
kubeconfig funcional
Control Plane criado em 1.35.8
Pod CIDR = 10.244.0.0/16
```

---

# CP5 — Instalar Calico 3.32.2

**Executar em:** `k8s-cp-01`.

```bash
export CALICO_VERSION=v3.32.2

kubectl create -f \
  https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/v1_crd_projectcalico_org.yaml

kubectl create -f \
  https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml
```

Descarregar o manifesto da formação diretamente do GitHub para uma localização conhecida:

```bash
LAB_ROOT="$HOME/formacao-kubernetes/sessao-04"
MANIFEST_DIR="$LAB_ROOT/manifests"

mkdir -p "$MANIFEST_DIR"

curl -fsSL \
  https://raw.githubusercontent.com/Skullclamp/formacao-kubernetes/main/sessao-04/manifests/calico_installation_sessao4.yaml \
  -o "$MANIFEST_DIR/calico_installation_sessao4.yaml"
```

Confirmar que o ficheiro existe e validar o CIDR antes de aplicar:

```bash
ls -l "$MANIFEST_DIR/calico_installation_sessao4.yaml"
grep -n 'cidr:' "$MANIFEST_DIR/calico_installation_sessao4.yaml"
```

Esperado:

```text
cidr: 10.244.0.0/16
```

Aplicar:

```bash
kubectl create -f "$MANIFEST_DIR/calico_installation_sessao4.yaml"
```

Acompanhar:

```bash
kubectl get pods -n tigera-operator -o wide
kubectl get pods -n calico-system -o wide
kubectl get tigerastatus
kubectl get nodes -o wide
```

### CHECKPOINT CP5

```text
calico   Available=True  Progressing=False  Degraded=False
Node do Control Plane Ready
CoreDNS Running/Ready
```

Na instalação mínima da sessão, `tiers` pode indicar `Waiting for Tigera API server`; o critério do core networking é o estado de `calico` e `ippools`.

---

# CP6 — Integrar o Worker

## 6.1. Gerar o join

**Executar em:** `k8s-cp-01`.

```bash
sudo kubeadm token create --print-join-command \
  --kubeconfig=/etc/kubernetes/admin.conf
```

Copiar o comando real devolvido.

## 6.2. Executar o join

**Executar em:** `k8s-wk-01`.

```text
sudo kubeadm join 192.168.50.46:6443 \
  --token TOKEN_REAL \
  --discovery-token-ca-cert-hash sha256:HASH_REAL \
  --cri-socket=unix:///run/containerd/containerd.sock
```

Não executar `TOKEN_REAL` ou `HASH_REAL` literalmente.

No Worker:

```bash
sudo systemctl is-active kubelet
sudo ls -l /etc/kubernetes/kubelet.conf
```

No Control Plane:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
```

### CHECKPOINT CP6

```text
k8s-cp-01   Ready   ... v1.35.8
k8s-wk-01   Ready   ... v1.35.8
```

Opcionalmente, depois de confirmar o join, listar e remover o bootstrap token se já não for necessário:

```bash
sudo kubeadm token list --kubeconfig=/etc/kubernetes/admin.conf
```

---

# CP7 — Cordon, drain e uncordon

**Executar comandos `kubectl` em:** `k8s-cp-01`.

Descarregar o manifesto do Pod de teste diretamente do GitHub:

```bash
LAB_ROOT="$HOME/formacao-kubernetes/sessao-04"
MANIFEST_DIR="$LAB_ROOT/manifests"

mkdir -p "$MANIFEST_DIR"

curl -fsSL \
  https://raw.githubusercontent.com/Skullclamp/formacao-kubernetes/main/sessao-04/manifests/pod_cordon_test.yaml \
  -o "$MANIFEST_DIR/pod_cordon_test.yaml"

ls -l "$MANIFEST_DIR/pod_cordon_test.yaml"
```

Criar o Pod de teste:

```bash
kubectl apply -f "$MANIFEST_DIR/pod_cordon_test.yaml"
kubectl wait --for=condition=Ready pod/cordon-test --timeout=120s
kubectl get pod cordon-test -o wide
```

Confirmar que está no Worker.

Cordon:

```bash
kubectl cordon k8s-wk-01
kubectl get nodes
```

Primeiro drain seletivo, sem `--force`:

```bash
kubectl drain k8s-wk-01 \
  --ignore-daemonsets \
  --pod-selector=app=cordon-test
```

**Esperado:** recusa de remoção do Pod direto sem controller.

Agora, apenas para este exercício controlado:

```bash
kubectl drain k8s-wk-01 \
  --ignore-daemonsets \
  --pod-selector=app=cordon-test \
  --force
```

Depois:

```bash
kubectl get pod cordon-test
kubectl uncordon k8s-wk-01
kubectl get nodes
```

### CHECKPOINT CP7

```text
cordon observado
recusa sem --force compreendida
Pod de teste removido de forma controlada
Worker novamente Ready e schedulable
```

---

# CP8 — Health gate e ponto de recuperação

**Executar em:** Control Plane, exceto os comandos locais indicados.

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl get events -A --sort-by=.lastTimestamp | tail -n 50
```

Tabela compacta:

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

No Worker:

```bash
sudo journalctl -u kubelet -n 100 --no-pager \
  | grep -Ei 'unable to signal init|permission denied|apparmor.*DENIED' || true
```

### CHECKPOINT CP8

Só avançar se:

```text
Nodes Ready
DiskPressure=False
Pods críticos estáveis
Calico core saudável
sem churn persistente
sem AppArmor/runc errors recorrentes
```

Criar snapshots coordenados das duas VMs, por exemplo:

```text
S04-CP8-K8s-1.35.8-Healthy-Before-Upgrade
```

---

# CP9 — Upgrade do Control Plane para 1.36.4

**Executar em:** `k8s-cp-01`.

## 9.1. Repositório 1.36 e kubeadm

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
```

```bash
K8S_136_PKG_VERSION='1.36.4-1.1'

sudo apt-mark unhold kubeadm
sudo apt-get -s install kubeadm="$K8S_136_PKG_VERSION"
```

Se a simulação mostrar apenas o upgrade esperado:

```bash
sudo apt-get install -y kubeadm="$K8S_136_PKG_VERSION"
sudo apt-mark hold kubeadm

kubeadm version -o short
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.36.4
```

Validar antes de atualizar o kubelet:

```bash
kubectl version
kubectl get nodes -o wide
kubectl get pods -A -o wide
```

É normal o API Server já estar em `1.36.4` enquanto o kubelet do Node ainda aparece em `1.35.8`.

## 9.2. Kubelet e kubectl do Control Plane

```bash
kubectl drain k8s-cp-01 --ignore-daemonsets
```

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

Aguardar o Node regressar a `Ready,SchedulingDisabled` e depois:

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

Esta diferença temporária faz parte do upgrade sequencial.

---

# CP10 — Upgrade do Worker para 1.36.4

## 10.1. Atualizar kubeadm e configuração local

**Executar em:** `k8s-wk-01`.

Configurar o repositório Kubernetes v1.36 tal como no CP9 e depois:

```bash
K8S_136_PKG_VERSION='1.36.4-1.1'

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

Neste momento é normal:

```text
kubeadm v1.36.4
kubelet v1.35.8
```

## 10.2. Preparar o Tigera Operator

**Executar em:** `k8s-cp-01`.

Se o Tigera Operator estiver no Worker, fixá-lo temporariamente no Control Plane durante a manutenção:

```bash
kubectl patch deployment tigera-operator \
  -n tigera-operator \
  --type='merge' \
  -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/hostname":"k8s-cp-01"}}}}}'

kubectl rollout status deployment/tigera-operator \
  -n tigera-operator --timeout=120s

kubectl get pod -n tigera-operator -o wide
```

## 10.3. Drain integral do Worker

**Executar em:** `k8s-cp-01`.

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets
```

Esperado:

```text
k8s-wk-01   Ready,SchedulingDisabled
```

No Worker devem permanecer essencialmente DaemonSets como `calico-node`, `csi-node-driver` e `kube-proxy`.

## 10.4. Atualizar kubelet e kubectl

**Executar em:** `k8s-wk-01`.

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

Reabrir o Worker:

```bash
kubectl uncordon k8s-wk-01
```

Remover o `nodeSelector` temporário:

```bash
kubectl patch deployment tigera-operator \
  -n tigera-operator \
  --type='json' \
  -p='[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]'

kubectl rollout status deployment/tigera-operator \
  -n tigera-operator --timeout=120s
```

### CHECKPOINT CP10

```text
Control Plane Ready v1.36.4
Worker        Ready v1.36.4
Tigera Operator Running
```

---

# CP11 — Health gate final

**Executar em:** `k8s-cp-01`.

```bash
kubectl get nodes \
  -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,DISK:.status.conditions[?(@.type=="DiskPressure")].status,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion'

kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl get pods -A \
  --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl version
```

Resultado esperado:

```text
NAME        READY   DISK    KUBELET   RUNTIME
k8s-cp-01   True    False   v1.36.4   containerd://2.2.6
k8s-wk-01   True    False   v1.36.4   containerd://2.2.6
```

```text
Client Version: v1.36.4
Server Version: v1.36.4
```

O filtro de Pods anómalos deve devolver:

```text
No resources found
```

No Worker, confirmar ausência do problema antigo AppArmor/runc:

```bash
sudo journalctl -k --since "-10 min" --no-pager \
  | grep -Ei 'apparmor="DENIED"|unable to signal init|permission denied' \
  || true
```

Warnings de arranque como `checkpoint is not found` ou `no imagefs label for configured runtime` devem ser avaliados pela recorrência e pelo impacto; no ensaio validado foram transitórios e o Node convergiu para `Ready=True` e `DiskPressure=False`.

### CHECKPOINT CP11 — conclusão

```text
UPGRADE COMPLETO
Kubernetes 1.35.8 → 1.36.4
Control Plane Ready
Worker Ready
containerd 2.2.6
DiskPressure=False
Calico core saudável
sem Pods anómalos persistentes
```

---

# Evidências mínimas a guardar

Durante a sessão, registar na [`../folha_evidencias.md`](../folha_evidencias.md):

1. versões iniciais de Kubernetes e runtime;
2. `kubectl get nodes -o wide` após o join;
3. estado de Calico/CoreDNS;
4. evidência do exercício `cordon`/`drain`/`uncordon`;
5. health gate antes do upgrade;
6. versão mista após atualizar o Control Plane;
7. health gate final com ambos os Nodes em `v1.36.4`.

Para conceitos, flags e troubleshooting detalhado, consultar:

- [`../manual_formando.md`](../manual_formando.md)
- [`../cheat_sheet.md`](../cheat_sheet.md)
- [`../troubleshooting.md`](../troubleshooting.md)
- [`../compatibilidade.md`](../compatibilidade.md)