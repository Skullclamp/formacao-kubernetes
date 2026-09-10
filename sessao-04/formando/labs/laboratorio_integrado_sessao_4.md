# Laboratório Integrado — Sessão 4
## Kubernetes Admin I: da VM Ubuntu limpa ao cluster 1.36.4 atualizado

**Sessão:** 4  
**Duração da sessão:** 4 horas / 240 minutos  
**Nível:** intermédio  
**Topologia:** `k8s-cp-01` + `k8s-wk-01`  
**Cenário:** cluster Kubernetes on-premises com `kubeadm`, `containerd` e Calico

Este laboratório acompanha uma única história técnica. O objetivo não é copiar comandos: é compreender, executar manualmente, observar, registar evidência e explicar o que aconteceu.

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

> **Baseline validada em laboratório:** o percurso descrito neste documento foi executado de ponta a ponta com sucesso em duas VMs Ubuntu 26.04.1 LTS, partindo de Kubernetes 1.35.8 e terminando em Kubernetes 1.36.4.

> **Outputs esperados:** IDs de Pods, timestamps, endereços de Pod e tempos de execução variam entre ambientes. Os exemplos mostram apenas os estados relevantes a observar.

---

# 0. Baseline e percurso

## 0.1. Baseline técnica validada

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
Filesystem /:            40 GB no laboratório validado
```

A escolha do Pod CIDR `10.244.0.0/16` é intencional. A rede física do laboratório é `192.168.50.0/24`; usar `192.168.0.0/16` para Pods criaria sobreposição com a rede dos hosts.

## 0.2. Percurso

```text
VMs Ubuntu preparadas
      ↓
Linux / módulos / sysctl / disco
      ↓
containerd 2.2.6 + runc 1.3.6
      ↓
Kubernetes 1.35.8
      ↓
kubeadm init no Control Plane
      ↓
Calico 3.32.2
      ↓
kubeadm join do Worker
      ↓
cluster 1.35.8 saudável
      ↓
cordon / drain seletivo / uncordon
      ↓
health gate + snapshot coordenado
      ↓
kubeadm upgrade apply 1.36.4
      ↓
kubelet/kubectl do Control Plane
      ↓
kubeadm upgrade node no Worker
      ↓
drain integral do Worker
      ↓
kubelet/kubectl do Worker
      ↓
cluster 1.36.4 saudável
```

## 0.3. Onde executar cada tipo de comando

| Operação | Nó |
|---|---|
| `kubeadm init` | Control Plane |
| `kubeadm token create` | Control Plane |
| `kubectl ...` administrativo | Control Plane |
| `kubeadm join` | Worker |
| `kubeadm upgrade apply` | Control Plane |
| `kubeadm upgrade node` | Worker |
| `systemctl` / `journalctl` | nó que está a ser diagnosticado |

O Worker **não recebe** `/etc/kubernetes/admin.conf` para uso administrativo. Se `kubectl` for executado no Worker sem kubeconfig, é normal surgir uma tentativa de ligação a `localhost:8080` e a operação falhar.

---

# CP1 — Preparar e validar as duas VMs

Executar nos **dois nós**.

## 1.1. Identidade, memória, swap, disco e cgroups

```bash
hostname
ip -br address
free -h
swapon --show
lsblk -f
df -h /
stat -fc %T /sys/fs/cgroup
```

Esperado no laboratório:

```text
Control Plane → k8s-cp-01
Worker        → k8s-wk-01
cgroups       → cgroup2fs
swap          → vazio
```

O tamanho do disco virtual **não basta**. Confirmar sempre o tamanho útil do filesystem `/`.

No ambiente validado, a VM tinha um disco virtual de 48 GB, mas o LV raiz tinha apenas cerca de 10 GB. Isso originou `DiskPressure` durante a instalação do Calico.

## 1.2. Se o root filesystem estiver subdimensionado

Executar **apenas se a topologia de disco corresponder** a `/dev/sda3` + `ubuntu-vg/ubuntu-lv`.

Primeiro observar:

```bash
lsblk
sudo pvs
sudo vgs
sudo lvs
```

Se existir espaço não particionado no disco e o layout corresponder ao laboratório:

```bash
sudo apt-get update
sudo apt-get install -y cloud-guest-utils

sudo growpart -N /dev/sda 3
sudo growpart /dev/sda 3
sudo pvresize /dev/sda3
sudo lvextend -r -L 40G /dev/ubuntu-vg/ubuntu-lv

df -h /
```

> Não executar `resize2fs` diretamente sobre `/dev/sda3`: nesse layout, `/dev/sda3` é um PV LVM, não o filesystem raiz.

## 1.3. Swap, módulos e sysctl

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
swapon --show
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
```

## 1.4. Resolução entre nós

No laboratório validado:

```text
192.168.50.46  k8s-cp-01
192.168.50.65  k8s-wk-01
```

Confirmar nos dois nós:

```bash
getent hosts k8s-cp-01
getent hosts k8s-wk-01
ping -c 2 k8s-cp-01
ping -c 2 k8s-wk-01
```

## 1.5. Confirmar ausência de Kubernetes residual

```bash
sudo ss -ltnp | grep -E ':(6443|2379|2380|10250|10257|10259)\b' || true

dpkg-query -W -f='${Package} ${Version}\n' \
  kubeadm kubelet kubectl 2>/dev/null || true

grep -R 'pkgs.k8s.io/core:/stable:' \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true
```

Se existir um cluster anterior, não improvisar um downgrade. Restaurar uma VM/snapshot limpo e repetir o laboratório.

---

# CP2 — Instalar e validar containerd 2.2.6

Executar nos **dois nós**.

## 2.1. Repositório Docker

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL \
  https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt-get update
apt-cache madison containerd.io
```

## 2.2. Instalar a versão validada

```bash
CONTAINERD_PKG_VERSION="$(
  apt-cache madison containerd.io |
  awk '$3 ~ /^2\.2\.6/ {print $3; exit}'
)"

printf 'containerd.io selecionado: %s\n' "$CONTAINERD_PKG_VERSION"
test -n "$CONTAINERD_PKG_VERSION"

sudo apt-get install -y \
  containerd.io="$CONTAINERD_PKG_VERSION"

sudo apt-mark hold containerd.io
```

No ambiente validado, o package foi:

```text
containerd.io 2.2.6-1~ubuntu.26.04~resolute
```

O package `containerd.io` fornece o seu próprio `runc`. A combinação validada foi:

```text
containerd 2.2.6
runc 1.3.6
```

## 2.3. Configurar CRI e SystemdCgroup

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

grep -n 'disabled_plugins\|SystemdCgroup' /etc/containerd/config.toml
```

Garantir que CRI não está desativado e ativar `SystemdCgroup`:

```bash
sudo sed -i \
  's/SystemdCgroup = false/SystemdCgroup = true/' \
  /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd
```

Validar:

```bash
containerd --version
runc --version
sudo systemctl is-active containerd
containerd config dump | grep -i -A5 -B5 SystemdCgroup
sudo ctr plugins ls | grep -Ei 'cri|io.containerd.cri.v1'
dpkg -S "$(command -v containerd)" "$(command -v runc)"
apt-mark showhold | grep '^containerd.io$'
```

Modelo mental:

```text
kubelet → CRI → containerd → runc → kernel
```

---

# CP3 — Instalar Kubernetes 1.35.8

Executar nos **dois nós**.

## 3.1. Repositório Kubernetes 1.35

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL \
  https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
  | sudo gpg --dearmor --yes \
      -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo \
  'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
apt-cache madison kubeadm
```

## 3.2. Fixar exatamente 1.35.8

```bash
K8S_PKG_VERSION='1.35.8-1.1'

apt-cache madison kubeadm \
  | grep -F "$K8S_PKG_VERSION"

sudo apt-get install -y \
  kubelet="$K8S_PKG_VERSION" \
  kubeadm="$K8S_PKG_VERSION" \
  kubectl="$K8S_PKG_VERSION"

sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable kubelet
```

Validar:

```bash
kubeadm version -o short
kubelet --version
kubectl version --client
apt-mark showhold \
  | grep -E '^(containerd.io|kubeadm|kubelet|kubectl)$'
```

Esperado:

```text
kubeadm  v1.35.8
kubelet  v1.35.8
kubectl  v1.35.8
```

O kubelet pode não ficar funcional antes do `kubeadm init`/`join`; isso não é, por si só, falha nesta fase.

---

# CP4 — Inicializar o Control Plane

Executar **apenas em `k8s-cp-01`**.

## 4.1. Gate de rede

```bash
hostname
ip route get 10.244.0.1
ip route get 10.96.0.1
```

Os CIDRs de Pods e Services não devem sobrepor-se às redes dos hosts.

## 4.2. Inicializar

```bash
sudo kubeadm init \
  --kubernetes-version=v1.35.8 \
  --apiserver-advertise-address=192.168.50.46 \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///run/containerd/containerd.sock
```

Configurar o kubeconfig administrativo:

```bash
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"
```

Validar:

```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -n kube-system -o wide
```

Antes do CNI é normal o Control Plane surgir temporariamente como `NotReady` e CoreDNS ficar `Pending`.

---

# CP5 — Instalar Calico 3.32.2

Executar no **Control Plane**.

Posiciona-te na diretoria `sessao-04` do clone do repositório.

## 5.1. Instalar o Tigera Operator

```bash
export CALICO_VERSION=v3.32.2

kubectl create -f \
  https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/v1_crd_projectcalico_org.yaml

kubectl create -f \
  https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml
```

Validar a imagem do Operator:

```bash
kubectl -n tigera-operator get deploy tigera-operator \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Esperado nesta baseline:

```text
quay.io/tigera/operator:v1.42.6
```

## 5.2. Aplicar apenas o networking necessário

O laboratório não instala os recursos opcionais `APIServer`, `Goldmane` e `Whisker`.

```bash
cat manifests/calico_installation_sessao4.yaml
grep -n 'cidr:' manifests/calico_installation_sessao4.yaml
kubectl create -f manifests/calico_installation_sessao4.yaml
```

Esperado:

```text
cidr: 10.244.0.0/16
```

Validar:

```bash
kubectl get nodes -o wide
kubectl get pods -n calico-system -o wide
kubectl get pods -n tigera-operator -o wide
kubectl get tigerastatus
```

Critério principal da sessão:

```text
calico   AVAILABLE=True   PROGRESSING=False   DEGRADED=False
```

É possível `tiers` surgir como `DEGRADED=True` com a mensagem `Waiting for Tigera API server to be ready`, porque o recurso separado `APIServer` foi deliberadamente omitido. Isso não invalida o CNI/core networking deste laboratório.

## 5.3. Se aparecer DiskPressure

Se surgirem muitos Pods `Evicted`, parar e observar:

```bash
kubectl describe node k8s-cp-01
kubectl get events -A --sort-by=.lastTimestamp | tail -n 100
df -h /
lsblk
sudo pvs
sudo vgs
sudo lvs
```

No incidente validado, a causa foi o filesystem `/` com cerca de 10 GB e não uma falha do Calico. Só avançar depois de `DiskPressure=False` e do Operator estabilizar.

---

# CP6 — Integrar o Worker

## 6.1. Gerar o join no Control Plane

No **`k8s-cp-01`**:

```bash
hostname
sudo ls -l /etc/kubernetes/admin.conf

sudo kubeadm token create \
  --print-join-command \
  --kubeconfig=/etc/kubernetes/admin.conf
```

Não colocar o token real em capturas, relatórios ou commits.

## 6.2. Executar o join no Worker

No **`k8s-wk-01`**, copiar o comando real gerado e executá-lo com `sudo`, acrescentando:

```text
--cri-socket=unix:///run/containerd/containerd.sock
```

Estrutura do comando, apenas para leitura:

```text
sudo kubeadm join 192.168.50.46:6443 --token TOKEN_REAL --discovery-token-ca-cert-hash sha256:HASH_REAL --cri-socket=unix:///run/containerd/containerd.sock
```

Não escrever placeholders com `< >` no shell.

## 6.3. Validar localmente o Worker

```bash
sudo systemctl is-active kubelet
sudo systemctl is-active containerd
sudo ls -l /etc/kubernetes/kubelet.conf
```

Não usar `kubectl get nodes` no Worker como validação administrativa.

## 6.4. Validar no Control Plane

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
```

Esperado:

```text
k8s-cp-01   Ready   ...   v1.35.8
k8s-wk-01   Ready   ...   v1.35.8
```

Confirmar também:

```bash
kubectl get nodes \
  -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,DISK:.status.conditions[?(@.type=="DiskPressure")].status,VERSION:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion'
```

## 6.5. Revogar o bootstrap token depois do join

No Control Plane:

```bash
sudo kubeadm token list
```

Depois de identificar o token usado, eliminá-lo:

```text
sudo kubeadm token delete TOKEN_ID_REAL
```

Um novo Worker pode receber um novo token quando necessário.

---

# CP7 — Scheduling, cordon e drain seletivo

Executar os comandos `kubectl` no **Control Plane**.

## 7.1. Criar um Pod no Worker

```bash
kubectl apply -f manifests/pod_cordon_test.yaml
kubectl wait \
  --for=condition=Ready \
  pod/cordon-test \
  --timeout=120s

kubectl get pod cordon-test -o wide
```

Confirmar `NODE=k8s-wk-01`.

## 7.2. Cordon

```bash
kubectl cordon k8s-wk-01
kubectl get nodes
```

Esperado:

```text
k8s-wk-01   Ready,SchedulingDisabled
```

## 7.3. Drain seletivo sem force

```bash
kubectl drain k8s-wk-01 \
  --ignore-daemonsets \
  --pod-selector=app=cordon-test
```

É esperado que o comando recuse eliminar um Pod direto sem controller.

## 7.4. Drain seletivo com force consciente

```bash
kubectl drain k8s-wk-01 \
  --ignore-daemonsets \
  --pod-selector=app=cordon-test \
  --force
```

Validar:

```bash
kubectl get pod cordon-test
```

Esperado: `NotFound`.

Reabrir:

```bash
kubectl uncordon k8s-wk-01
kubectl get nodes
```

Opcionalmente, voltar a criar o Pod para provar que o Worker aceita scheduling após `uncordon`, e removê-lo no fim.

## 7.5. Health gate do runtime

No Worker:

```bash
sudo journalctl -k --since '-10 min' --no-pager \
  | grep -Ei \
    'apparmor="DENIED"|unable to signal init|permission denied' \
  || true
```

Na baseline validada não reapareceu o incidente antigo de `runc ... unable to signal init: permission denied`.

---

# CP8 — Health gate e snapshot antes do upgrade

Executar no **Control Plane**:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl cluster-info
kubectl get events -A --sort-by=.lastTimestamp | tail -n 100

kubectl get pods -A \
  --field-selector=status.phase=Failed

kubectl get pods -A \
  | grep -E 'Evicted|ContainerStatusUnknown|CrashLoopBackOff|Error' \
  || true
```

Critérios mínimos:

```text
ambos os Nodes Ready
DiskPressure=False
calico Available=True / Progressing=False / Degraded=False
CoreDNS Running
sem Pods Failed atuais
sem churn de Evicted/ContainerStatusUnknown
sem AppArmor DENIED
```

## 8.1. Confirmar versões antes do upgrade

No Control Plane:

```bash
kubeadm version -o short
kubectl get nodes \
  -o custom-columns='NAME:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion'
```

No Worker:

```bash
kubeadm version -o short
kubelet --version
containerd --version
```

## 8.2. Criar snapshots coordenados

Só com o cluster saudável, criar snapshots das **duas VMs** no mesmo ponto lógico.

Nome recomendado:

```text
S04-CP8-K8s-1.35.8-Healthy-Before-Upgrade
```

> Snapshot de VM é adequado como ponto de recuperação deste laboratório. Não substitui uma estratégia de backup/restore de produção para etcd e dados persistentes.

## 8.3. Preparar o repositório 1.36 nos dois nós

Executar nos **dois nós**:

```bash
sudo rm -f /etc/apt/sources.list.d/kubernetes.list
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

curl -fsSL \
  https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | sudo gpg --dearmor \
      -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo \
  'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
apt-cache madison kubeadm | head -n 20
```

Confirmar que existe:

```text
1.36.4-1.1
```

Ainda não atualizar o kubelet.

---

# CP9 — Upgrade do Control Plane para 1.36.4

Executar no **`k8s-cp-01`**.

## 9.1. Atualizar apenas kubeadm

```bash
K8S_136_PKG_VERSION='1.36.4-1.1'

sudo apt-mark unhold kubeadm
sudo apt-get -s install kubeadm="$K8S_136_PKG_VERSION"
```

A simulação deve alterar apenas `kubeadm`.

```bash
sudo apt-get install -y \
  kubeadm="$K8S_136_PKG_VERSION"

sudo apt-mark hold kubeadm

kubeadm version -o short
kubelet --version
kubectl version --client
```

Nesta fase:

```text
kubeadm   v1.36.4
kubelet   v1.35.8
kubectl   v1.35.8
```

## 9.2. Planear antes de aplicar

```bash
sudo kubeadm upgrade plan
```

Confirmar:

```text
Cluster version: 1.35.8
Target version:  v1.36.4
```

O plano validado atualizou também:

```text
CoreDNS  v1.13.1 → v1.14.2
etcd     3.6.6-0 → 3.6.8-0
```

## 9.3. Aplicar o upgrade do Control Plane

```bash
sudo kubeadm upgrade apply v1.36.4
```

Só avançar se terminar com sucesso.

Validar:

```bash
kubectl version
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus

kubectl get pods -n kube-system \
  -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[*].image,STATUS:.status.phase'
```

É normal o API Server já estar em `v1.36.4` enquanto o kubelet do Node ainda reporta `v1.35.8`.

## 9.4. Drain do Control Plane

Antes do drain, confirmar que o Tigera Operator e Calico estão estáveis:

```bash
kubectl get pod -n tigera-operator -o wide
kubectl get tigerastatus
```

Depois:

```bash
kubectl drain k8s-cp-01 \
  --ignore-daemonsets
```

Os static Pods do Control Plane e os DaemonSets permanecem no nó; workloads evacuáveis são movidos.

## 9.5. Atualizar kubelet e kubectl do Control Plane

```bash
sudo apt-mark unhold kubelet kubectl

sudo apt-get -s install \
  kubelet="$K8S_136_PKG_VERSION" \
  kubectl="$K8S_136_PKG_VERSION"
```

A simulação deve alterar apenas `kubelet` e `kubectl`.

```bash
sudo apt-get install -y \
  kubelet="$K8S_136_PKG_VERSION" \
  kubectl="$K8S_136_PKG_VERSION"

sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

Validar:

```bash
sudo systemctl is-active kubelet
kubelet --version
kubectl version --client
kubectl get nodes -o wide
```

O nó pode aparecer `NotReady` durante alguns segundos após o restart.

Aguardar o scheduler:

```bash
kubectl wait \
  --namespace=kube-system \
  --for=condition=Ready \
  pod/kube-scheduler-k8s-cp-01 \
  --timeout=120s
```

Reabrir:

```bash
kubectl uncordon k8s-cp-01
kubectl get nodes
```

Esperado:

```text
k8s-cp-01   Ready   ...   v1.36.4
k8s-wk-01   Ready   ...   v1.35.8
```

---

# CP10 — Upgrade do Worker para 1.36.4

## 10.1. Atualizar kubeadm no Worker

No **`k8s-wk-01`**:

```bash
K8S_136_PKG_VERSION='1.36.4-1.1'

sudo apt-mark unhold kubeadm
sudo apt-get -s install kubeadm="$K8S_136_PKG_VERSION"

sudo apt-get install -y \
  kubeadm="$K8S_136_PKG_VERSION"

sudo apt-mark hold kubeadm

kubeadm version -o short
kubelet --version
```

Esperado:

```text
kubeadm  v1.36.4
kubelet  v1.35.8
```

## 10.2. Atualizar a configuração local do Worker

```bash
sudo kubeadm upgrade node
sudo systemctl is-active kubelet
kubelet --version
```

O binário do kubelet continua `v1.35.8` até à etapa seguinte.

## 10.3. Preparar o Tigera Operator antes do drain integral

No **Control Plane**:

```bash
kubectl get pod -n tigera-operator -o wide
```

Se o Tigera Operator estiver no Worker, fixá-lo temporariamente ao Control Plane:

```bash
kubectl patch deployment tigera-operator \
  -n tigera-operator \
  --type='merge' \
  -p '{
    "spec": {
      "template": {
        "spec": {
          "nodeSelector": {
            "kubernetes.io/hostname": "k8s-cp-01"
          }
        }
      }
    }
  }'

kubectl rollout status deployment/tigera-operator \
  -n tigera-operator \
  --timeout=120s

kubectl get pod -n tigera-operator -o wide
```

Confirmar que o Operator está `Running` no Control Plane e que o core Calico continua saudável.

## 10.4. Drain integral do Worker

No Control Plane:

```bash
kubectl drain k8s-wk-01 \
  --ignore-daemonsets
```

Não adicionar `--force` ou `--delete-emptydir-data` automaticamente. Se o drain recusar, ler primeiro a causa.

Validar:

```bash
kubectl get nodes
kubectl get pods -A -o wide \
  --field-selector spec.nodeName=k8s-wk-01
```

Esperado: ficam essencialmente os DaemonSets `calico-node`, `csi-node-driver` e `kube-proxy`.

## 10.5. Atualizar kubelet e kubectl do Worker

No Worker:

```bash
sudo apt-mark unhold kubelet kubectl

sudo apt-get -s install \
  kubelet="$K8S_136_PKG_VERSION" \
  kubectl="$K8S_136_PKG_VERSION"

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

apt-mark showhold \
  | grep -E '^(containerd.io|kubeadm|kubelet|kubectl)$'
```

Esperado:

```text
kubeadm   v1.36.4
kubelet   v1.36.4
kubectl   v1.36.4
```

## 10.6. Health gate do runtime no Worker

```bash
sudo journalctl -k --since '-10 min' --no-pager \
  | grep -Ei \
    'apparmor="DENIED"|unable to signal init|permission denied' \
  || true
```

Durante o arranque do kubelet podem surgir mensagens transitórias como:

```text
checkpoint is not found
no imagefs label for configured runtime
```

No laboratório validado surgiram apenas no arranque e não se repetiram depois de o nó estabilizar. O critério é ausência de repetição persistente, `DiskPressure=False` e workloads funcionais.

## 10.7. Uncordon e reposição do Operator

No Control Plane:

```bash
kubectl get nodes -o wide
kubectl uncordon k8s-wk-01
kubectl get nodes
```

Esperado:

```text
k8s-cp-01   Ready   ...   v1.36.4
k8s-wk-01   Ready   ...   v1.36.4
```

Se foi adicionado o `nodeSelector` temporário ao Tigera Operator, removê-lo:

```bash
kubectl patch deployment tigera-operator \
  -n tigera-operator \
  --type='json' \
  -p='[
    {
      "op": "remove",
      "path": "/spec/template/spec/nodeSelector"
    }
  ]'

kubectl rollout status deployment/tigera-operator \
  -n tigera-operator \
  --timeout=120s
```

O Operator pode depois ser colocado em qualquer um dos dois nós.

---

# CP11 — Validação final do cluster

Executar no **Control Plane**:

```bash
kubectl get nodes \
  -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,DISK:.status.conditions[?(@.type=="DiskPressure")].status,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion'

kubectl get pods -A -o wide
kubectl get tigerastatus

kubectl get pods -A \
  --field-selector=status.phase!=Running,status.phase!=Succeeded

kubectl version
```

Output final de referência:

```text
NAME        READY   DISK    KUBELET   RUNTIME
k8s-cp-01   True    False   v1.36.4   containerd://2.2.6
k8s-wk-01   True    False   v1.36.4   containerd://2.2.6
```

E:

```text
Client Version: v1.36.4
Server Version: v1.36.4
```

O core Calico deve continuar:

```text
calico   True   False   False   All objects available
```

Não devem existir Pods atuais em `Failed`, `CrashLoopBackOff`, `Error`, `Evicted` ou `ContainerStatusUnknown`.

## 11.1. Verificação final AppArmor/runc no Worker

```bash
sudo journalctl -k --since '-5 min' --no-pager \
  | grep -Ei \
    'apparmor="DENIED"|unable to signal init|permission denied' \
  || true
```

Na baseline validada, o problema histórico de AppArmor/runc **não se reproduziu** com a instalação limpa baseada em `containerd 2.2.6` + `runc 1.3.6`.

Isto não prova que `containerd 2.2.6` seja, isoladamente, a causa da correção; apenas documenta o resultado observado no ambiente testado.

---

# 12. Evidências a recolher

Registar pelo menos:

1. versões iniciais `kubeadm`, `kubelet`, `kubectl`, `containerd` e `runc`;
2. `df -h /` e estado `DiskPressure`;
3. `kubectl get nodes -o wide` após `kubeadm init` + Calico;
4. Worker `Ready` após `join`;
5. resultado do primeiro `drain` seletivo sem `--force`;
6. resultado do `drain --force` sobre o Pod de teste;
7. health gate antes do snapshot;
8. `kubeadm upgrade plan`;
9. `SUCCESS` do `kubeadm upgrade apply v1.36.4`;
10. Control Plane em `v1.36.4` com Worker ainda em `v1.35.8`;
11. `kubeadm upgrade node` no Worker;
12. drain integral do Worker;
13. ambos os nós `Ready` em `v1.36.4`;
14. ausência de `AppArmor DENIED` no health gate final.

Usa também a [folha de evidências](../../folha_evidencias.md).

---

# 13. Se algo correr mal

```text
PARAR
  ↓
OBSERVAR
  ↓
REGISTAR EVIDÊNCIA
  ↓
IDENTIFICAR A CAUSA
  ↓
CORRIGIR OU RESTAURAR
```

No Control Plane:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp | tail -n 100
kubectl get tigerastatus
```

No nó afetado:

```bash
sudo systemctl status kubelet --no-pager
sudo systemctl status containerd --no-pager
sudo journalctl -u kubelet -n 100 --no-pager
sudo journalctl -k --since '-30 min' --no-pager \
  | grep -Ei \
    'apparmor="DENIED"|audit.*DENIED|runc|containerd' \
  || true
```

Não usar como primeira reação:

```text
--ignore-preflight-errors
--force
apt downgrade improvisado
desativar AppArmor globalmente
```

Num laboratório descartável, se o upgrade deixar o cluster num estado inconsistente que não é possível explicar/corrigir com segurança, restaurar os snapshots coordenados criados em CP8.

Consulta também:

- [Troubleshooting](../../troubleshooting.md)
- [Compatibilidade](../../compatibilidade.md)
- [Checklist operacional](../../checklist_operacional.md)
- [Cheat sheet](../../cheat_sheet.md)

---

# 14. Síntese

No final do laboratório, o formando deve conseguir explicar:

```text
porque fixámos uma versão Kubernetes
porque o Pod CIDR não pode sobrepor a rede física
porque o CNI é necessário
porque kubectl administrativo fica no Control Plane
porque cordon ≠ drain
porque drain exige leitura do tipo de Pod
porque kubeadm é atualizado antes do kubelet
porque o Control Plane é atualizado antes do Worker
porque o kubelet é atualizado com o nó drenado
porque health gates são parte do upgrade
porque persistência/snapshot ≠ estratégia de backup de produção
```

Resultado final validado:

```text
Kubernetes 1.35.8
       ↓
upgrade minor sequencial
       ↓
Kubernetes 1.36.4

Control Plane Ready
Worker Ready
Calico saudável
containerd 2.2.6
DiskPressure=False
sem AppArmor DENIED
```
