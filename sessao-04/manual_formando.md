# C) Manual do Formando — Sessão 4
## Kubernetes Admin I — Instalação, Administração e Upgrade do Cluster

**Duração:** 4 horas  
**Nível:** intermédio  
**Topologia:** `k8s-cp-01` + `k8s-wk-01`  
**SO:** Ubuntu 26.04 LTS

## Baseline

```text
Kubernetes inicial:  1.35.8
Kubernetes final:    1.36.4
containerd:          2.2.x
Calico:              3.32.2
Tigera Operator:     1.42.6
```

A versão patch concreta deve ser confirmada antes de cada nova edição. O princípio fixo da sessão é **1.35.x → 1.36.x**.

---

# 1. Objetivo da sessão

Nesta sessão vais acompanhar um ciclo de vida completo:

```text
preparar os nós
      ↓
instalar Kubernetes 1.35
      ↓
construir o cluster
      ↓
instalar a rede de Pods
      ↓
integrar o Worker
      ↓
validar e manter
      ↓
preparar recuperação
      ↓
atualizar para 1.36
      ↓
validar novamente
```

Em cada etapa deves saber responder:

1. porque é necessária;
2. em que nó se executa;
3. que resultado esperas;
4. como o validas;
5. o que investigarias se o resultado fosse diferente.

---

# 2. Refresh Kubernetes

## 2.1. Modelo mental

Kubernetes gere aplicações containerizadas através de uma API declarativa e de ciclos de reconciliação.

```text
estado desejado
      ↓
API Server
      ↓
controllers / scheduler
      ↓
estado real
```

## 2.2. Componentes principais

**Control Plane**

- `kube-apiserver` — ponto central da API;
- `etcd` — armazenamento do estado do cluster;
- `kube-scheduler` — escolhe Nodes para Pods;
- `kube-controller-manager` — executa os controllers.

**Worker**

- `kubelet` — agente do Node;
- `containerd` — runtime de containers;
- `kube-proxy` — networking de Services;
- CNI — rede de Pods.

## 2.3. Ferramentas

| Ferramenta | Papel |
|---|---|
| `kubeadm` | bootstrap e ciclo de vida do cluster |
| `kubelet` | agente que corre em cada Node |
| `kubectl` | cliente que comunica com o API Server |

Regra fundamental:

```text
kubeadm init          → Control Plane
kubeadm token create  → Control Plane
kubeadm join          → Worker
```

## 2.4. Comandos e flags frequentes

```bash
kubectl get nodes
kubectl get pods -A
kubectl get pods -n kube-system -o wide
kubectl describe node <NODE>
kubectl get events -A --sort-by=.lastTimestamp
```

```text
-n <namespace>   namespace específico
-A              todos os namespaces
-o wide         mais informação
-o yaml         representação YAML
-w              acompanhar alterações
--help          ajuda
```

---

# 3. Porque usamos Kubernetes 1.35 → 1.36

A versão Kubernetes mais recente não é automaticamente a melhor baseline para uma formação. Precisamos de compatibilidade transversal entre o cluster e os componentes usados durante o curso.

A opção adotada é:

```text
Kubernetes 1.35.x
        ↓
upgrade minor suportado
        ↓
Kubernetes 1.36.x
```

Razões:

- Kubernetes 1.35 e 1.36 estão suportados nesta edição;
- Calico 3.32 é oficialmente testado com ambas;
- Calico 3.32.2 usa Tigera Operator 1.42.6;
- containerd 2.2.x é uma série recomendada em comum para Kubernetes 1.35 e 1.36;
- Traefik não é instalado nesta sessão, mas a sua política de compatibilidade atual abrange 1.35 e 1.36.

Consulta [`compatibilidade.md`](compatibilidade.md).

---

# 4. Ambiente do laboratório

```text
Control Plane: k8s-cp-01
Worker:        k8s-wk-01
Pod CIDR:      192.168.0.0/16
Service CIDR:  10.96.0.0/12
```

Cada formando utiliza duas VMs.

Antes de começar, confirma que o Pod CIDR não se sobrepõe à rede das VMs, VPN ou rede institucional.

---

# 5. Preparar Linux

Executar em **ambos os nós**.

## 5.1. Identidade e recursos

```bash
hostname
ip -br address
free -h
```

## 5.2. Verificar instalações anteriores

```bash
snap list microk8s 2>/dev/null || true
systemctl list-units --type=service | grep -Ei 'microk8s|k3s|minikube' || true
sudo ss -ltnp | grep -E ':(6443|2379|2380|10250|10257|10259)\b' || true

dpkg-query -W -f='${Package} ${Version}\n' kubeadm kubelet kubectl 2>/dev/null || true

grep -R "pkgs.k8s.io/core:/stable:" \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true
```

Se a VM já tiver Kubernetes 1.37 ou um cluster anterior, o procedimento da formação é **restaurar uma VM/snapshot limpo**, não improvisar um downgrade.

## 5.3. Swap, módulos e sysctl

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

Valida:

```bash
swapon --show
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
stat -fc %T /sys/fs/cgroup
```

---

# 6. containerd 2.2.x e CRI

A série 2.2.x é usada para que o runtime permaneça numa série recomendada tanto para Kubernetes 1.35 como 1.36.

## 6.1. Instalar uma versão 2.2.x

Executar nos dois nós:

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

CONTAINERD_PKG_VERSION="$(
  apt-cache madison containerd.io |
  awk '$3 ~ /^2\.2\./ {print $3; exit}'
)"

test -n "$CONTAINERD_PKG_VERSION"
sudo apt-get install -y containerd.io="$CONTAINERD_PKG_VERSION"
```

## 6.2. Configurar

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo nano /etc/containerd/config.toml
```

Confirma:

```text
cri não está em disabled_plugins
SystemdCgroup = true
```

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd

containerd --version
systemctl is-active containerd
containerd config dump | grep -i -A5 -B5 SystemdCgroup
sudo ctr plugins ls | grep -i cri
```

Modelo mental:

```text
kubelet → CRI → containerd → runc → kernel
```

---

# 7. Instalar exatamente Kubernetes 1.35.x

Executar nos dois nós.

## 7.1. Repositório 1.35

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

## 7.2. Fixar a versão

```bash
K8S_PKG_VERSION="$(
  apt-cache madison kubeadm |
  awk '$3 ~ /^1\.35\./ {print $3; exit}'
)"

test -n "$K8S_PKG_VERSION"
printf 'Versão selecionada: %s\n' "$K8S_PKG_VERSION"

sudo apt-get install -y \
  kubelet="$K8S_PKG_VERSION" \
  kubeadm="$K8S_PKG_VERSION" \
  kubectl="$K8S_PKG_VERSION"

sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
```

Valida:

```bash
kubeadm version
kubelet --version
kubectl version --client
apt-mark showhold
```

**Se aparecer 1.37, não avances.** Verifica os repositórios APT e o estado da VM.

---

# 8. Inicializar o Control Plane

A partir daqui, esta operação é **apenas em `k8s-cp-01`**.

```bash
hostname
```

```bash
test "$(hostname -s)" = "k8s-cp-01" || {
  echo "ERRO: kubeadm init só pode ser executado em k8s-cp-01"
  exit 1
}
```

```bash
K8S_PKG_VERSION="$(dpkg-query -W -f='${Version}' kubeadm)"
K8S_SEMVER="v${K8S_PKG_VERSION%%-*}"

sudo kubeadm init \
  --kubernetes-version="$K8S_SEMVER" \
  --pod-network-cidr=192.168.0.0/16
```

O `--kubernetes-version` evita que o bootstrap use implicitamente outra versão.

Configura o kubeconfig:

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

# 9. Calico 3.32.2 e Tigera Operator 1.42.6

Executar no Control Plane.

```bash
export CALICO_VERSION=v3.32.2

kubectl create -f \
  https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/v1_crd_projectcalico_org.yaml

kubectl create -f \
  https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml
```

Validar o Operator:

```bash
kubectl get pods -n tigera-operator
kubectl -n tigera-operator get deploy tigera-operator \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Para Calico 3.32.2, a imagem do Operator deve corresponder à série `v1.42.6`.

```bash
curl -LO \
  https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml

grep -n 'cidr:' custom-resources.yaml
kubectl create -f custom-resources.yaml
```

Acompanha:

```bash
kubectl get tigerastatus
kubectl get pods -n calico-system -o wide
kubectl get nodes
```

---

# 10. Integrar o Worker

Esta é uma distinção crítica.

## 10.1. Criar o token — no Control Plane

Em **`k8s-cp-01`**:

```bash
hostname
```

```bash
test "$(hostname -s)" = "k8s-cp-01" || {
  echo "ERRO: o token de join é criado no Control Plane"
  exit 1
}
```

```bash
set +x
sudo kubeadm token create --print-join-command \
  --kubeconfig /etc/kubernetes/admin.conf
```

O comando precisa de comunicar com a API do cluster. O Worker não tem `/etc/kubernetes/admin.conf` de Control Plane.

**Não copies `admin.conf` para o Worker para resolver este erro.**

## 10.2. Executar o join — no Worker

Em **`k8s-wk-01`**:

```bash
hostname
```

```bash
test "$(hostname -s)" = "k8s-wk-01" || {
  echo "ERRO: kubeadm join só pode ser executado em k8s-wk-01"
  exit 1
}
```

Executa apenas o comando real devolvido pelo Control Plane.

No Control Plane:

```bash
kubectl get nodes -o wide
kubectl get pods -n kube-system -o wide
kubectl get pods -n calico-system -o wide
kubectl get tigerastatus
```

Aguarda a convergência.

---

# 11. kubeconfig e contextos

No Control Plane:

```bash
kubectl config view
kubectl config current-context
kubectl config get-contexts
```

Um contexto associa:

```text
cluster + user + namespace opcional
```

`kubectl` pode existir no Worker por uniformização do laboratório, mas o Worker não precisa de kubeconfig administrativo para funcionar como Node.

---

# 12. Manutenção: cordon, drain e uncordon

No Control Plane:

```bash
kubectl apply -f manifests/pod_cordon_test.yaml
kubectl get pod cordon-test -o wide

kubectl cordon k8s-wk-01
kubectl drain k8s-wk-01 --ignore-daemonsets
```

Um Pod criado diretamente, sem controller, obriga a uma decisão explícita.

Só no exercício controlado:

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets --force
kubectl get pod cordon-test
kubectl uncordon k8s-wk-01
kubectl get nodes
```

O Pod não reaparece porque não existe controller a reconciliar o estado desejado.

---

# 13. Preparar recuperação antes do upgrade

Antes do upgrade:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl cluster-info
```

Cria snapshots das duas VMs no mesmo ponto lógico:

```text
k8s-cp-01 → pre-upgrade-1.35
k8s-wk-01 → pre-upgrade-1.35
```

Se o upgrade ficar irrecuperável no laboratório, restauramos os snapshots. Não tratamos o rollback como uma simples reinstalação de pacotes antigos.

---

# 14. Upgrade 1.35.x → 1.36.x

Não se saltam versões minor.

## 14.1. Control Plane primeiro

Em `k8s-cp-01`, muda o repositório APT para 1.36:

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
test -n "$K8S_PKG_VERSION_136"
```

Atualiza `kubeadm`:

```bash
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm="$K8S_PKG_VERSION_136"
sudo apt-mark hold kubeadm

sudo kubeadm upgrade plan
sudo kubeadm upgrade apply "$K8S_TARGET"
```

Depois prepara o upgrade minor do kubelet:

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
```

## 14.2. Worker depois

No Worker, muda o repositório para 1.36 e atualiza primeiro `kubeadm`.

```bash
sudo apt-get update
# depois de configurar o repo v1.36
K8S_PKG_VERSION_136="$(
  apt-cache madison kubeadm |
  awk '$3 ~ /^1\.36\./ {print $3; exit}'
)"

sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm="$K8S_PKG_VERSION_136"
sudo apt-mark hold kubeadm
sudo kubeadm upgrade node
```

A partir do Control Plane:

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets
```

No Worker:

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y \
  kubelet="$K8S_PKG_VERSION_136" \
  kubectl="$K8S_PKG_VERSION_136"
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

No Control Plane:

```bash
kubectl uncordon k8s-wk-01
```

---

# 15. Validação final

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl cluster-info
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

CoreDNS e kube-proxy fazem parte do ciclo de upgrade gerido pelo `kubeadm`; mesmo assim, devem ser observados e validados no final.

---

# 16. Troubleshooting orientado por evidências

```text
Sintoma → Evidência → Hipótese → Validação → Correção → Nova validação
```

Comandos base:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
kubectl describe node <NODE>
kubectl get tigerastatus
journalctl -u kubelet -n 80 --no-pager
systemctl status containerd --no-pager
```

### Caso: `failed to load admin kubeconfig`

Se o prompt mostra `k8s-wk-01` e executaste:

```bash
sudo kubeadm token create --print-join-command
```

estás no nó errado. O token é criado no Control Plane.

```text
Worker → NÃO cria token
Control Plane → cria token
Worker → executa join
```

Consulta [`troubleshooting.md`](troubleshooting.md).

---

# 17. Resumo

```text
Linux preparado
  ↓
containerd 2.2.x
  ↓
Kubernetes 1.35.x fixado
  ↓
Control Plane
  ↓
Calico 3.32.2 + Tigera Operator 1.42.6
  ↓
Worker
  ↓
manutenção
  ↓
snapshot
  ↓
upgrade 1.35 → 1.36
  ↓
validação final
```

## Autoavaliação

- [ ] Sei explicar as funções de `kubeadm`, `kubelet` e `kubectl`.
- [ ] Sei distinguir comandos de Control Plane e Worker.
- [ ] Sei instalar explicitamente Kubernetes 1.35.x sem deixar o APT escolher 1.37.
- [ ] Sei validar CRI e `SystemdCgroup`.
- [ ] Sei explicar a compatibilidade Calico/Tigera/containerd.
- [ ] Sei criar o comando de join no Control Plane.
- [ ] Sei aplicar `cordon`, `drain` e `uncordon`.
- [ ] Sei preparar um ponto de recuperação.
- [ ] Sei executar a sequência de upgrade 1.35.x → 1.36.x.
- [ ] Sei validar novamente o cluster depois do upgrade.
