# Laboratório Integrado — Sessão 4
## Kubernetes Admin I: construir em 1.36 e atualizar para 1.37

**Duração:** 4 horas  
**Nível:** intermédio  
**Topologia:** `k8s-cp-01` + `k8s-wk-01`  
**Stack inicial:** Ubuntu 26.04 LTS · Kubernetes 1.36.x · containerd · Calico/Tigera Operator  
**Resultado final:** Kubernetes 1.37.x

## Regra pedagógica

Não existe script de instalação para o formando.

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
EXPLICAÇÃO
```

Usa [`../folha_evidencias.md`](../folha_evidencias.md) durante o percurso.

---

# 0. Resultado final

```text
NAME         STATUS   ROLES           VERSION
k8s-cp-01    Ready    control-plane   v1.37.x
k8s-wk-01    Ready    <none>          v1.37.x
```

---

# CP1 — Preparar os dois nós Linux

Executar em **`k8s-cp-01` e `k8s-wk-01`**.

## 1.1. Identidade e recursos

```bash
hostname
ip -br address
free -h
```

Cada VM deve ter pelo menos cerca de 2 vCPU e 2 GiB RAM para este laboratório.

## 1.2. Resolução entre os nós

Em `/etc/hosts`, usa os IPs reais:

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

## 1.3. Garantir que não existe Kubernetes residual

```bash
snap list microk8s 2>/dev/null
systemctl list-units --type=service | grep -Ei 'microk8s|k3s|minikube'
sudo ss -ltnp | grep -E ':(6443|2379|2380|10250|10257|10259)\b'
```

Se surgirem processos como `kubelite`, `kube-apiserver`, `etcd`, `kube-scheduler` ou `kube-controller-manager`, não avances até perceberes a origem.

## 1.4. Swap

```bash
swapon --show
sudo swapoff -a
```

No laboratório, a decisão é persistida em `/etc/fstab`.

## 1.5. Módulos e sysctl

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

**Checkpoint CP1:** explica ao formador que evidência confirma que os dois hosts estão prontos.

---

# CP2 — Instalar e configurar containerd

Nos dois nós:

```bash
sudo apt-get update
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
```

Confirma que `cri` não está desativado:

```bash
sudo grep -n 'disabled_plugins' /etc/containerd/config.toml
```

Edita:

```bash
sudo nano /etc/containerd/config.toml
```

Na secção `runc.options`, garante:

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

**Checkpoint CP2:** explica `kubelet → CRI → containerd → runc → kernel`.

---

# CP3 — Instalar Kubernetes 1.36.x

Nos dois nós:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' \
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

As versões devem pertencer à série **1.36.x**. A baseline de referência é 1.36.4.

---

# CP4 — Inicializar o Control Plane

Esta secção é **APENAS em `k8s-cp-01`**.

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

Se um preflight falhar, corrige a causa. Não uses `--ignore-preflight-errors` apenas para esconder o sintoma.

Configura o kubeconfig:

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

**Observação:** antes do CNI, `k8s-cp-01` pode estar `NotReady` e CoreDNS pode não estar operacional.

---

# CP5 — Instalar Calico via Tigera Operator

Executar no Control Plane. A release deve ser previamente validada pelo formador. A edição de referência foi ensaiada com `v3.32.2`.

```bash
export CALICO_VERSION=v3.32.2

kubectl create -f \
https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/v1_crd_projectcalico_org.yaml

kubectl create -f \
https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml
```

Obtém os Custom Resources:

```bash
curl -LO \
https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml

grep -n 'cidr:' custom-resources.yaml
```

Confirma `192.168.0.0/16`, ajusta manualmente se necessário e aplica:

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

Enquanto ainda não existir Worker, alguns Deployments podem ficar `Pending` por causa da taint `control-plane:NoSchedule`.

```bash
kubectl get events -A --sort-by=.lastTimestamp
kubectl describe node k8s-cp-01 | grep -i Taints
```

**Não removas a taint.**

### Compatibilidade

Calico 3.32 é oficialmente testado até Kubernetes 1.36. Como este laboratório termina em 1.37, o formador deve pré-validar a combinação pós-upgrade ou usar uma release Calico oficialmente testada com 1.37 quando disponível.

---

# CP6 — Adicionar o Worker

No `k8s-cp-01`:

```bash
sudo kubeadm token create --print-join-command
```

No `k8s-wk-01`, executa o comando **real** devolvido pelo CP com `sudo`.

```bash
sudo kubeadm join <ENDPOINT_REAL>:6443 --token <TOKEN_REAL> \
  --discovery-token-ca-cert-hash sha256:<HASH_REAL>
```

Os valores acima são placeholders. Não executes `<TOKEN_REAL>`, `VALOR_REAL`, `<HASH_REAL>` ou `...` literalmente.

> No Worker executa-se `kubeadm join`, nunca `kubeadm init`.

No Control Plane:

```bash
kubectl get nodes -o wide
kubectl get pods -n calico-system -o wide
kubectl get pods -n kube-system -o wide
kubectl get tigerastatus
```

Aguarda a convergência até os dois Nodes estarem `Ready` e CoreDNS/Calico operacionais.

Neste momento tens um cluster **Kubernetes 1.36.x saudável**.

---

# CP7 — Manutenção controlada

Aplica o Pod direto:

```bash
kubectl apply -f manifests/pod_cordon_test.yaml
kubectl get pod cordon-test -o wide
```

Cordon:

```bash
kubectl cordon k8s-wk-01
kubectl get nodes
```

Drain sem force:

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets
```

Lê a mensagem. O Pod direto sem controller deve obrigar a uma decisão explícita.

Só neste exercício:

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets --force
kubectl get pod cordon-test
kubectl uncordon k8s-wk-01
```

O Pod não reaparece porque não existe controller.

---

# CP8 — Upgrade do Control Plane para 1.37.x

## 8.1. Confirmar o estado inicial

```bash
kubectl get nodes -o wide
sudo kubeadm upgrade plan
```

## 8.2. Mudar o repositório APT

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.37/deb/Release.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.37/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-cache madison kubeadm
```

Regista a versão real do pacote. Nos comandos seguintes:

```text
<PKG_1_37> = versão APT real
<K8S_1_37> = versão Kubernetes real, por exemplo v1.37.0
```

## 8.3. Atualizar kubeadm

```bash
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm='<PKG_1_37>'
sudo apt-mark hold kubeadm
kubeadm version
```

## 8.4. Planear e aplicar

```bash
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply <K8S_1_37>
```

Observa:

```bash
kubectl get nodes -o wide
```

É normal existir temporariamente version skew.

## 8.5. Atualizar kubelet e kubectl do Control Plane

```bash
kubectl drain k8s-cp-01 --ignore-daemonsets
```

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet='<PKG_1_37>' kubectl='<PKG_1_37>'
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

```bash
kubectl uncordon k8s-cp-01
kubectl get nodes -o wide
```

---

# CP9 — Upgrade do Worker para 1.37.x

No Worker, muda primeiro o repositório para a série 1.37 usando o mesmo procedimento.

Atualiza `kubeadm`:

```bash
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm='<PKG_1_37>'
sudo apt-mark hold kubeadm
sudo kubeadm upgrade node
```

No Control Plane:

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets
```

> Num upgrade, não uses `--force` por omissão. Se o drain recusar, investiga primeiro.

No Worker:

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet='<PKG_1_37>' kubectl='<PKG_1_37>'
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

No Control Plane:

```bash
kubectl uncordon k8s-wk-01
```

---

# CP10 — Validação final

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl cluster-info
kubectl config current-context
```

Confirma:

```text
[ ] k8s-cp-01 Ready e v1.37.x
[ ] k8s-wk-01 Ready e v1.37.x
[ ] Worker schedulable
[ ] CoreDNS Running
[ ] Calico/Tigera operacional
[ ] API acessível
```

---

# Questões de consolidação

1. Porque usamos o repositório 1.36 na instalação e 1.37 no upgrade?
2. Porque se atualiza primeiro o `kubeadm`?
3. Porque o Control Plane é atualizado antes do Worker?
4. Em que momento existe version skew?
5. Porque o kubelet deve ser drenado antes de um upgrade minor?
6. Porque `kubeadm upgrade node` é usado no Worker?
7. Porque não devemos usar `--force` automaticamente num drain de upgrade?
8. Porque voltamos a validar CoreDNS e CNI no final?
9. Porque uma combinação pré-validada localmente não é sinónimo de suporte oficial do fornecedor?

Na Sessão 5, o foco passa de **construir e evoluir o cluster** para **executar e expor workloads e preservar os seus dados**.
