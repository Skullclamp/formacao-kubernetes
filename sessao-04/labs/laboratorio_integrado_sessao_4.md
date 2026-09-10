# Laboratório Integrado — Sessão 4
## Kubernetes Admin I: instalar 1.35.x, operar e atualizar para 1.36.x

**Duração:** 4 horas  
**Nível:** intermédio  
**Topologia:** `k8s-cp-01` + `k8s-wk-01`

## Baseline

```text
Ubuntu:              26.04 LTS
Kubernetes inicial:  1.35.8
Kubernetes final:    1.36.4
containerd:          2.2.x
Calico:              3.32.2
Tigera Operator:     1.42.6
Pod CIDR:            192.168.0.0/16
Service CIDR:        10.96.0.0/12
```

Os patches 1.35.x e 1.36.x devem ser confirmados antes da turma. O laboratório fixa sempre uma versão concreta descoberta no repositório APT; não instala simplesmente "a mais recente".

## Método

```text
COMPREENDER → EXECUTAR → OBSERVAR → REGISTAR → EXPLICAR
```

Usa `../folha_evidencias.md` durante o percurso.

---

# CP1 — Confirmar identidade e limpar o ponto de partida

Executar nos **dois nós**.

```bash
hostname
ip -br address
free -h
swapon --show
```

Esperado:

```text
Control Plane → k8s-cp-01
Worker        → k8s-wk-01
```

## 1.1. Confirmar que não existe Kubernetes residual

```bash
snap list microk8s 2>/dev/null || true
systemctl list-units --type=service | grep -Ei 'microk8s|k3s|minikube' || true
sudo ss -ltnp | grep -E ':(6443|2379|2380|10250|10257|10259)\b' || true

dpkg-query -W -f='${Package} ${Version}\n' kubeadm kubelet kubectl 2>/dev/null || true

grep -R "pkgs.k8s.io/core:/stable:" \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true
```

Se a VM já tiver Kubernetes 1.37 ou um cluster anterior, **não tentes fazer downgrade ad hoc**. Para esta formação, repõe o snapshot/VM limpa e recomeça.

## 1.2. Swap, módulos e sysctl

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
stat -fc %T /sys/fs/cgroup
timedatectl status
```

## 1.3. Resolução entre nós

Regista os IPs reais e configura `/etc/hosts` em ambos:

```text
<IP_CP>      k8s-cp-01
<IP_WORKER>  k8s-wk-01
```

```bash
getent hosts k8s-cp-01
getent hosts k8s-wk-01
ping -c 2 k8s-cp-01
ping -c 2 k8s-wk-01
```

---

# CP2 — Instalar containerd 2.2.x

A série **containerd 2.2.x** é escolhida porque é uma série recomendada em comum para Kubernetes 1.35 e 1.36.

Executar nos **dois nós**.

## 2.1. Repositório Docker apenas para `containerd.io`

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"${UBUNTU_CODENAME:-$VERSION_CODENAME}\") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update
apt-cache madison containerd.io
```

Seleciona automaticamente o patch 2.2.x mais recente disponível:

```bash
CONTAINERD_PKG_VERSION="$(
  apt-cache madison containerd.io |
  awk '$3 ~ /^2\.2\./ {print $3; exit}'
)"

printf 'containerd.io selecionado: %s\n' "$CONTAINERD_PKG_VERSION"
test -n "$CONTAINERD_PKG_VERSION"

sudo apt-get install -y containerd.io="$CONTAINERD_PKG_VERSION"
```

## 2.2. Configuração CRI e cgroups

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo nano /etc/containerd/config.toml
```

Confirma duas condições:

```text
1. cri NÃO está em disabled_plugins
2. SystemdCgroup = true nas opções do runtime runc
```

Depois:

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd

containerd --version
systemctl is-active containerd
containerd config dump | grep -i -A5 -B5 SystemdCgroup
sudo ctr plugins ls | grep -i cri
sudo ss -lx | grep containerd
```

Modelo mental:

```text
kubelet → CRI → containerd → runc → kernel
```

---

# CP3 — Instalar exatamente Kubernetes 1.35.x

Executar nos **dois nós**.

## 3.1. Garantir que não ficou um repositório Kubernetes de outra minor

```bash
grep -R "pkgs.k8s.io/core:/stable:" \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true
```

Numa VM limpa, configura o repositório 1.35:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
apt-cache madison kubeadm
```

## 3.2. Fixar explicitamente o pacote 1.35.x

```bash
K8S_PKG_VERSION="$(
  apt-cache madison kubeadm |
  awk '$3 ~ /^1\.35\./ {print $3; exit}'
)"

printf 'Kubernetes package: %s\n' "$K8S_PKG_VERSION"
test -n "$K8S_PKG_VERSION"

sudo apt-get install -y \
  kubelet="$K8S_PKG_VERSION" \
  kubeadm="$K8S_PKG_VERSION" \
  kubectl="$K8S_PKG_VERSION"

sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
```

Validar:

```bash
kubeadm version
kubelet --version
kubectl version --client
apt-mark showhold
```

**Não avances se aparecer 1.36 ou 1.37.**

---

# CP4 — Inicializar o Control Plane em 1.35.x

Executar **apenas em `k8s-cp-01`**.

```bash
hostname
```

Guarda de segurança contra nó errado:

```bash
test "$(hostname -s)" = "k8s-cp-01" || {
  echo "ERRO: kubeadm init só pode ser executado em k8s-cp-01"
  exit 1
}
```

Deriva a versão Kubernetes a partir do pacote instalado:

```bash
K8S_PKG_VERSION="$(dpkg-query -W -f='${Version}' kubeadm)"
K8S_SEMVER="v${K8S_PKG_VERSION%%-*}"
printf 'Bootstrap Kubernetes: %s\n' "$K8S_SEMVER"
```

Inicializa:

```bash
sudo kubeadm init \
  --kubernetes-version="$K8S_SEMVER" \
  --pod-network-cidr=192.168.0.0/16
```

Configura `kubectl`:

```bash
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"
```

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -n kube-system
```

Antes do CNI, `NotReady` pode ser esperado.

---

# CP5 — Instalar Calico 3.32.2 via Tigera Operator

Executar no **Control Plane**.

```bash
export CALICO_VERSION=v3.32.2

kubectl create -f \
  https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/v1_crd_projectcalico_org.yaml

kubectl create -f \
  https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml
```

Validar o Operator e a imagem utilizada:

```bash
kubectl get pods -n tigera-operator
kubectl -n tigera-operator get deploy tigera-operator \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Para Calico 3.32.2, a referência esperada do Operator é `quay.io/tigera/operator:v1.42.6`.

Obtém e inspeciona os Custom Resources:

```bash
curl -LO \
  https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml

grep -n 'cidr:' custom-resources.yaml
```

O CIDR deve ser `192.168.0.0/16`. Depois:

```bash
kubectl create -f custom-resources.yaml

kubectl get tigerastatus
kubectl get pods -n tigera-operator -o wide
kubectl get pods -n calico-system -o wide
kubectl get nodes
```

Calico 3.32 é oficialmente testado com Kubernetes 1.35 e 1.36, por isso este percurso permanece dentro da matriz de testes publicada.

---

# CP6 — Gerar o join no Control Plane e integrar o Worker

## 6.1. Gerar o comando — APENAS `k8s-cp-01`

```bash
hostname
```

```bash
test "$(hostname -s)" = "k8s-cp-01" || {
  echo "ERRO: o token de join é criado no Control Plane, não no Worker"
  exit 1
}
```

```bash
set +x
sudo kubeadm token create --print-join-command \
  --kubeconfig /etc/kubernetes/admin.conf
```

> Se executares este comando no Worker, não existe um `admin.conf` de Control Plane e o comando falha. **Não copies o kubeconfig administrativo para o Worker para contornar o erro.**

## 6.2. Executar o join — APENAS `k8s-wk-01`

No Worker:

```bash
hostname
```

```bash
test "$(hostname -s)" = "k8s-wk-01" || {
  echo "ERRO: kubeadm join só pode ser executado em k8s-wk-01"
  exit 1
}
```

Executa, com `sudo`, **o comando real** produzido no Control Plane.

De volta ao Control Plane:

```bash
kubectl get nodes -o wide
kubectl get pods -n calico-system -o wide
kubectl get pods -n kube-system -o wide
kubectl get tigerastatus
```

Aguarda a convergência até os dois Nodes estarem `Ready` e CoreDNS/Calico operacionais.

---

# CP7 — Manutenção: cordon, drain e uncordon

No Control Plane:

```bash
kubectl apply -f ../manifests/pod_cordon_test.yaml
kubectl get pod cordon-test -o wide

kubectl cordon k8s-wk-01
kubectl drain k8s-wk-01 --ignore-daemonsets
```

O primeiro `drain` deve chamar a atenção para o Pod direto sem controller. Lê a mensagem.

Só para este exercício controlado:

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets --force
kubectl get pod cordon-test
kubectl uncordon k8s-wk-01
kubectl get nodes
```

---

# CP8 — Ponto de recuperação antes do upgrade

Antes de alterar versões:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl cluster-info
```

Cria na plataforma de virtualização um snapshot coordenado das duas VMs:

```text
k8s-cp-01 → pre-upgrade-1.35
k8s-wk-01 → pre-upgrade-1.35
```

Se o upgrade falhar gravemente no laboratório, este é o ponto de retorno. Não se ensina um downgrade APT improvisado.

---

# CP9 — Upgrade do Control Plane: 1.35.x → 1.36.x

Executar primeiro em **`k8s-cp-01`**.

## 9.1. Mudar o repositório para 1.36

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update

K8S_PKG_VERSION_136="$(
  apt-cache madison kubeadm |
  awk '$3 ~ /^1\.36\./ {print $3; exit}'
)"
K8S_TARGET="v${K8S_PKG_VERSION_136%%-*}"

printf 'Pacote destino: %s\n' "$K8S_PKG_VERSION_136"
printf 'Kubernetes destino: %s\n' "$K8S_TARGET"
test -n "$K8S_PKG_VERSION_136"
```

## 9.2. Atualizar kubeadm e o Control Plane

```bash
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm="$K8S_PKG_VERSION_136"
sudo apt-mark hold kubeadm

kubeadm version
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply "$K8S_TARGET"
```

Validar antes de continuar:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
```

## 9.3. Atualizar kubelet e kubectl do Control Plane

```bash
kubectl drain k8s-cp-01 --ignore-daemonsets

sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y \
  kubelet="$K8S_PKG_VERSION_136" \
  kubectl="$K8S_PKG_VERSION_136"
sudo apt-mark hold kubelet kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet

kubectl uncordon k8s-cp-01
kubectl get nodes -o wide
```

Neste momento, é normal o Worker ainda estar na versão 1.35.x.

---

# CP10 — Upgrade do Worker para 1.36.x

No **Worker**, muda o repositório para 1.36 e calcula novamente a versão de pacote:

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update

K8S_PKG_VERSION_136="$(
  apt-cache madison kubeadm |
  awk '$3 ~ /^1\.36\./ {print $3; exit}'
)"
test -n "$K8S_PKG_VERSION_136"

sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm="$K8S_PKG_VERSION_136"
sudo apt-mark hold kubeadm

sudo kubeadm upgrade node
```

No **Control Plane**:

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets
```

No **Worker**:

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y \
  kubelet="$K8S_PKG_VERSION_136" \
  kubectl="$K8S_PKG_VERSION_136"
sudo apt-mark hold kubelet kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

No **Control Plane**:

```bash
kubectl uncordon k8s-wk-01
```

---

# CP11 — Validação final

No Control Plane:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl cluster-info
kubectl config current-context
```

Esperado:

```text
k8s-cp-01   Ready   control-plane   v1.36.x
k8s-wk-01   Ready   <none>          v1.36.x
```

Confirma também:

```bash
kubectl get pods -n kube-system -o wide
kubectl get pods -n calico-system -o wide
```

`kubeadm upgrade apply` gere os add-ons CoreDNS e kube-proxy no processo de upgrade; mesmo assim, o formando deve confirmar o seu estado final.

---

# Se algo correr mal

```text
PARAR
  ↓
recolher evidência
  ↓
não avançar para o próximo nó
  ↓
decidir correção ou restauro
```

Comandos úteis:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
kubectl get tigerastatus
journalctl -u kubelet -n 80 --no-pager
systemctl status containerd --no-pager
sudo ls -la /etc/kubernetes/tmp/ 2>/dev/null || true
```

Num laboratório descartável, se o estado ficar inconsistente, restaura os snapshots `pre-upgrade-1.35` das duas VMs.

Consulta também [`../troubleshooting.md`](../troubleshooting.md) e [`../compatibilidade.md`](../compatibilidade.md).
