# Laboratório Integrado — Sessão 4
## Kubernetes Admin I: de duas VMs Ubuntu a um cluster Kubernetes funcional

**Duração:** 4 horas  
**Nível:** intermédio  
**Topologia:** `k8s-cp-01` + `k8s-wk-01`  
**Stack:** Ubuntu 26.04 LTS · Kubernetes 1.37 · containerd · Calico/Tigera Operator

## Regra pedagógica

Neste laboratório não existe um script de instalação para o formando. Em cada etapa:

```text
CONCEITO
   ↓
PORQUE É NECESSÁRIO
   ↓
COMANDO MANUAL
   ↓
O QUE OBSERVAR
   ↓
EVIDÊNCIA
   ↓
ERRO FREQUENTE
```

Usa [`../folha_evidencias.md`](../folha_evidencias.md) durante o percurso.

---

# 0. Resultado final

```text
NAME         STATUS   ROLES
k8s-cp-01    Ready    control-plane
k8s-wk-01    Ready    <none>
```

---

# CP1 — Preparar os dois nós Linux

Executar em **`k8s-cp-01` e `k8s-wk-01`**.

## 1.1 Identidade e recursos

```bash
hostnamectl
ip -br address
free -h
```

Configura os nomes, se necessário:

```bash
# apenas no Control Plane
sudo hostnamectl set-hostname k8s-cp-01

# apenas no Worker
sudo hostnamectl set-hostname k8s-wk-01
```

Regista os IPs. Cada VM deve ter recursos suficientes para o laboratório; usa pelo menos cerca de 2 GiB de RAM e 2 vCPU.

## 1.2 Resolução entre os nós

Em ambos os nós, acrescenta a `/etc/hosts` os IPs reais:

```text
<IP_CP>      k8s-cp-01
<IP_WORKER>  k8s-wk-01
```

Valida:

```bash
getent hosts k8s-cp-01
getent hosts k8s-wk-01
ping -c 2 k8s-cp-01
ping -c 2 k8s-wk-01
```

## 1.3 Confirmar que não existe Kubernetes residual

Antes de construir o cluster, verifica se a VM já tem MicroK8s, k3s, Minikube ou componentes de uma instalação anterior:

```bash
snap list microk8s 2>/dev/null
sudo ss -ltnp | grep -E ':(6443|2379|2380|10250|10257|10259)\b'
```

Se surgirem `kubelite`, `kube-apiserver`, `etcd`, `kube-scheduler` ou `kube-controller-manager`, **não avances**. Identifica primeiro a origem.

## 1.4 Swap

```bash
swapon --show
sudo swapoff -a
```

Revê `/etc/fstab` para tornar a decisão persistente no ambiente de laboratório.

## 1.5 Módulos e sysctl

```bash
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
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
stat -fc %T /sys/fs/cgroup
timedatectl status
```

**Checkpoint CP1:** completa o checklist manual.

---

# CP2 — Instalar e configurar containerd

Executar nos **dois nós**.

```bash
sudo apt-get update
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
```

## Confirmar CRI

```bash
sudo grep -n 'disabled_plugins' /etc/containerd/config.toml
```

`cri` não deve estar em `disabled_plugins`.

## Configurar cgroup driver

No containerd 2.x, localiza a secção do runtime CRI:

```bash
sudo grep -n -A12 -B2 \
"io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options" \
/etc/containerd/config.toml
```

Edita manualmente:

```bash
sudo nano /etc/containerd/config.toml
```

Dentro de `runc.options`, garante:

```text
SystemdCgroup = true
```

Depois:

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
systemctl is-active containerd
containerd config dump | grep -i -A5 -B5 SystemdCgroup
sudo ctr plugins ls | grep -i cri
sudo ss -lx | grep containerd
```

**Checkpoint CP2:** explica a cadeia `kubelet → CRI → containerd → runc → kernel`.

---

# CP3 — Instalar kubelet, kubeadm e kubectl

Executar nos **dois nós**.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.37/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.37/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
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

Antes de `init`/`join`, o kubelet pode ainda não estar plenamente operacional como Node.

**Checkpoint CP3.**

---

# CP4 — Inicializar o Control Plane

A partir daqui, esta secção é **APENAS em `k8s-cp-01`**.

Confirma primeiro:

```bash
hostname
free -h
systemctl is-active containerd
swapon --show
sudo ss -ltnp | grep -E ':(6443|2379|2380|10257|10259)\b'
```

Executa:

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

> Se um preflight falhar, corrige a causa. Não avances com `--ignore-preflight-errors` apenas para esconder o sintoma.

Configura o kubeconfig do utilizador normal:

```bash
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"
```

Valida:

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -n kube-system
```

**O que observar:** antes do CNI, `k8s-cp-01` pode aparecer `NotReady` e CoreDNS pode não estar operacional.

**Checkpoint CP4.**

---

# CP5 — Instalar Calico via Tigera Operator

Executar no **Control Plane**. A versão Calico deve ser a versão previamente validada pelo formador para a edição. A edição de referência foi ensaiada com `v3.32.2`.

```bash
export CALICO_VERSION=v3.32.2

kubectl create -f \
https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/v1_crd_projectcalico_org.yaml

kubectl create -f \
https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml
```

Confirma o Operator:

```bash
kubectl get pods -n tigera-operator
```

Obtém e **inspeciona** os Custom Resources:

```bash
curl -LO \
https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml

grep -n 'cidr:' custom-resources.yaml
```

O CIDR deve ser coerente com `192.168.0.0/16`. Corrige-o manualmente se necessário e só depois aplica:

```bash
kubectl create -f custom-resources.yaml
```

Acompanha:

```bash
kubectl get tigerastatus
kubectl get pods -n tigera-operator -o wide
kubectl get pods -n calico-system -o wide
kubectl get nodes
```

Quando `k8s-cp-01` ficar `Ready`, a rede base está funcional.

## Não confundir `Pending` com CNI avariado

O Control Plane tem por omissão:

```text
node-role.kubernetes.io/control-plane:NoSchedule
```

Enquanto ainda não existir Worker, alguns Deployments (incluindo componentes Calico/Tigera e CoreDNS) podem ficar `Pending`. Confirma:

```bash
kubectl get events -A --sort-by=.lastTimestamp
kubectl describe node k8s-cp-01 | grep -i Taints
```

**Não removas a taint.** Continua para o Worker.

---

# CP6 — Adicionar o Worker

No **`k8s-cp-01`**, gera um comando atual:

```bash
sudo kubeadm token create --print-join-command
```

No **`k8s-wk-01`**, executa o comando **real** devolvido pelo Control Plane, com `sudo`:

```bash
sudo kubeadm join <CP_REAL>:6443 --token <TOKEN_REAL> \
  --discovery-token-ca-cert-hash sha256:<HASH_REAL>
```

`<CP_REAL>`, `<TOKEN_REAL>` e `<HASH_REAL>` são marcadores nesta documentação. Não os executes literalmente e nunca uses `...` como valor.

> **Muito importante:** no Worker executa-se `kubeadm join`, não `kubeadm init`.

De volta ao Control Plane:

```bash
kubectl get nodes -o wide
kubectl get pods -n calico-system -o wide
kubectl get pods -n kube-system -o wide
kubectl get tigerastatus
```

Aguarda alguns minutos pela convergência. O resultado esperado é:

```text
k8s-cp-01   Ready   control-plane
k8s-wk-01   Ready   <none>
CoreDNS      Running
Calico       operacional
```

**Checkpoint CP6.**

---

# Explorar kubeconfig e contextos

No Control Plane:

```bash
kubectl config view
kubectl config current-context
kubectl config get-contexts
```

Um contexto associa `cluster + user + namespace opcional`.

> `kubectl` está instalado no Worker por uniformização do laboratório, mas o Worker não precisa de kubeconfig administrativo. A administração é feita a partir do Control Plane.

---

# CP7 — Manutenção controlada do Worker

## Criar o Pod direto de teste

```bash
kubectl apply -f manifests/pod_cordon_test.yaml
kubectl get pod cordon-test -o wide
```

O Pod deve estar em `k8s-wk-01`. Não existe Deployment/ReplicaSet a geri-lo.

## Cordon

```bash
kubectl cordon k8s-wk-01
kubectl get nodes
```

`cordon` impede **novo scheduling**, mas não remove os Pods existentes.

## Drain sem `--force`

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets
```

Lê a mensagem. O Pod direto sem controller deve obrigar a uma decisão explícita.

## Drain com decisão explícita

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets --force
kubectl get pod cordon-test
```

O Pod desaparece e não é recriado porque não existe controller.

## Uncordon

```bash
kubectl uncordon k8s-wk-01
kubectl get nodes
```

**Checkpoint CP7:** Worker `Ready`, novamente schedulable, sem `cordon-test`.

---

# Upgrade — leitura do plano

No Control Plane:

```bash
sudo kubeadm upgrade plan
```

Nesta sessão não executamos um upgrade multi-node completo. Interpreta origem, destino, componentes e ordem de intervenção. Consulta [`../exercicios/upgrade_complementar.md`](../exercicios/upgrade_complementar.md).

---

# CP8 — Validação final manual

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl cluster-info
kubectl config current-context
```

Confirma:

```text
[ ] k8s-cp-01 Ready
[ ] k8s-wk-01 Ready
[ ] Worker schedulable
[ ] Tigera/Calico operacional
[ ] CoreDNS Running
[ ] API acessível
[ ] contexto kubectl conhecido
[ ] cordon-test removido
```

---

# Troubleshooting: método

```text
Sintoma
  ↓
Evidência
  ↓
Hipótese
  ↓
Validação
  ↓
Correção
  ↓
Nova validação
```

Comandos úteis:

```bash
kubectl get nodes -o wide
kubectl describe node <node>
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
kubectl get tigerastatus
systemctl status kubelet --no-pager
systemctl status containerd --no-pager
journalctl -u kubelet -n 50 --no-pager
journalctl -u containerd -n 50 --no-pager
sudo ss -ltnp | grep -E ':(6443|2379|2380|10250|10257|10259)\b'
```

Consulta também [`../troubleshooting.md`](../troubleshooting.md).

---

# Questões de consolidação

1. Porque é necessário configurar o runtime antes de `kubeadm init`?
2. Qual é a função do CRI?
3. Porque usamos `SystemdCgroup = true`?
4. Porque o Control Plane pode ficar `NotReady` antes do CNI?
5. Porque alguns Pods podem ficar `Pending` antes do Worker existir?
6. Porque não removemos a taint do Control Plane?
7. Qual a diferença entre `kubeadm init` e `kubeadm join`?
8. Qual a diferença entre `cordon` e `drain`?
9. Porque foi necessário `--force` no Pod direto?
10. Porque esse Pod não foi recriado?
11. Porque um token de exemplo/placeholder não serve num `join`?
12. Porque `kubeadm upgrade plan` é útil mesmo sem executar o upgrade?

Na Sessão 5, o foco passa de **construir o cluster** para **executar e expor workloads e preservar os seus dados**.
